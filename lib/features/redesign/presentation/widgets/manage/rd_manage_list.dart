import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue, AsyncValueX;
import 'package:go_router/go_router.dart';

import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/app_action_sheet.dart';
import '../rd_widgets.dart';
import '../today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: template "Verwaltungsliste" (canvas "Einheitliche Beta-UX",
/// boards "Ein Look: die 5 Seitentypen" Nr. 4 and "B Verwaltung: Listen").
///
/// One page type for every list of the Verwaltung: "‹ Verwaltung", large
/// title, one line of explanation, the entries as grouped lists (optionally
/// in sections), "+" to add, "•••" for "Reihenfolge ändern" and further
/// list actions, and the loading, empty and error states of the other Beta
/// pages. The page only shows; loading, saving and rights stay with the
/// caller (see `rd_groups_page.dart`, `rd_attendance_types_page.dart`).

/// TENANT: the list of [async] only when it surely belongs to the current
/// group and account (like `permissionsConfirmed`): fully loaded, or a
/// pull-to-refresh / invalidate of the same list (`isRefreshing`). After a
/// group or account switch the provider reloads (`isReloading`) and still
/// holds the old group's value, an error may carry it as well; then null,
/// so the page shows its loading (or error) state and offers no actions.
T? rdLoadedValue<T>(AsyncValue<T> async) {
  if (!async.hasValue || async.hasError) return null;
  if (async.isLoading && !async.isRefreshing) return null;
  return async.value;
}

/// One entry: initials (or [icon]), title, subtitle, a count on the right.
class RdManageListItem {
  const RdManageListItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.count,
    this.countWarn = false,
    this.icon,
    this.trailing,
    this.onTap,
  });

  /// Stable id (key of the row, also while sorting).
  final Object id;
  final String title;
  final String? subtitle;

  /// Text on the right ("12 Personen").
  final String? count;

  /// Shows [count] as a red pill (e.g. a group without persons).
  final bool countWarn;

  /// Icon instead of the initials of [title].
  final IconData? icon;

  /// Own widget on the right (e.g. a switch); replaces [count].
  final Widget? trailing;
  final VoidCallback? onTap;
}

/// A section of entries; [title] null = no heading (a plain list).
class RdManageListSection {
  const RdManageListSection({this.key, this.title, required this.items});

  /// Identifies the section for the caller (e.g. the category id).
  final Object? key;
  final String? title;
  final List<RdManageListItem> items;

  RdManageListSection withItems(List<RdManageListItem> items) =>
      RdManageListSection(key: key, title: title, items: items);
}

/// A further action of the "•••" menu ("Kategorien verwalten").
class RdManageListAction {
  const RdManageListAction({required this.label, required this.icon, required this.onSelected});

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
}

class RdManageListPage extends StatefulWidget {
  const RdManageListPage({
    super.key,
    required this.title,
    required this.intro,
    required this.sections,
    required this.emptyText,
    this.loadFailed = false,
    this.onRetry,
    this.notice,
    this.emptyIcon = Icons.inbox_outlined,
    this.addLabel,
    this.onAdd,
    this.actions = const [],
    this.onReorder,
    this.onRefresh,
    this.backLabel,
    this.onBack,
  });

  final String title;

  /// One line below the title: what the list is for.
  final String intro;

  /// Null while loading (or when loading failed, see [loadFailed]).
  final List<RdManageListSection>? sections;

  /// Loading failed and nothing is shown yet: error card with [onRetry].
  final bool loadFailed;
  final VoidCallback? onRetry;

  /// Important note below the intro (card).
  final String? notice;

  final String emptyText;
  final IconData emptyIcon;

  /// "+" (bottom right) and, on an empty list, the button of the empty card.
  final String? addLabel;
  final VoidCallback? onAdd;

  /// Further actions of the "•••" menu.
  final List<RdManageListAction> actions;

