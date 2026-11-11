// ai-assistant: the chat assistant ("Assistent" under "Mehr" / "Ich").
// Turns ONE typed message into ONE of the fixed commands of intent.ts
// (attendance rate, who comes, next Termin, birthdays, Werk last sung,
// help, and since package 2 set a status / planned absence). The app then
// loads and shows the data itself with the person's rights; changes are
// only a preview in the app until the person confirms. This function never
// reads, returns or writes data of people.
//
// Input (JSON):  { tenantId: number, text: string (≤ 500), today: "YYYY-MM-DD",
//                  language: "de" | "en" | "ru" | "es" }
// Output (JSON): { command: { command: "...", ... } } (see intent.ts)
//
// Guards (every paid call):
// - a real signed-in account (auth.getUser; the public anon JWT is refused),
// - that account belongs to the tenant (tenantUsers, not as applicant),
// - the tenant switched the assistant on (`tenants.ai_assistant_enabled`,
//   set by an admin; off → 403 {reason: "disabled"}),
// - the daily budget (`ai_assistant_take`, per account and per tenant,
//   taken before the paid call; see supabase/sql/ai_assistant.sql),
// - only names of groups and Termintypen go to the model, from the database
//   (tenant filter), never people; the message is passed as quoted data,
// - the model can only pick a command: every answer is checked
//   (validateCommand), anything else becomes "unsupported",
// - no log of the typed text, only the command and the token counts.
//
// Secrets: OPEN_AI_KEY_ASSISTANT (own key, so the costs show apart; falls
// back to OPEN_AI_KEY), SUPABASE_URL, SUPABASE_ANON_KEY,
// SUPABASE_SERVICE_ROLE_KEY (set by Supabase).
//
// Setup: supabase/sql/ai_assistant.sql run once,
//        then supabase functions deploy ai-assistant --project-ref <ref>
import OpenAI from "npm:openai@4.104.0";
import { createClient } from "npm:@supabase/supabase-js@2";
import { cleanText, isoDate, MAX_TEXT, parseModelAnswer, SYSTEM_PROMPT, userPrompt } from "./intent.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/// Applicants (7) wait for approval and may not use it.
const APPLICANT_ROLE = 7;

/// Messages per day (UTC): per account over all its tenants, per tenant over
/// all its accounts. One message costs a fraction of a cent.
const DAILY_LIMIT_USER = 60;
const DAILY_LIMIT_TENANT = 1000;

/// Text model, as the other KI functions (part-suggest, work-match).
const MODEL = "gpt-6-luna";

const MAX_NAMES = 150;
const LANGUAGES = new Set(["de", "en", "ru", "es"]);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/// Up to [MAX_NAMES] distinct short names.
function names(rows: { name?: unknown }[] | null): string[] {
  const out = new Set<string>();
  for (const r of rows ?? []) {
    const n = cleanText(r.name, 60);
    if (n) out.add(n);
    if (out.size >= MAX_NAMES) break;
  }
  return [...out];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);

  // 1. A real account, not just the public anon key.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "Invalid token" }, 401);
  const userId = userData.user.id;

  // 2. The request.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "expected JSON" }, 400);
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return json({ error: "expected a JSON object" }, 400);
  }
  const { tenantId, text: rawText, today: rawToday, language: rawLanguage } = body as Record<string, unknown>;
  if (typeof tenantId !== "number" || !Number.isInteger(tenantId) || tenantId <= 0) {
    return json({ error: "tenantId must be a positive integer" }, 400);
  }
  if (typeof rawText !== "string" || rawText.length > MAX_TEXT) {
    return json({ error: `text must be at most ${MAX_TEXT} characters` }, 413);
  }
  const text = cleanText(rawText, MAX_TEXT);
  if (!text) return json({ error: "text is empty" }, 400);
  // The device's day (time zone of the person); only a plausible one.
  const serverDay = new Date().toISOString().slice(0, 10);
  const today = isoDate(rawToday) ?? serverDay;
  if (Math.abs(Date.parse(today) - Date.parse(serverDay)) > 2 * 86_400_000) {
    return json({ error: "today is not plausible" }, 400);
  }
  const language = typeof rawLanguage === "string" && LANGUAGES.has(rawLanguage) ? rawLanguage : "de";

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 3. The account belongs to this tenant (not as applicant).
  const { data: membership, error: memberErr } = await admin
    .from("tenantUsers")
    .select("role")
    .eq("tenantId", tenantId)
    .eq("userId", userId)
    .neq("role", APPLICANT_ROLE)
    .limit(1)
    .maybeSingle();
  if (memberErr) {
    console.error("[ai-assistant] membership lookup failed", memberErr);
    return json({ error: "membership lookup failed" }, 500);
  }
  if (!membership) return json({ error: "Forbidden" }, 403);

  // 4. The admin switched the assistant on.
  const { data: tenant, error: tenantErr } = await admin
    .from("tenants")
    .select("ai_assistant_enabled")
    .eq("id", tenantId)
    .maybeSingle();
  if (tenantErr) {
    console.error("[ai-assistant] tenant lookup failed", tenantErr);
    return json({ error: "tenant lookup failed" }, 500);
  }
  if (tenant?.ai_assistant_enabled !== true) return json({ error: "Forbidden", reason: "disabled" }, 403);

  // 5. Names of groups and Termintypen (no people), from the database.
  const [groupsRes, typesRes] = await Promise.all([
    admin.from("instruments").select("name").eq("tenantId", tenantId).order("id").limit(MAX_NAMES),
    admin.from("attendance_types").select("name").eq("tenant_id", tenantId).order("index").limit(MAX_NAMES),
  ]);
  if (groupsRes.error || typesRes.error) {
    console.error("[ai-assistant] names lookup failed", groupsRes.error ?? typesRes.error);
    return json({ error: "names lookup failed" }, 500);
  }

  // 6. Budget: counted before the paid call, refused when used up or unknown.
  const { data: allowed, error: budgetErr } = await admin.rpc("ai_assistant_take", {
    p_tenant_id: tenantId,
    p_user_id: userId,
    p_user_limit: DAILY_LIMIT_USER,
    p_tenant_limit: DAILY_LIMIT_TENANT,
  });
  if (budgetErr) {
    console.error("[ai-assistant] budget check failed", budgetErr);
    return json({ error: "budget check failed" }, 503);
  }
  if (allowed !== true) return json({ error: "daily limit reached" }, 429);

  // 7. The model; rules and data are kept apart.
  let raw: string | null = null;
  try {
    const client = new OpenAI({ apiKey: Deno.env.get("OPEN_AI_KEY_ASSISTANT") || Deno.env.get("OPEN_AI_KEY") });
    const response = await client.chat.completions.create({
      model: MODEL,
      stream: false,
      reasoning_effort: "low",
      response_format: { type: "json_object" },
      // Reasoning tokens count against this limit too.
      max_completion_tokens: 2000,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: userPrompt({
            text,
            today,
            language,
            types: names(typesRes.data),
            groups: names(groupsRes.data),
          }),
        },
      ],
    });
    raw = response.choices[0]?.message?.content ?? null;
    console.log("[ai-assistant] usage", response.usage?.prompt_tokens, response.usage?.completion_tokens);
  } catch (e) {
    console.error("[ai-assistant] model call failed", e);
    return json({ error: "assistant failed" }, 502);
  }

  // 8. Only one of the fixed commands leaves the function.
  const command = parseModelAnswer(raw);
  console.log("[ai-assistant] command", command.command);
  return json({ command });
});
