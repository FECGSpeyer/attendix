// werke-import: the Google Drive side of "Noten importieren" (Beta design,
// lib/features/redesign/data/import/rd_import_drive.dart). A group shares its
// sheet-music folder with "Anyone with the link" and pastes the link in the
// app. The app walks the folder level by level through this function and has
// the chosen files copied straight from Drive into the tenant's song folders,
// so nothing large passes through the phone. The Google API key stays here.
//
// Actions (POST JSON, every one with tenantId):
//   folder {folder: Ref}                     → {id, name}
//   list   {folders: Ref[] (1–25)}           → {children: {<folderId>: Item[]}}
//          Item = {id, resourceKey?, name, mimeType, size?, modifiedTime?, md5?}
//   head   {file: Ref}                       → {data: base64, size}
//          first and last 256 KB (the dates inside a PDF), the whole file
//          when it is smaller
//   copy   {file: Ref, songId, storageName, contentType?} → {path}
//          (a file that changed since its size was read is refused: "changed")
//          stores the file at songs/<tenantId>/<songId>/<storageName>; an
//          existing object is never replaced. The app then adds the entry to
//          the song's files (SongFileService.uploadFileVia).
//   Ref = {id, resourceKey?}
//
// Guards:
// - a real signed-in account (auth.getUser; the public anon JWT is refused),
// - that account edits the tenant (tenantUsers role admin, responsible,
//   helper, voice-leader helper, as part-detect),
// - copy: the song belongs to the tenant, the storage name has the app's
//   pattern, upsert is off,
// - only www.googleapis.com is fetched; ids and resource keys are checked
//   against Drive's alphabet; Google Docs and files over 20 MB are refused,
// - a daily budget of calls and bytes per account and per tenant
//   (`werke_import_take`, see supabase/sql/werke_import_usage.sql; missing →
//   every call refused). Every action takes its call before it asks Google;
//   bytes are taken before a download, which stops at the bytes taken.
//
// Secrets: GOOGLE_API_KEY (Google Cloud API key, restricted to the Drive
// API), SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (set by
// Supabase).
//
// Setup: docs/werke-import.md.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const API_KEY = Deno.env.get("GOOGLE_API_KEY") ?? "";

/// Roles that edit the tenant (app: `Role.canEdit`).
const EDIT_ROLES = [1, 4, 5, 9];

/// Per day (UTC). The Speyer import (about 2,700 files) needs ~3,000 calls.
const DAILY_CALLS_USER = 20_000;
const DAILY_CALLS_TENANT = 40_000;
const DAILY_BYTES_USER = 10 * 1024 ** 3;
const DAILY_BYTES_TENANT = 20 * 1024 ** 3;

/// The app's upload limit (rdMaxUploadBytes).
const MAX_FILE_BYTES = 20 * 1024 * 1024;

/// Bytes read from each end of a PDF for its dates (rdPdfDate).
const HEAD_WINDOW = 256 * 1024;

const MAX_FOLDERS_PER_CALL = 25;
const MAX_PAGES_PER_FOLDER = 20;

const DRIVE = "https://www.googleapis.com/drive/v3/files";
const FOLDER_MIME = "application/vnd.google-apps.folder";
const DRIVE_ID = /^[A-Za-z0-9_-]{10,100}$/;
const RESOURCE_KEY = /^[A-Za-z0-9_-]{1,100}$/;

/// SongFileService.encodeFilename: `<name>_<number>.<ext>` with ASCII only.
const STORAGE_NAME = /^[A-Za-z0-9_-]{0,400}_\d{3,9}\.[A-Za-z0-9]{1,10}$/;
const CONTENT_TYPE = /^[a-z]+\/[A-Za-z0-9.+-]{1,100}$/;

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

/// Error codes the app knows (RdDriveError).
function fail(error: string, status: number): Response {
  return json({ error }, status);
}

type Ref = { id: string; resourceKey?: string };

