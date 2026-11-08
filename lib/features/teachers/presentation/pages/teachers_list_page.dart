import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/repositories/teacher_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../people/presentation/widgets/ion/ion_widgets.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground;

/// Validation of the teacher form, per mode exactly as in Ionic:
/// - create (teachers.page `addTeacher`): `String(name).length < 3 ||
///   instruments.length === 0` → toast `teachers.fillAll`.
/// - edit (teacher.page `editTeacher`): no validation at all, so existing
///   entries without instrument can still be saved.
/// Also used by the Beta sheet "Neuer Lehrer".
bool isTeacherFormValid({
  required bool isNew,
  required String name,
  required Iterable<int> instruments,
}) {
  if (!isNew) return true;
  return name.length >= 3 && instruments.isNotEmpty;
}

/// All groups of the tenant; waits for them if no page loaded them yet.
Future<List<Group>> loadTeacherGroups(WidgetRef ref) async {
  try {
    return await ref.read(groupsProvider.future);
  } catch (_) {
    return ref.read(groupsProvider).valueOrNull ?? const [];
  }
}

/// Ionic "Lehrer hinzufügen" sheet (breakpoint 0.7), also used by the Beta
/// list (`rd_teachers_page.dart`). Returns the created teacher, null when
/// the sheet was closed or creating failed.
///
/// The repository (bound to tenant and account) is taken before the first
/// await: when the group changed while the sheet was open, nothing is
/// created (the instruments belong to the old group) and an error is shown.
Future<Teacher?> showAddTeacherSheet(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final repo = container.read(teacherRepositoryWithTenantProvider);
  final saveFailed = context.l10n.extraFieldsSaveFailed;
  // Ionic teachers.page: instruments without the main group. Ionic has
  // db.groups() always loaded; here the groups may not be loaded yet.
  final groups = (await loadTeacherGroups(ref))
      .where((g) => g.maingroup != true)
      .toList();
  if (!context.mounted) return null;
  final result = await showModalBottomSheet<Teacher>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _TeacherForm(availableInstruments: groups),
    ),
  );
  if (result == null) return null;
  // Same tenant and account as when the sheet was opened (one repository
  // instance per tenant and account).
  if (!repo.hasTenantId || !identical(container.read(teacherRepositoryWithTenantProvider), repo)) {
    if (context.mounted) ToastHelper.showError(context, saveFailed);
    return null;
  }
  try {
    final created = await repo.createTeacher(result);
    container.read(trackingServiceProvider).track(TrackingEvent.teacherAdded);
    container.invalidate(teachersProvider);
    return created;
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
    return null;
  }
}

/// Teacher list (Ionic teachers.page): "Lehrer", rows with name, instrument
/// names and a "n Spieler" badge; FAB opens the "Lehrer hinzufügen" sheet,
/// tapping a row opens "Lehrer bearbeiten".
class TeachersListPage extends ConsumerWidget {
  const TeachersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(enrichedTeachersProvider);
    final currentRole = ref.watch(currentRoleProvider);
    // Ionic teachers.page isAdmin = Admin or Responsible
    final isAdmin = currentRole.isAdmin || currentRole.isResponsible;

    Future<void> refresh() async {
      ref.invalidate(teachersProvider);
      ref.invalidate(studentCountsProvider);
      ref.invalidate(enrichedTeachersProvider);
      await ref.read(enrichedTeachersProvider.future);
    }

