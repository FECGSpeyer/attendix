import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/pdf_branding.dart';
import '../../../../core/services/register_plan_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/plan/plan.dart' show RegisterPlanSettings;
import '../../../../l10n/l10n.dart';
import 'ion_items.dart';
import 'plan_export_actions.dart';
import 'rd_register_setup_sheet.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/services/pdf_fonts.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

/// Opens the Registerprobenplan modal (Ionic `isPlanModalOpen`, a sheet with
/// breakpoints `[0, 1]`, i.e. full height).
///
/// [attendanceDate] is the date of the Termin selected in the editor (Ionic
/// uses it for "Stand: …"; today when none is selected).
Future<void> showRegisterPlanSheet(BuildContext context, {DateTime? attendanceDate}) async {
  await showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.rdSkin != null ? context.rd.bg : null,
    builder: (context) => FractionallySizedBox(
      heightFactor: 1,
      child: RegisterPlanSheet(attendanceDate: attendanceDate),
    ),
  );
}

/// What the Registerprobe sheet hands to the Beta Ablauf: the groups, the
/// conductors in the drawn order and the total minutes.
class RegisterPlanChoice {
  const RegisterPlanChoice({required this.groups, required this.conductors, required this.minutes});

  final List<String> groups;
  final List<String> conductors;
  final num minutes;
}

/// Beta Ablauf: the Registerprobe setup ([RdRegisterSetupSheet]) with a
/// preview (clock times from [startMinutes]) and "In den Ablauf einfügen"
/// ([initial]: change an existing Registerprobe, "Übernehmen"). Null when
/// closed without.
Future<RegisterPlanChoice?> showRegisterPlanInsertSheet(
  BuildContext context, {
  RegisterPlanSettings? initial,
  num? initialMinutes,
  int? startMinutes,
  String? subtitle,
}) {
  return showModalBottomSheet<RegisterPlanChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    builder:
        (context) => FractionallySizedBox(
          heightFactor: 1,
          child: RdRegisterSetupSheet(
            initial: initial,
            initialMinutes: initialMinutes,
            startMinutes: startMinutes,
            subtitle: subtitle,
          ),
        ),
  );
}

/// Registerprobenplan generator (Ionic planning.page `createPlan` modal):
/// editable groups (persisted per instance), editable conductors
/// ("Vorname N."), total time, export as PDF or per Telegram (PDF / Bild).
class RegisterPlanSheet extends ConsumerStatefulWidget {
  const RegisterPlanSheet({
    super.key,
    this.attendanceDate,
  });

  final DateTime? attendanceDate;

  @override
  ConsumerState<RegisterPlanSheet> createState() => _RegisterPlanSheetState();
}

class _Entry {
  _Entry(this.id, String text) : controller = TextEditingController(text: text);
  final int id;
  final TextEditingController controller;
}