function ref(value: unknown): Ref | null {
  if (typeof value !== "object" || value === null) return null;
  const { id, resourceKey } = value as Record<string, unknown>;
  if (typeof id !== "string" || !DRIVE_ID.test(id)) return null;
  if (resourceKey === undefined || resourceKey === null) return { id };
  if (typeof resourceKey !== "string" || !RESOURCE_KEY.test(resourceKey)) return null;
  return { id, resourceKey };
}

class DriveError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

/// The day's budget refused a call; [response] is the answer to send.
class BudgetRefused extends Error {
  constructor(readonly response: Response) {
    super("budget");
  }
}

/// A request to the Drive API with the key and the resource keys of [refs].
async function drive(
  path: string,
  params: Record<string, string>,
  refs: Ref[],
  headers: Record<string, string> = {},
): Promise<Response> {
  const url = new URL(path ? `${DRIVE}/${encodeURIComponent(path)}` : DRIVE);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  url.searchParams.set("supportsAllDrives", "true");
  url.searchParams.set("key", API_KEY);
  const keys = refs.filter((r) => r.resourceKey).map((r) => `${r.id}/${r.resourceKey}`);
  if (keys.length) headers["X-Goog-Drive-Resource-Keys"] = keys.join(",");
  const res = await fetch(url, { headers, signal: AbortSignal.timeout(60_000) });
  if (res.ok) return res;
  let reason = "";
  try {
    const body = await res.json();
    reason = body?.error?.errors?.[0]?.reason ?? body?.error?.status ?? "";
  } catch {
    // No JSON.
  }
  console.error("[werke-import] drive", res.status, reason);
  if (res.status === 404) throw new DriveError("not_found", 404);
  if (reason === "keyInvalid" || reason === "accessNotConfigured" || reason === "keyExpired") {
    throw new DriveError("not_configured", 503);
  }
  if (res.status === 429 || /RateLimit|rateLimit|dailyLimit|quota/i.test(reason)) {
    throw new DriveError("drive_busy", 429);
  }
  if (res.status === 401 || res.status === 403) throw new DriveError("not_found", 404);
  throw new DriveError("drive_failed", 502);
}

type Meta = { id: string; name: string; mimeType: string; size: number };

async function meta(file: Ref): Promise<Meta> {
  const res = await drive(file.id, { fields: "id,name,mimeType,size" }, [file]);
  const m = await res.json();
  return {
    id: String(m.id ?? file.id),
    name: String(m.name ?? ""),
    mimeType: String(m.mimeType ?? ""),
    size: Number(m.size ?? 0),
  };
}

/// Children of one folder, every page; a folder with more pages is refused
/// (choose a sub-folder) instead of being read in part. [charge] takes one
/// call of the day's budget before each request to Google.
async function children(folder: Ref, charge: () => Promise<void>): Promise<unknown[]> {
  const items: unknown[] = [];
  let pageToken = "";
  for (let page = 0; page < MAX_PAGES_PER_FOLDER; page++) {
    await charge();
    const params: Record<string, string> = {
      q: `'${folder.id}' in parents and trashed = false`,
      fields: "nextPageToken,files(id,name,mimeType,size,modifiedTime,md5Checksum,resourceKey)",
      pageSize: "1000",
      includeItemsFromAllDrives: "true",
    };
    if (pageToken) params.pageToken = pageToken;
    const res = await drive("", params, [folder]);
    const body = await res.json();
    for (const f of body.files ?? []) {
      if (typeof f?.id !== "string" || !DRIVE_ID.test(f.id)) continue;
      items.push({
        id: f.id,
        resourceKey: typeof f.resourceKey === "string" && RESOURCE_KEY.test(f.resourceKey) ? f.resourceKey : undefined,
        name: String(f.name ?? "").slice(0, 300),
        mimeType: String(f.mimeType ?? ""),
        size: f.size === undefined ? undefined : Number(f.size),
        modifiedTime: typeof f.modifiedTime === "string" ? f.modifiedTime : undefined,
        md5: typeof f.md5Checksum === "string" ? f.md5Checksum : undefined,
      });
    }
    pageToken = typeof body.nextPageToken === "string" ? body.nextPageToken : "";
    if (!pageToken) return items;
  }
  throw new DriveError("too_many", 413);
}

