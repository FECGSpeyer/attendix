/// PostgREST caps every response at `max-rows` (Supabase default 1000), so
/// "all rows" queries must be loaded page by page.
const int kPostgrestPageSize = 1000;

/// SOL_FIX1: loads every page of a query via [fetchPage] (`from`/`to` are
/// inclusive row indices for `.range(from, to)`) until a page returns fewer
/// than [pageSize] rows.
///
/// The query passed in must have a deterministic order ending in a unique
/// column (e.g. `.order('id')`), otherwise pages can overlap or skip rows.
Future<List<T>> fetchAllPages<T>(
  Future<List<T>> Function(int from, int to) fetchPage, {
  int pageSize = kPostgrestPageSize,
}) async {
  assert(pageSize > 0);
  final all = <T>[];
  for (var from = 0;; from += pageSize) {
    final page = await fetchPage(from, from + pageSize - 1);
    all.addAll(page);
    if (page.length < pageSize) break;
  }
  return all;
}

/// Max ids per `inFilter`: the ids end up in the request URL, and browsers,
/// proxies and PostgREST reject URLs beyond roughly 8 KB. 150 ids stay well
/// below that even for long ids.
const int kInFilterChunkSize = 150;

/// Runs [fetch] once per chunk of [ids] (at most [chunkSize] each) and
/// concatenates the results in chunk order. Use it for `inFilter` lists
/// that can grow with the data (all Termine of a season, all persons).
Future<List<T>> fetchInChunks<T, K>(
  List<K> ids,
  Future<List<T>> Function(List<K> chunk) fetch, {
  int chunkSize = kInFilterChunkSize,
}) async {
  assert(chunkSize > 0);
  final all = <T>[];
  for (var i = 0; i < ids.length; i += chunkSize) {
    final end = i + chunkSize < ids.length ? i + chunkSize : ids.length;
    all.addAll(await fetch(ids.sublist(i, end)));
  }
  return all;
}