  /// Set when the order can be changed: "Reihenfolge ändern" in "•••". Each
  /// section is sorted on its own; "Fertig" calls this with the new order
  /// (only after a real move) and leaves the mode when it returns true. On
  /// false the moved order stays so the user can try again.
  final Future<bool> Function(List<RdManageListSection> sections)? onReorder;

  final Future<void> Function()? onRefresh;

  /// Back link; default "‹ Verwaltung" (pop, else Ich › Verwaltung).
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  State<RdManageListPage> createState() => _RdManageListPageState();
}

class _RdManageListPageState extends State<RdManageListPage> {
  /// The working copy while sorting; null = normal list.
  List<RdManageListSection>? _sorting;
  bool _moved = false;
  bool _saving = false;

  int get _itemCount => (widget.sections ?? const []).fold(0, (sum, s) => sum + s.items.length);

  /// Each section is sorted on its own: only offered when one has 2+ rows.
  bool get _canReorder =>
      widget.onReorder != null && (widget.sections ?? const []).any((s) => s.items.length > 1);

  void _back() {
    if (widget.onBack != null) return widget.onBack!();
    context.canPop() ? context.pop() : context.go(RedesignRoutes.manage);
  }

  void _startSorting() {
    setState(() {
      _sorting = [for (final s in widget.sections ?? const <RdManageListSection>[]) s.withItems([...s.items])];
      _moved = false;
    });
  }

  void _cancelSorting() {
    if (_saving) return; // the moved order stays until the save has answered
    setState(() => _sorting = null);
  }