/// The body of [res], refused when it is longer than [limit] bytes (the
/// rest is not downloaded).
async function readAtMost(res: Response, limit: number): Promise<Uint8Array> {
  const length = Number(res.headers.get("content-length") ?? "0");
  if (length > limit) {
    await res.body?.cancel();
    throw new DriveError("changed", 409);
  }
  const reader = res.body?.getReader();
  if (!reader) return new Uint8Array(0);
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > limit) {
      await reader.cancel();
      throw new DriveError("changed", 409);
    }
    chunks.push(value);
  }
  const data = new Uint8Array(total);
  let at = 0;
  for (const c of chunks) {
    data.set(c, at);
    at += c.length;
  }
  return data;
}

/// The bytes of [file] from [start] to [end] (inclusive); never more than
/// that many are downloaded.
async function bytes(file: Ref, start: number, end: number): Promise<Uint8Array> {
  const res = await drive(file.id, { alt: "media" }, [file], { Range: `bytes=${start}-${end}` });
  const want = end - start + 1;
  if (res.status === 206) return readAtMost(res, want);
  // A server that ignores the range sends the whole file from its start.
  if (start > 0) {
    await res.body?.cancel();
    throw new DriveError("changed", 409);
  }
  return readPrefix(res, want);
}

/// The first [count] bytes of [res]; the rest is not downloaded.
async function readPrefix(res: Response, count: number): Promise<Uint8Array> {
  const reader = res.body?.getReader();
  if (!reader) return new Uint8Array(0);
  const data = new Uint8Array(count);
  let at = 0;
  while (at < count) {
    const { done, value } = await reader.read();
    if (done) break;
    const take = Math.min(value.length, count - at);
    data.set(value.subarray(0, take), at);
    at += take;
  }
  if (at >= count) await reader.cancel();
  return data.subarray(0, at);
}