    // UX_PEOPLE: Ionic teachers.page — condensed large title on iOS,
    // plain ion-list with ion-items, glass FAB.
    return IonPage(
      title: context.l10n.teachersTitle,
      onRefresh: refresh,
      slivers: [
        ...teachersAsync.when(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: AppSpinner()),
            ),
          ],
          error: (error, stack) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: IonNoData(
                icon: Icons.error_outline,
                label: context.l10n.teachersFlutterLoadFailed,
                actions: [
                  (
                    context.l10n.messagesRetry,
                    () => ref.invalidate(enrichedTeachersProvider),
                  ),
                ],
              ),
            ),
          ],
          data: (teachers) => [
            SliverList.builder(
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return _TeacherTile(
                  teacher: teacher,
                  // Ionic openModal: `if (!this.isAdmin) return;`
                  onTap: isAdmin
                      ? () => _openTeacherPage(context, ref, teacher)
                      : null,
                );
              },
            ),
          ],
        ),
      ],
      floatingActionButton: TabBarFab.wrap(isAdmin
          ? IonFabButton(onPressed: () => showAddTeacherSheet(context, ref))
          : null),
    );
  }

  /// Ionic TeacherPage modal ("Lehrer bearbeiten").
  Future<void> _openTeacherPage(
    BuildContext context,
    WidgetRef ref,
    Teacher teacher,
  ) async {
    final groups = await loadTeacherGroups(ref);
    if (!context.mounted) return;
    final result = await Navigator.of(context, rootNavigator: true).push<Teacher>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TeacherEditPage(
          teacher: teacher,
          availableInstruments: groups,
        ),
      ),
    );

    if (result != null && teacher.id != null) {
      try {
        await ref.read(teacherNotifierProvider.notifier).updateTeacher(
          teacher.id!,
          {
            'name': result.name,
            'number': result.number,
            'notes': result.notes,
            'private': result.isPrivate,
            'instruments': result.instruments,
          },
        );
        if (context.mounted) {
          ToastHelper.showSuccess(context, context.l10n.teachersUpdated);
        }
      } catch (e) {
        if (context.mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }
}

class _TeacherTile extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;

  // Ionic teachers.page has no delete action (TeacherService.deleteTeacher
  // has no caller), so the list offers none either.
  const _TeacherTile({
    required this.teacher,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = teacher.playerCount ?? 0;
    return IonItem(
      onTap: onTap,
      end: [
        IonBadge(
          text: context.l10n.teachersPlayerCount(count),
          color: count > 0 ? AppColors.primary : AppColors.danger,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(teacher.name, style: IonText.h2(context)),
          if (teacher.insNames?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(teacher.insNames!, style: IonText.h3(context)),
            ),
        ],
      ),
    );
  }
}

/// Form fields shared by "Lehrer hinzufügen" and "Lehrer bearbeiten"
/// (Ionic order: Name, Instrumente, Privatlehrer, Kontakt, Notizen).
class _TeacherForm extends StatefulWidget {
  const _TeacherForm({
    this.teacher,
    required this.availableInstruments,
    this.players = const [],
  });

  final Teacher? teacher;
  final List<Group> availableInstruments;

  /// Names of the players of this teacher (edit only)
  final List<String> players;

  @override
  State<_TeacherForm> createState() => _TeacherFormState();
}

class _TeacherFormState extends State<_TeacherForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _notesController;
  late bool _private;
  late Set<int> _selectedInstruments;

  bool get _isNew => widget.teacher == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.teacher?.name ?? '');
    _numberController =
        TextEditingController(text: widget.teacher?.number ?? '');
    _notesController = TextEditingController(text: widget.teacher?.notes ?? '');
    _private = widget.teacher?.isPrivate ?? false;
    _selectedInstruments = Set<int>.from(widget.teacher?.instruments ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickInstruments() async {
    final selected = Set<int>.from(_selectedInstruments);
    final result = await showAppDialog<Set<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppAlertDialog(
          title: Text(context.l10n.teachersInstruments),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final g in widget.availableInstruments)
                  if (g.id != null)
                    CheckboxListTile(
                      title: Text(g.name),
                      value: selected.contains(g.id),
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          selected.add(g.id!);
                        } else {
                          selected.remove(g.id!);
                        }
                      }),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(context.l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _selectedInstruments = result);
  }

  void _submit() {
    if (!isTeacherFormValid(
      isNew: _isNew,
      name: _nameController.text,
      instruments: _selectedInstruments,
    )) {
      ToastHelper.showError(context, context.l10n.teachersFillAll);
      return;
    }
    Navigator.pop(
      context,
      Teacher(
        id: widget.teacher?.id,
        name: _nameController.text.trim(),
        number: _numberController.text.trim(),
        notes: _notesController.text.trim(),
        isPrivate: _private,
        instruments: _selectedInstruments.toList(),
        tenantId: widget.teacher?.tenantId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.availableInstruments
        .where((g) => _selectedInstruments.contains(g.id))
        .map((g) => g.name)
        .join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isNew) ...[
            Text(context.l10n.teachersAdd,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: context.l10n.typeSettingsName),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.teachersInstruments),
            subtitle: names.isEmpty ? null : Text(names),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: _pickInstruments,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.teachersPrivate),
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          TextField(
            controller: _numberController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.l10n.teachersContact),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: context.l10n.peopleNotes),
            minLines: 1,
            maxLines: 5,
          ),
          if (widget.players.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            ExpansionTile(
              title: Text(context.l10n.teachersPlayers),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              children: [
                for (final p in widget.players)
                  ListTile(contentPadding: EdgeInsets.zero, title: Text(p)),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          FilledButton(
            onPressed: _submit,
            child: IonButtonLabel(_isNew ? context.l10n.attendanceAdd : context.l10n.teachersUpdate),
          ),
        ],
      ),
    );
  }
}

/// Ionic TeacherPage: full-screen "Lehrer bearbeiten" with a close button.
class _TeacherEditPage extends ConsumerWidget {
  const _TeacherEditPage({
    required this.teacher,
    required this.availableInstruments,
  });

  final Teacher teacher;
  final List<Group> availableInstruments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = (ref.watch(playersProvider).valueOrNull ?? const [])
        .where((p) => teacher.id != null && p.teacher == teacher.id)
        .map((p) => '${p.firstName} ${p.lastName}')
        .toList();
    return Scaffold(
      // PARITY_R5: teacher.page.html `<ion-content>` without colour → white.
      backgroundColor: ionPlainContentBackground(context),
      appBar: AppBar(
        title: Text(context.l10n.teachersEdit),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _TeacherForm(
        teacher: teacher,
        availableInstruments: availableInstruments,
        players: players,
      ),
    );
  }
}