  Future<void> _finishSorting() async {
    final sorting = _sorting;
    if (sorting == null || _saving) return;
    if (!_moved) {
      setState(() => _sorting = null);
      return;
    }
    setState(() => _saving = true);
    var ok = false;
    try {
      ok = await widget.onReorder!(sorting);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _sorting = null;
    });
  }

  /// [newIndex] as `onReorderItem` reports it (already without the moved row).
  void _move(int section, int oldIndex, int newIndex) {
    // A move during the save would be dropped when the save succeeds.
    if (_saving) return;
    setState(() {
      if (newIndex == oldIndex) return;
      final items = [..._sorting![section].items];
      items.insert(newIndex, items.removeAt(oldIndex));
      _sorting![section] = _sorting![section].withItems(items);
      _moved = true;
    });
  }

  Future<void> _more() async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<int>(
      context,
      actions: [
        if (_canReorder) AppActionSheetAction(value: -1, icon: Icons.swap_vert, label: l10n.redesignManageListReorder),
        for (var i = 0; i < widget.actions.length; i++)
          AppActionSheetAction(value: i, icon: widget.actions[i].icon, label: widget.actions[i].label),
      ],
    );
    if (!mounted || action == null) return;
    if (action == -1) {
      _startSorting();
    } else {
      widget.actions[action].onSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final sorting = _sorting;
    final sections = widget.sections;
    final hasMenu = _canReorder || widget.actions.isNotEmpty;
    final showAdd = widget.onAdd != null && sorting == null;

    final topBar = Row(
      children: [
        if (sorting != null)
          RdTextLink(key: const Key('rd-manage-list-cancel'), label: l10n.redesignCommonCancel, onTap: _cancelSorting)
        else
          Expanded(child: RdBackLink(label: widget.backLabel ?? l10n.redesignMeAdmin, onTap: _back)),
        if (sorting != null) ...[
          const Spacer(),
          if (_saving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
              ),
            )
          else
            RdTextLink(key: const Key('rd-manage-list-done'), label: l10n.redesignCommonDone, onTap: _finishSorting),
        ] else if (hasMenu && sections != null)
          RdCircleButton(
            key: const Key('rd-manage-list-more'),
            icon: Icons.more_horiz,
            label: l10n.redesignManageListMore,
            onPressed: _more,
          ),
      ],
    );

    final List<Widget> body;
    if (sections == null) {
      body = [
        widget.loadFailed
            ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.cloud_off_outlined,
              action:
                  widget.onRetry == null
                      ? null
                      : RdOutlineButton(label: l10n.redesignCommonRetry, onPressed: widget.onRetry),
            )
            : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      ];
    } else if (_itemCount == 0) {
      body = [
        RdInfoCard(
          icon: widget.emptyIcon,
          text: widget.emptyText,
          action:
              widget.onAdd == null || widget.addLabel == null
                  ? null
                  : RdOutlineButton(icon: Icons.add, label: widget.addLabel!, onPressed: widget.onAdd),
        ),
      ];
    } else {
      final shown = sorting ?? sections;
      body = [
        if (sorting != null) ...[
          RdInfoCard(icon: Icons.swap_vert, text: l10n.redesignManageListReorderHint),
          const SizedBox(height: 18),
        ],
        for (var s = 0; s < shown.length; s++)
          if (shown[s].items.isNotEmpty) ...[
            if (shown[s].title != null) RdSectionHeader(shown[s].title!, trailing: '${shown[s].items.length}'),
            sorting != null
                ? RdGroupedList(children: [IgnorePointer(ignoring: _saving, child: _sortList(context, s, shown[s]))])
                : RdGroupedList(
                  children: [
                    for (final item in shown[s].items) _ItemRow(key: ValueKey('rd-manage-item-${item.id}'), item: item),
                  ],
                ),
            const SizedBox(height: 22),
          ],
      ];
    }

    return RdPage(
      // Kept while sorting (the working copy stays), so the list does not
      // jump when the mode changes.
      onRefresh: widget.onRefresh,
      padding: EdgeInsets.fromLTRB(20, 12, 20, showAdd ? 96 : 32),
      floatingActionButton:
          showAdd
              ? FloatingActionButton(
                key: const Key('rd-manage-list-add'),
                tooltip: widget.addLabel,
                backgroundColor: p.primary,
                foregroundColor: p.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                onPressed: widget.onAdd,
                child: const Icon(Icons.add, size: 28),
              )
              : null,
      children: [
        topBar,
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(widget.title, style: RdType.largeTitle(p))),
        const SizedBox(height: 6),
        Text(widget.intro, style: RdType.meta(p, size: 15)),
        if (widget.notice != null) ...[
          const SizedBox(height: 12),
          RdInfoCard(icon: Icons.info_outline, text: widget.notice!),
        ],
        const SizedBox(height: 20),
        ...body,
      ],
    );
  }

  Widget _sortList(BuildContext context, int index, RdManageListSection section) {
    final p = context.rd;
    final items = section.items;
    return ReorderableListView(
      key: ValueKey('rd-manage-sort-${section.key ?? index}'),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, _, __) => Material(color: p.surface, elevation: 6, child: child),
      onReorderItem: (o, n) => _move(index, o, n),
      children: [
        for (var i = 0; i < items.length; i++)
          Column(
            key: ValueKey('rd-manage-sort-item-${items[i].id}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              RdListRow(
                leading: _leading(items[i]),
                title: items[i].title,
                subtitle: items[i].subtitle,
                showChevron: false,
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle, color: p.text2),
                  ),
                ),
              ),
              if (i < items.length - 1) Divider(height: 1, thickness: 1, color: p.line),
            ],
          ),
      ],
    );
  }
}

Widget _leading(RdManageListItem item) =>
    item.icon != null ? RdRowIcon(item.icon!) : RdInitials(rdInitialsOf(item.title), size: 32, square: true);

class _ItemRow extends StatelessWidget {
  const _ItemRow({super.key, required this.item});

  final RdManageListItem item;

  @override
  Widget build(BuildContext context) {
    final count = item.count;
    return RdListRow(
      leading: _leading(item),
      title: item.title,
      subtitle: item.subtitle,
      value: item.trailing != null || item.countWarn ? null : count,
      trailing: item.trailing ?? (item.countWarn && count != null ? RdPill(count, tone: RdTone.absent) : null),
      onTap: item.onTap,
    );
  }
}