class _RegisterPlanSheetState extends ConsumerState<RegisterPlanSheet> {
  final List<_Entry> _groups = [];
  final List<_Entry> _conductors = [];
  late final _minutesController = TextEditingController(text: '60');
  int _nextId = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final e in [..._groups, ..._conductors]) {
      e.controller.dispose();
    }
    _minutesController.dispose();
    super.dispose();
  }

  _Entry _entry(String text) {
    final e = _Entry(_nextId++, text);
    e.controller.addListener(_refresh);
    return e;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Ionic `showOptions` → `planGroups = loadPlanGroups()`, `planConductors = conductors…`.
  Future<void> _load() async {
    final l10n = l10nWithoutContext;
    final tenant = ref.read(currentTenantProvider);
    var categories = const <GroupCategory>[];
    var conductors = const <Person>[];
    try {
      categories = await ref.read(groupCategoriesProvider.future);
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'register_plan_sheet');
    }
    try {
      conductors = await ref.read(conductorsProvider.future);
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'register_plan_sheet');
    }
    final defaults = RegisterPlanService.defaultGroups(
      categoryNames: [for (final c in categories) c.name],
      isChoir: tenant?.type == 'choir',
      choirDefaults: [l10n.planningSoprano, l10n.planningAlto, l10n.planningTenor, l10n.planningBass],
      otherDefaults: [l10n.planningStrings, l10n.planningWoodwinds, l10n.commonOtherPlural],
    );
    String? stored;
    if (tenant?.id != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        stored = prefs.getString(RegisterPlanService.groupsStorageKey(tenant!.id!));
      } catch (_) {}
    }
    final groups = RegisterPlanService.parseStoredGroups(stored, defaults);
    final names = RegisterPlanService.conductorNames(conductors);
    if (!mounted) return;
    setState(() {
      _groups.addAll(groups.map(_entry));
      _conductors.addAll(names.map(_entry));
      _loading = false;
    });
  }

  Future<void> _saveGroups(List<String> groups) async {
    final tenantId = ref.read(currentTenantProvider)?.id;
    if (tenantId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(RegisterPlanService.groupsStorageKey(tenantId), RegisterPlanService.encodeGroups(groups));
    } catch (_) {}
  }

  List<String> get _groupValues => [for (final g in _groups) g.controller.text];
  List<String> get _conductorValues => [for (final c in _conductors) c.controller.text];

  bool get _disabled =>
      _busy ||
      RegisterPlanService.isExportDisabled(
        conductors: _conductorValues,
        groups: _groupValues,
        time: _minutesController.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Telegram buttons only when the user linked Telegram (Ionic `telegram_chat_id`).
    ref.watch(notificationConfigProvider);
    final chatId = planTelegramChatId(ref);
    final theme = Theme.of(context);
    if (context.rdSkin != null) return _buildBeta(context, chatId);

    return Scaffold(
      // Ionic: ion-content color="light" (grey grouped background).
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: ionModalToolbarHeight(context),
        automaticallyImplyLeading: false,
        title: Text(l10n.planningSectionalPlan),
        // IOS_PAGES3: iOS → ✕ in a Liquid Glass circle
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose), onPressed: () => Navigator.pop(context)),
          ]),
        ],
      ),
      body: _loading
          ? const Center(child: AppSpinner())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _listHeader(l10n.planningGroups, () => setState(() => _groups.add(_entry('')))),
                _insetList([
                  for (var i = 0; i < _groups.length; i++)
                    _inputRow(
                      key: ValueKey('group-${_groups[i].id}'),
                      icon: AppIcons.peopleOutline,
                      controller: _groups[i].controller,
                      hint: l10n.planningGroupName,
                      capitalization: TextCapitalization.sentences,
                      onRemove: _groups.length > 2 ? () => _remove(_groups, i) : null,
                    ),
                ]),
                const SizedBox(height: 16),
                _listHeader(l10n.planningConductors, () => setState(() => _conductors.add(_entry('')))),
                _insetList([
                  for (var i = 0; i < _conductors.length; i++)
                    _inputRow(
                      key: ValueKey('conductor-${_conductors[i].id}'),
                      icon: AppIcons.personOutline,
                      controller: _conductors[i].controller,
                      hint: l10n.planningName,
                      capitalization: TextCapitalization.words,
                      onRemove: _conductors.length > 1 ? () => _remove(_conductors, i) : null,
                    ),
                ]),
                const SizedBox(height: 16),
                _insetList([
                  // Ionic: ion-input with an inline start label.
                  ListTile(
                    leading: Icon(AppIcons.schedule, color: AppColors.medium),
                    title: Row(
                      children: [
                        Text(l10n.planningTimeMinutes),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _minutesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _disabled ? null : () => _createPlan(),
                  icon: Icon(AppIcons.descriptionOutlined),
                  label: IonButtonLabel(l10n.planningExport),
                ),
                if (chatId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _disabled ? null : () => _createPlan(perTelegram: true),
                    icon: Icon(AppIcons.sendOutlined),
                    label: IonButtonLabel(l10n.planningTelegramPdfShort),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _disabled ? null : () => _createPlan(perTelegram: true, asImage: true),
                    icon: Icon(AppIcons.imageOutlined),
                    label: IonButtonLabel(l10n.planningTelegramImageShort),
                  ),
                ],
              ],
            ),
    );
  }

  /// REDESIGN (Termin-Werkzeuge T1): the same generator in the Beta look.
  Widget _buildBeta(BuildContext context, String? chatId) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget input(
      _Entry e,
      String keyPrefix,
      IconData icon,
      String hint,
      TextCapitalization caps,
      VoidCallback? onRemove,
    ) => Padding(
      key: ValueKey('$keyPrefix-${e.id}'),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          RdRowIcon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: e.controller,
              textCapitalization: caps,
              style: TextStyle(fontSize: 17, color: p.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.text2),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.remove_circle_outline, semanticLabel: l10n.commonRemove),
              color: p.absent,
              onPressed: onRemove,
            ),
        ],
      ),
    );
    Widget addRow(String label, VoidCallback onTap) => RdListRow(
      leading: Icon(Icons.add, color: p.link),
      title: label,
      titleColor: p.link,
      showChevron: false,
      onTap: onTap,
    );
    final minutes = num.tryParse(_minutesController.text.trim()) ?? 0;
    void step(int delta) => setState(() {
      final next = (minutes + delta).clamp(0, 999);
      _minutesController.text = next == next.roundToDouble() ? '${next.round()}' : '$next';
    });
    Widget stepButton(IconData icon, String label, int delta) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => step(delta),
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: p.softText)),
        ),
      ),
    );
    return Material(
      color: p.bg,
      child: SafeArea(
        child: _loading
            ? const Center(child: AppSpinner())
            : ListView(
              // Keeps the export/Telegram buttons reachable above the keyboard.
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.viewInsetsOf(context).bottom),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.planningSectionalPlan,
                          style: RdType.title(p),
                        ),
                      ),
                    ),
                    RdCircleButton(icon: Icons.close, label: l10n.commonClose, onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                RdGroupLabel(l10n.planningGroups),
                RdGroupedList(
                  children: [
                    for (var i = 0; i < _groups.length; i++)
                      input(
                        _groups[i],
                        'group',
                        Icons.people_outline,
                        l10n.planningGroupName,
                        TextCapitalization.sentences,
                        _groups.length > 2 ? () => _remove(_groups, i) : null,
                      ),
                    addRow(l10n.planningGroups, () => setState(() => _groups.add(_entry('')))),
                  ],
                ),
                const SizedBox(height: 16),
                RdGroupLabel(l10n.planningConductors),
                RdGroupedList(
                  children: [
                    for (var i = 0; i < _conductors.length; i++)
                      input(
                        _conductors[i],
                        'conductor',
                        Icons.person_outline,
                        l10n.planningName,
                        TextCapitalization.words,
                        _conductors.length > 1 ? () => _remove(_conductors, i) : null,
                      ),
                    addRow(l10n.planningConductors, () => setState(() => _conductors.add(_entry('')))),
                  ],
                ),
                const SizedBox(height: 16),
                RdGroupLabel(l10n.planningTimeMinutes),
                RdCard(
                  child: Row(
                    children: [
                      stepButton(Icons.remove, l10n.redesignPlanLess, -5),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _minutesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: p.bg,
                            suffixText: l10n.redesignPlanMinUnit,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      stepButton(Icons.add, l10n.redesignPlanMore5, 5),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                RdPrimaryButton(
                  icon: Icons.description_outlined,
                  label: l10n.planningExport,
                  loading: _busy,
                  onPressed: _disabled ? null : () => _createPlan(),
                ),
                if (chatId != null) ...[
                  const SizedBox(height: 8),
                  RdOutlineButton(
                    icon: Icons.send_outlined,
                    label: l10n.planningTelegramPdfShort,
                    onPressed: _disabled ? null : () => _createPlan(perTelegram: true),
                  ),
                  const SizedBox(height: 8),
                  RdOutlineButton(
                    icon: Icons.image_outlined,
                    label: l10n.planningTelegramImageShort,
                    onPressed: _disabled ? null : () => _createPlan(perTelegram: true, asImage: true),
                  ),
                ],
              ],
            ),
      ),
    );
  }

  void _remove(List<_Entry> list, int index) {
    setState(() {
      final e = list.removeAt(index);
      e.controller.dispose();
    });
  }

  Widget _listHeader(String label, VoidCallback onAdd) {
    return IonListHeader(
      title: label,
      trailing: IconButton(
        icon: Icon(AppIcons.addCircleOutline, semanticLabel: context.l10n.a11yIncrease),
        color: AppColors.primary,
        onPressed: onAdd,
      ),
    );
  }

  Widget _insetList(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _inputRow({
    required Key key,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    required TextCapitalization capitalization,
    VoidCallback? onRemove,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon, color: AppColors.medium),
      title: TextField(
        controller: controller,
        textCapitalization: capitalization,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
      ),
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: Icon(AppIcons.highlightOff, semanticLabel: context.l10n.commonRemove),
              color: AppColors.danger,
              onPressed: onRemove,
            ),
    );
  }

  /// Ionic `createPlan(timeString, modal, perTelegram, asImage)`.
  Future<void> _createPlan({bool perTelegram = false, bool asImage = false}) async {
    final groups = _groupValues;
    await _saveGroups(groups);

    final plan = RegisterPlanService.generate(
      conductors: RegisterPlanService.shuffle(_conductorValues),
      groups: groups,
      totalMinutes: num.tryParse(_minutesController.text.trim()) ?? 0,
    );
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await exportRegisterPlan(
      context,
      ref,
      plan,
      attendanceDate: widget.attendanceDate,
      perTelegram: perTelegram,
      asImage: asImage,
    );
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context);
  }
}

