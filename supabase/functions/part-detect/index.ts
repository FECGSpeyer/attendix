// part-detect: reads the part name (e.g. "Violin II", "Clarinet in B♭ 1") on
// the first page of an uploaded sheet-music file and picks the matching
// group of the tenant. Called by the app only for files whose part could
// not be recognised from the file name (fallback, see
// lib/core/services/part_vision_service.dart).
//
// Input (JSON): { image: base64 JPEG/PNG of page 1, mime, fileName,
//                 groups: [{ id, name }] }
// Output (JSON): { groupId: number | null, label: string | null,
//                  confidence: "high" | "low" }
//
// The function reads nothing from the database; it only needs a signed-in
// user (deploy with JWT verification, the default) and the OPEN_AI_KEY
// secret that synonyms-gpt already uses.
//
// Deploy: supabase functions deploy part-detect --project-ref <ref>
import OpenAI from "https://deno.land/x/openai@v4.69.0/mod.ts";

interface Group {
  id: number;
  name: string;
}

interface ReqPayload {
  image?: string;
  mime?: string;
  fileName?: string;
  groups?: Group[];
}

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_IMAGE_CHARS = 2_000_000; // ~1.5 MB base64
const MAX_GROUPS = 150;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);

  let body: ReqPayload;
  try {
    body = (await req.json()) as ReqPayload;
  } catch {
    return json({ error: "expected JSON" }, 400);
  }

  const image = (body.image ?? "").trim();
  const mime = body.mime === "image/png" ? "image/png" : "image/jpeg";
  const groups = (body.groups ?? [])
    .filter((g) => Number.isInteger(g?.id) && typeof g?.name === "string" && g.name.trim())
    .slice(0, MAX_GROUPS)
    .map((g) => ({ id: g.id, name: g.name.trim().slice(0, 80) }));
  if (!image || image.length > MAX_IMAGE_CHARS || groups.length === 0) {
    return json({ error: "image and groups are required" }, 400);
  }
  const fileName = (body.fileName ?? "").slice(0, 200);

  const client = new OpenAI({ apiKey: Deno.env.get("OPEN_AI_KEY") });
  const list = groups.map((g) => `${g.id}: ${g.name}`).join("\n");
  const prompt =
    `This is the first page of a sheet-music part (file name: "${fileName}"). ` +
    `Read the part / instrument name printed on it (usually at the top left or top centre, ` +
    `e.g. "Violin II", "Clarinet in B♭ 1", "Horn in F 3", "Sopran", "Partitur"). ` +
    `Ignore the title, composer and movement numbers. ` +
    `Pick the ONE group from this list that this part belongs to, taking part numbers into account ` +
    `(Violin II belongs to a group like "Violine 2", not "Violine 1"):\n${list}\n\n` +
    `Answer only with JSON: {"groupId": <id from the list or null>, "label": "<part name as printed or null>", ` +
    `"confidence": "high" | "low"}. Use "low" when the name is hard to read, missing, ` +
    `or more than one group could fit; use null when no group fits or it is a full score.`;

  try {
    const response = await client.chat.completions.create({
      model: "gpt-4.1-mini",
      stream: false,
      temperature: 0,
      response_format: { type: "json_object" },
      max_tokens: 120,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: { url: `data:${mime};base64,${image}`, detail: "high" } },
          ],
        },
      ],
    });
    const raw = response.choices[0]?.message?.content ?? "{}";
    const parsed = JSON.parse(raw) as { groupId?: unknown; label?: unknown; confidence?: unknown };
    const id = typeof parsed.groupId === "number" ? parsed.groupId : Number(parsed.groupId);
    const groupId = groups.some((g) => g.id === id) ? id : null;
    return json({
      groupId,
      label: typeof parsed.label === "string" ? parsed.label.slice(0, 80) : null,
      confidence: parsed.confidence === "high" && groupId !== null ? "high" : "low",
    });
  } catch (e) {
    console.error("part-detect error", e);
    return json({ error: "detection failed" }, 502);
  }
});
