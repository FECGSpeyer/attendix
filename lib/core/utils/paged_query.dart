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