/// Saves [plan] as PDF, or sends it per Telegram (PDF or [asImage]).
/// [timeLabel]: the first column's header ("Minuten" by default). False
/// when it failed (a toast says why) or Telegram is not linked.
Future<bool> exportRegisterPlan(
  BuildContext context,
  WidgetRef ref,
  RegisterPlan plan, {
  DateTime? attendanceDate,
  String? timeLabel,
  bool perTelegram = false,
  bool asImage = false,
}) async {
  final l10n = context.l10n;
  final tenant = ref.read(currentTenantProvider);
  final shortName = tenant?.shortName ?? '';
  final date = DateFormat(dateFmt()).format(attendanceDate ?? DateTime.now());
  try {
    final branding = ref.read(includeBrandingProvider) ? await resolvePdfBranding(ref) : null;
    final pdf = await buildRegisterPlanPdf(
      plan,
      title: l10n.planningSectionalPlanTitle(shortName),
      subtitle: l10n.planningAsOf(date),
      minutesLabel: timeLabel ?? l10n.planningMinutes,
      branding: branding,
    );

    if (perTelegram) {
      final chatId = planTelegramChatId(ref);
      if (chatId == null) return false;
      var bytes = pdf;
      if (asImage) {
        await for (final page in Printing.raster(pdf, pages: const [0], dpi: 150)) {
          bytes = await page.toPng();
          break;
        }
      }
      final now = DateTime.now();
      final stamp = '${now.day.toString().padLeft(2, '0')}_${now.month.toString().padLeft(2, '0')}_${now.year}';
      try {
        await ref.read(telegramServiceProvider).sendPlanPerTelegram(
              fileBytes: bytes,
              name: 'Registerprobenplan_$stamp',
              chatId: chatId,
              asImage: asImage,
            );
        if (context.mounted) ToastHelper.showSuccess(context, l10n.svcMessageSent);
      } catch (_) {
        if (context.mounted) ToastHelper.showError(context, l10n.svcSendMessageFailed);
      }
    } else {
      // Ionic `Utils.downloadFileNative`: save, not print.
      await NativeFileService.saveBytes(pdf, '$shortName Registerprobenplan: $date.pdf');
    }
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, l10n.planningFlutterExportFailed(friendlyErrorMessage(e)));
    return false;
  }
  return true;
}

