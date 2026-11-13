// synonyms-gpt: other names for a group/instrument ("Synonyme generieren" in
// Register bearbeiten, Ionic and Flutter). Returns a comma-separated list as
// text/plain.
//
// Input (JSON):  { group: string }
// Output:        "Flöte, Querflöte, Flute, ..." (text/plain)
//
// Until 13.11.2026 this function lived only in the dashboard and used
// `gpt-4.1-nano`, which OpenAI shut down (404 model_not_found → app showed
// "Fehler beim Synonyme generieren"). Now the newest Luna, as part-suggest.
//
// Secrets: OPEN_AI_KEY_IMPORT (falls back to OPEN_AI_KEY, as part-suggest).
// Deploy: supabase functions deploy synonyms-gpt --project-ref <ref>
import OpenAI from "npm:openai@4.104.0";

/// Text model: the newest GPT Luna (Leon, 06.11.2026).
const MODEL = "gpt-6-luna";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ReqPayload {
  group?: string;
}

console.info("synonyms-gpt started");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405, headers: cors });

  const contentType = req.headers.get("content-type") || "";
  if (!contentType.includes("application/json")) {
    return new Response("Unsupported Media Type: expected application/json", { status: 415, headers: cors });
  }

  let group = "";
  try {
    group = (((await req.json()) as ReqPayload).group ?? "").trim().slice(0, 80);
  } catch {
    return new Response("Bad Request: invalid JSON", { status: 400, headers: cors });
  }
  if (!group) return new Response("Bad Request: 'group' is required", { status: 400, headers: cors });

  try {
    const client = new OpenAI({ apiKey: Deno.env.get("OPEN_AI_KEY_IMPORT") || Deno.env.get("OPEN_AI_KEY") });
    const response = await client.chat.completions.create({
      model: MODEL,
      stream: false,
      reasoning_effort: "low",
      // Reasoning tokens count against this limit too.
      max_completion_tokens: 2000,
      messages: [
        {
          role: "system",
          content:
            "You list synonyms for the name of a group in an orchestra, choir or band (an instrument, voice or section). " +
            "Give at most 5, in German and English. Reply only with a comma-separated list, no other text or formatting.",
        },
        { role: "user", content: `Group name (data): ${JSON.stringify(group)}` },
      ],
    });
    const reply = response.choices[0]?.message?.content?.trim() ?? "";
    if (!reply) {
      console.error("synonyms-gpt empty reply", response.choices[0]?.finish_reason);
      return new Response("No synonyms", { status: 502, headers: cors });
    }
    return new Response(reply, { headers: { ...cors, "Content-Type": "text/plain" } });
  } catch (e) {
    console.error("synonyms-gpt error", e);
    return new Response("Synonyms failed", { status: 502, headers: cors });
  }
});
