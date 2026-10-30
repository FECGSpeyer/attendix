import 'package:flutter/material.dart';
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
import '../../../../l10n/l10n.dart';
import 'ion_items.dart';
import 'plan_export_actions.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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
    builder: (context) => FractionallySizedBox(
      heightFactor: 1,
      child: RegisterPlanSheet(attendanceDate: attendanceDate),
    ),
  );
}

/// Registerprobenplan generator (Ionic planning.page `createPlan` modal):
/// editable groups (persisted per instance), editable conductors
/// ("Vorname N."), total time, export as PDF or per Telegram (PDF / Bild).
class RegisterPlanSheet extends ConsumerStatefulWidget {
  const RegisterPlanSheet({super.key, this.attendanceDate});

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
  final _minutesController = TextEditingController(text: '60');
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
            IconButton(icon: Icon(Icons.close, semanticLabel: context.l10n.commonClose), onPressed: () => Navigator.pop(context)),
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
                      icon: Icons.people_outline,
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
                      icon: Icons.person_outline,
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
                    leading: const Icon(Icons.schedule, color: AppColors.medium),
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
                  icon: const Icon(Icons.description_outlined),
                  label: IonButtonLabel(l10n.planningExport),
                ),
                if (chatId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _disabled ? null : () => _createPlan(perTelegram: true),
                    icon: const Icon(Icons.send_outlined),
                    label: IonButtonLabel(l10n.planningTelegramPdfShort),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _disabled ? null : () => _createPlan(perTelegram: true, asImage: true),
                    icon: const Icon(Icons.image_outlined),
                    label: IonButtonLabel(l10n.planningTelegramImageShort),
                  ),
                ],
              ],
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
        icon: Icon(Icons.add_circle_outline, semanticLabel: context.l10n.a11yIncrease),
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
              icon: Icon(Icons.highlight_off, semanticLabel: context.l10n.commonRemove),
              color: AppColors.danger,
              onPressed: onRemove,
            ),
    );
  }

  /// Ionic `createPlan(timeString, modal, perTelegram, asImage)`.
  Future<void> _createPlan({bool perTelegram = false, bool asImage = false}) async {
    final l10n = context.l10n;
    final groups = _groupValues;
    await _saveGroups(groups);

    final plan = RegisterPlanService.generate(
      conductors: RegisterPlanService.shuffle(_conductorValues),
      groups: groups,
      totalMinutes: num.tryParse(_minutesController.text.trim()) ?? 0,
    );
    final tenant = ref.read(currentTenantProvider);
    final shortName = tenant?.shortName ?? '';
    final date = DateFormat(dateFmt()).format(widget.attendanceDate ?? DateTime.now());

    setState(() => _busy = true);
    try {
      final branding = ref.read(includeBrandingProvider) ? await resolvePdfBranding(ref) : null;
      final pdf = await buildRegisterPlanPdf(
        plan,
        title: l10n.planningSectionalPlanTitle(shortName),
        subtitle: l10n.planningAsOf(date),
        minutesLabel: l10n.planningMinutes,
        branding: branding,
      );

      if (perTelegram) {
        final chatId = planTelegramChatId(ref);
        if (chatId == null) return;
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
          if (mounted) ToastHelper.showSuccess(context, l10n.svcMessageSent);
        } catch (_) {
          if (mounted) ToastHelper.showError(context, l10n.svcSendMessageFailed);
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => pdf,
          name: '$shortName Registerprobenplan: $date.pdf',
        );
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.planningFlutterExportFailed(friendlyErrorMessage(e)));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (mounted) Navigator.pop(context);
  }
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

  final doc = pw.Document();
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