/// PDF of a Registerprobenplan (Ionic autoTable, `theme: 'plain'`, A4
/// portrait, font 11, padding 3.5 mm, zebra rows, letterhead on every page).
Future<Uint8List> buildRegisterPlanPdf(
  RegisterPlan plan, {
  required String title,
  required String subtitle,
  required String minutesLabel,
  PdfBranding? branding,
}) async {
  const mm = PdfPageFormat.mm;
  const text = PdfColor.fromInt(0xFF1E1E1E);
  pw.Widget cell(String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(3.5 * mm),
        child: pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? const PdfColor.fromInt(0xFF323232) : text,
          ),
        ),
      );

  final doc = await PdfFonts.document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(14 * mm, 10 * mm, 14 * mm, 14 * mm),
    header: (_) => buildPdfBrandingHeader(branding: branding, title: title, subtitle: subtitle),
    build: (_) => [
      pw.Table(
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF646464), width: 0.5 * mm)),
            ),
            children: [cell(minutesLabel, bold: true), for (final g in plan.groups) cell(g, bold: true)],
          ),
          for (var i = 0; i < plan.rows.length; i++)
            pw.TableRow(
              decoration: i.isOdd ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)) : null,
              children: [for (final v in plan.rows[i]) cell(v)],
            ),
        ],
      ),
    ],
  ));
  return doc.save();
}