function base64(data: Uint8Array): string {
  let s = "";
  for (let i = 0; i < data.length; i += 0x8000) {
    s += String.fromCharCode(...data.subarray(i, i + 0x8000));
  }
  return btoa(s);
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
  let body: Record<string, unknown>;
  try {
    const value = await req.json();
    if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error();
    body = value as Record<string, unknown>;
  } catch {
    return fail("bad_request", 400);
  }
  const { action, tenantId } = body;
  if (typeof tenantId !== "number" || !Number.isInteger(tenantId) || tenantId <= 0) {
    return fail("bad_request", 400);
  }
  if (!API_KEY) return fail("not_configured", 503);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 3. The account edits this tenant.
  const { data: membership, error: memberErr } = await admin
    .from("tenantUsers")
    .select("role")
    .eq("tenantId", tenantId)
    .eq("userId", userId)
    .in("role", EDIT_ROLES)
    .limit(1)
    .maybeSingle();
  if (memberErr) {
    console.error("[werke-import] membership lookup failed", memberErr);
    return fail("failed", 500);
  }
  if (!membership) return fail("forbidden", 403);

  /// Counts [calls] calls and [byteCount] bytes; a response when the day's
  /// budget is used up (or unknown), null when they are taken.
  async function take(calls: number, byteCount: number): Promise<Response | null> {
    const { data: allowed, error } = await admin.rpc("werke_import_take", {
      p_tenant_id: tenantId,
      p_user_id: userId,
      p_calls: calls,
      p_bytes: Math.max(0, Math.ceil(byteCount)),
      p_user_calls: DAILY_CALLS_USER,
      p_tenant_calls: DAILY_CALLS_TENANT,
      p_user_bytes: DAILY_BYTES_USER,
      p_tenant_bytes: DAILY_BYTES_TENANT,
    });
    if (error) {
      console.error("[werke-import] budget check failed", error);
      return fail("not_configured", 503);
    }
    return allowed === true ? null : fail("limit", 429);
  }

  /// One call of the budget, or [BudgetRefused].
  async function charge(): Promise<void> {
    const refused = await take(1, 0);
    if (refused) throw new BudgetRefused(refused);
  }

  try {
    switch (action) {
      case "folder": {
        const folder = ref(body.folder);
        if (!folder) return fail("bad_request", 400);
        const refused = await take(1, 0);
        if (refused) return refused;
        const m = await meta(folder);
        if (m.mimeType !== FOLDER_MIME) return fail("not_folder", 400);
        return json({ id: m.id, name: m.name.slice(0, 300) });
      }

      case "list": {
        const raw = body.folders;
        if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_FOLDERS_PER_CALL) {
          return fail("bad_request", 400);
        }
        const folders = raw.map(ref);
        if (folders.some((f) => f === null)) return fail("bad_request", 400);
        // Every page of every folder is one call of the budget.
        const lists = await Promise.all((folders as Ref[]).map((f) => children(f, charge)));
        const result: Record<string, unknown[]> = {};
        (folders as Ref[]).forEach((f, i) => (result[f.id] = lists[i]));
        return json({ children: result });
      }

      case "head": {
        const file = ref(body.file);
        if (!file) return fail("bad_request", 400);
        // At most two windows are read.
        const refused = await take(1, HEAD_WINDOW * 2);
        if (refused) return refused;
        const m = await meta(file);
        if (m.mimeType.startsWith("application/vnd.google-apps.")) return fail("not_a_file", 400);
        if (m.size > MAX_FILE_BYTES) return fail("too_large", 413);
        const whole = m.size <= HEAD_WINDOW * 2;
        if (m.size === 0) return json({ data: "", size: 0 });
        let data: Uint8Array;
        if (whole) {
          data = await bytes(file, 0, m.size - 1);
        } else {
          const head = await bytes(file, 0, HEAD_WINDOW - 1);
          const tail = await bytes(file, m.size - HEAD_WINDOW, m.size - 1);
          data = new Uint8Array(head.length + tail.length);
          data.set(head, 0);
          data.set(tail, head.length);
        }
        return json({ data: base64(data), size: m.size });
      }

      case "copy": {
        const file = ref(body.file);
        const { songId, storageName, contentType } = body;
        if (!file || typeof songId !== "number" || !Number.isInteger(songId) || songId <= 0) {
          return fail("bad_request", 400);
        }
        if (typeof storageName !== "string" || !STORAGE_NAME.test(storageName)) {
          return fail("bad_request", 400);
        }
        const type = typeof contentType === "string" && CONTENT_TYPE.test(contentType)
          ? contentType
          : "application/octet-stream";

        // The song is one of the tenant's.
        const { data: song, error: songErr } = await admin
          .from("songs")
          .select("id")
          .eq("id", songId)
          .eq("tenantId", tenantId)
          .maybeSingle();
        if (songErr) {
          console.error("[werke-import] song lookup failed", songErr);
          return fail("failed", 500);
        }
        if (!song) return fail("song_not_found", 404);

        const refusedCall = await take(1, 0);
        if (refusedCall) return refusedCall;
        const m = await meta(file);
        if (m.mimeType.startsWith("application/vnd.google-apps.")) return fail("not_a_file", 400);
        if (m.size > MAX_FILE_BYTES) return fail("too_large", 413);
        // The bytes before the download; a file that grew since is refused.
        const refusedBytes = await take(0, m.size);
        if (refusedBytes) return refusedBytes;

        const res = await drive(file.id, { alt: "media" }, [file]);
        const data = await readAtMost(res, m.size);

        const path = `songs/${tenantId}/${songId}/${storageName}`;
        const { error: upErr } = await admin.storage
          .from("songs")
          .upload(path, data, { contentType: type, upsert: false });
        if (upErr) {
          const status = Number((upErr as { statusCode?: string | number }).statusCode ?? 0);
          if (status === 409 || /exists/i.test(upErr.message)) return fail("exists", 409);
          console.error("[werke-import] storage upload failed", upErr);
          return fail("storage_failed", 502);
        }
        return json({ path });
      }

      default:
        return fail("bad_request", 400);
    }
  } catch (e) {
    if (e instanceof BudgetRefused) return e.response;
    if (e instanceof DriveError) return fail(e.code, e.status);
    console.error("[werke-import] failed", e);
    return fail("drive_failed", 502);
  }
});
