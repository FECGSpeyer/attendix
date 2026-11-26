import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/church_providers.dart';
import '../../../core/providers/files_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/tenant/tenant.dart';
import '../../../data/repositories/extra_fields_repository.dart';
import '../../../data/repositories/song_repository.dart'
    show songRepositoryForTenantProvider;
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/adaptive/adaptive.dart';

enum ExtraFieldTarget { person, song }

/// Extra field id derived from [name] (lowercase, underscores).
String extraFieldIdFromName(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

String extraFieldTypeName(String type) {
  final l10n = l10nWithoutContext;
  switch (type) {
    case 'text':
      return l10n.typeSettingsText;
    case 'textarea':
      return l10n.extraFieldsTextarea;
    case 'number':
      return l10n.extraFieldsNumber;
    case 'select':
      return l10n.extraFieldsSelect;
    case 'date':
      return l10n.attendanceDate;
    case 'boolean':
      return l10n.extraFieldsYesNo;
    case 'bfecg_church':
      return l10n.extraFieldsChurch;
    default:
      return type;
  }
}

/// Summary lines describing an extra field in the list.
List<String> extraFieldSummaryLines(
  AppLocalizations l10n,
  ExtraField f, {
  required bool person,
}) =>
    [
      if (f.id != 'bfecg_church')
        l10n.extraFieldsTypeLine(extraFieldTypeName(f.type)),
      l10n.extraFieldsDisplayLine(
        f.displayMode == 'underneath'
            ? l10n.extraFieldsUnderName
            : l10n.extraFieldsAsChip,
      ),
      if (person && (f.visibleToPlayers ?? false))
        '${l10n.extraFieldsVisible}${(f.editableByPlayers ?? false) ? l10n.extraFieldsEditableSuffix : ''}',
    ];

/// `ref.read` of a widget or `ProviderContainer.read`.
typedef ProviderRead = T Function<T>(ProviderListenable<T> provider);

/// Church ids for the default of a BFECG church field.
List<Object> extraFieldChurchIds(ProviderRead read) =>
    (read(churchesProvider).valueOrNull ?? [])
        .map((c) => c.id)
        .whereType<String>()
        .toList();

/// Saves field definitions of [repo]'s tenant, cleans values of persons and
/// (own library only) works, then updates local tenant state if still current.
Future<void> saveExtraFieldDefinitions(
  ProviderRead read,
  ExtraFieldsRepository repo, {
  required List<ExtraField> personFields,
  required List<ExtraField> songFields,
  required List<Object> churchIds,
}) async {
  final tenantId = repo.currentTenantId;
  final songSettings = await read(
    songRepositoryForTenantProvider((tenantId: tenantId, songSourceTenantId: null)),
  ).getSongTenantSettings();
  final songTenantId = songSettings.songSourceTenantId ?? tenantId;
  final before = read(currentTenantProvider);
  final previous = before?.id == tenantId ? before : null;
  final previousPersons = previous?.additionalFields;
  final previousSongs = previous?.songAdditionalFields;
  await repo.saveFields(personFields: personFields, songFields: songFields);
  await repo.sanitizeValues(
    table: 'player',
    definitions: personFields,
    churchIds: churchIds,
    previousIds: previousPersons?.map((f) => f.id).toSet(),
    renamedOptions: previousPersons == null
        ? null
        : renamedExtraFieldOptions(previousPersons, personFields),
  );
  if (songTenantId == tenantId) {
    await repo.sanitizeValues(
      table: 'songs',
      definitions: songFields,
      songTenantId: tenantId,
      previousIds: previousSongs?.map((f) => f.id).toSet(),
      renamedOptions: previousSongs == null
          ? null
          : renamedExtraFieldOptions(previousSongs, songFields),
    );
  }

  await read(currentTenantProvider.notifier).updateTenantLocalIfCurrent(
        tenantId,
        (current) => current.copyWith(
          additionalFields: personFields,
          songAdditionalFields: songFields,
        ),
      );
}

/// Add/edit bottom sheet for an [ExtraField].
Future<ExtraField?> showExtraFieldSheet(
  BuildContext context,
  WidgetRef ref, {
  required ExtraFieldTarget target,
  required List<ExtraField> Function() fields,
  ExtraField? existing,
}) async {
  final isEdit = existing != null;
  final isPerson = target == ExtraFieldTarget.person;
  final tenantId = ref.read(currentTenantIdProvider);
  final extraFieldsRepo = ref.read(extraFieldsRepositoryWithTenantProvider);
  final nameController = TextEditingController(text: existing?.name ?? '');
  final initialDefaultText = existing != null &&
          existing.type != 'boolean' &&
          existing.defaultValue != null &&
          existing.defaultValue != false
      ? '${existing.defaultValue}'
      : '';
  final defaultController = TextEditingController(text: initialDefaultText);
  var type = existing?.type ?? 'text';
  var displayMode = existing?.displayMode ?? 'chip';
  var visible = existing?.visibleToPlayers ?? false;
  var editable = existing?.editableByPlayers ?? false;
  final initialBoolDefault = existing?.type == 'boolean' &&
      (existing?.defaultValue == null || existing?.defaultValue == true);
  var boolDefault = initialBoolDefault;
  final options = <TextEditingController>[
    for (final o in existing?.options ?? const <String>[])
      TextEditingController(text: o),
  ];
  final originalOptions = [...?existing?.options];

  dynamic editedDefault() {
    if (type == 'boolean') {
      return isEdit && boolDefault == initialBoolDefault
          ? existing.defaultValue
          : boolDefault;
    }
    if (type == 'bfecg_church') return existing?.defaultValue;
    if (isEdit && defaultController.text == initialDefaultText) {
      return existing.defaultValue;
    }
    return _parseExtraFieldDefault(type, defaultController.text);
  }

  ExtraField buildField(String id) {
    final optionValues = options.map((c) => c.text).toList();
    return ExtraField(
      id: id,
      name: nameController.text.trim(),
      type: type,
      defaultValue: type == 'select'
          ? (optionValues.isNotEmpty ? optionValues.first : existing?.defaultValue)
          : editedDefault(),
      options: type == 'select' ? optionValues : const [],
      visibleToPlayers: isPerson ? visible : false,
      editableByPlayers: isPerson && visible ? editable : false,
      displayMode: displayMode,
    );
  }

  var disposed = false;
  void disposeControllers() {
    if (disposed) return;
    disposed = true;
    nameController.dispose();
    defaultController.dispose();
    for (final c in options) {
      c.dispose();
    }
  }

  Widget sheet(BuildContext sheetContext) => _DisposeOnUnmount(
        onDispose: disposeControllers,
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> removeOption(int i) async {
              final value = options[i].text;
              if (isEdit && value.isNotEmpty && originalOptions.contains(value)) {
                final ok = await DialogHelper.showConfirmation(
                  ctx,
                  title: context.l10n.extraFieldsDeleteOption,
                  message: context.l10n.extraFieldsDeleteOptionMessage(value),
                  confirmText: context.l10n.commonDelete,
                  isDestructive: true,
                );
                if (!ok) return;
                if (isPerson) {
                  if (!ctx.mounted) return;
                  final current = options.map((c) => c.text).toList();
                  final newDefault = current.first == value
                      ? (current.length > 1 ? current[1] : '')
                      : current.first;
                  final rootNav = Navigator.of(ctx, rootNavigator: true);
                  unawaited(showDialog<void>(
                    context: ctx,
                    useRootNavigator: true,
                    barrierDismissible: false,
                    builder: (_) => _MigratingOverlay(
                      label: context.l10n.extraFieldsFlutterUpdatingPersons,
                    ),
                  ));
                  try {
                    final count = await extraFieldsRepo.updateFieldValue(
                      existing.id,
                      value,
                      newDefault,
                    );
                    if (count > 0 && context.mounted) {
                      ToastHelper.showSuccess(
                        context,
                        context.l10n.extraFieldsPersonsUpdated(count),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
                    }
                    return;
                  } finally {
                    rootNav.pop();
                  }
                }
              }
              if (!ctx.mounted || i >= options.length) return;
              setSheet(() => options.removeAt(i).dispose());
            }

            Future<void> resetValues() async {
              final ok = await DialogHelper.showConfirmation(
                ctx,
                title: context.l10n.extraFieldsResetValues,
                message: context.l10n.extraFieldsResetValuesMessage(nameController.text),
                confirmText: context.l10n.dashSettingsReset,
                isDestructive: true,
              );
              if (!ok || !ctx.mounted) return;
              final resolved = extraFieldDefaultValue(
                type,
                defaultValue: type == 'select' ? null : editedDefault(),
                options: options.map((c) => c.text).toList(),
                churchIds: extraFieldChurchIds(ref.read),
              );
              try {
                final count = await extraFieldsRepo.resetFieldValues(
                  existing!.id,
                  resolved,
                );
                if (context.mounted) {
                  ToastHelper.showSuccess(
                    context,
                    context.l10n.extraFieldsPersonsUpdated(count),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
                }
              }
            }

            void submit() {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ToastHelper.showError(ctx, context.l10n.extraFieldsInvalidName);
                return;
              }
              final id = type == 'bfecg_church'
                  ? 'bfecg_church'
                  : extraFieldIdFromName(name);
              if (fields().any((f) => f.id == id)) {
                ToastHelper.showError(ctx, context.l10n.extraFieldsIdExists);
                return;
              }
              if (type == 'select') {
                final optionValues = options.map((c) => c.text).toList();
                if (optionValues.isEmpty) {
                  ToastHelper.showError(ctx, context.l10n.extraFieldsAddOption);
                  return;
                }
                if (optionValues.any((o) => o.trim().isEmpty)) {
                  ToastHelper.showError(ctx, context.l10n.extraFieldsOptionsEmpty);
                  return;
                }
              }
              if (id.isEmpty) {
                ToastHelper.showError(ctx, context.l10n.extraFieldsIdEmpty);
                return;
              }
              Navigator.pop(sheetContext, buildField(id));
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppDimensions.paddingM,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEdit
                                  ? context.l10n.typeSettingsEditField
                                  : context.l10n.extraFieldsAddNew,
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              AppIcons.close,
                              semanticLabel: context.l10n.commonClose,
                            ),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      if (isEdit)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.typeSettingsType),
                          trailing: Text(extraFieldTypeName(type)),
                        )
                      else
                        AppDropdownFormField<String>(
                          interface: AppSelectInterface.alert,
                          value: type,
                          decoration: InputDecoration(
                            labelText: context.l10n.typeSettingsType,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'text',
                              child: Text(context.l10n.typeSettingsText),
                            ),
                            DropdownMenuItem(
                              value: 'number',
                              child: Text(context.l10n.extraFieldsNumber),
                            ),
                            DropdownMenuItem(
                              value: 'boolean',
                              child: Text(context.l10n.extraFieldsYesNo),
                            ),
                            DropdownMenuItem(
                              value: 'select',
                              child: Text(context.l10n.extraFieldsSelect),
                            ),
                            if (isPerson && tenantId == 12)
                              DropdownMenuItem(
                                value: 'bfecg_church',
                                child: Text(context.l10n.extraFieldsChurch),
                              ),
                          ],
                          onChanged: (v) => setSheet(() {
                            type = v ?? 'text';
                            boolDefault = false;
                            defaultController.text = type == 'number' ? '0' : '';
                          }),
                        ),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: context.l10n.typeSettingsName,
                        ),
                      ),
                      if (isEdit)
                        AppDropdownFormField<String>(
                          interface: AppSelectInterface.alert,
                          value: displayMode,
                          decoration: InputDecoration(
                            labelText: context.l10n.extraFieldsDisplay,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'chip',
                              child: Text(context.l10n.extraFieldsAsChip),
                            ),
                            DropdownMenuItem(
                              value: 'underneath',
                              child: Text(context.l10n.extraFieldsUnderName),
                            ),
                          ],
                          onChanged: (v) =>
                              setSheet(() => displayMode = v ?? 'chip'),
                        ),
                      if (isPerson) ...[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.extraFieldsVisible),
                          subtitle: Text(context.l10n.extraFieldsVisibleHelper),
                          value: visible,
                          onChanged: (v) => setSheet(() => visible = v),
                        ),
                        if (visible)
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.l10n.extraFieldsEditable),
                            subtitle: Text(context.l10n.extraFieldsEditableHelper),
                            value: editable,
                            onChanged: (v) => setSheet(() => editable = v),
                          ),
                      ],
                      if (type == 'select') ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.typeSettingsOptions,
                                style: Theme.of(ctx).textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                AppIcons.add,
                                semanticLabel: context.l10n.a11yAdd,
                              ),
                              onPressed: () =>
                                  setSheet(() => options.add(TextEditingController())),
                            ),
                          ],
                        ),
                        if (options.isEmpty)
                          Text(
                            isEdit
                                ? context.l10n.extraFieldsNoOptions
                                : context.l10n.extraFieldsNoOptionsSelected,
                            style: TextStyle(color: AppColors.mediumOf(context)),
                          ),
                        for (var i = 0; i < options.length; i++)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: options[i],
                                  textCapitalization: TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: context.l10n.extraFieldsValuePh,
                                    helper: i == 0
                                        ? Text(
                                            context.l10n.extraFieldsFlutterFirstOptionDefault,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  AppIcons.deleteOutline,
                                  color: AppColors.danger,
                                  semanticLabel: context.l10n.commonDelete,
                                ),
                                onPressed: () => removeOption(i),
                              ),
                            ],
                          ),
                      ],
                      if (type != 'select' && type != 'bfecg_church') ...[
                        if (type == 'boolean')
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.l10n.extraFieldsDefaultValue),
                            value: boolDefault,
                            onChanged: (v) => setSheet(() => boolDefault = v),
                          )
                        else
                          TextField(
                            controller: defaultController,
                            keyboardType: type == 'number'
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: isEdit
                                  ? context.l10n.extraFieldsDefaultValue
                                  : context.l10n.extraFieldsDefaultOptional,
                            ),
                          ),
                      ],
                      if (isEdit && isPerson)
                        TextButton(
                          onPressed: resetValues,
                          child: Text(
                            context.l10n.extraFieldsResetAll,
                            style: const TextStyle(color: AppColors.warning),
                          ),
                        ),
                      if (!isEdit)
                        ElevatedButton(
                          onPressed: submit,
                          child: Text(context.l10n.typeSettingsAddField),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

  final result = await showModalBottomSheet<ExtraField>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: sheet,
  );
  if (isEdit) return buildField(existing.id);
  return result;
}

dynamic _parseExtraFieldDefault(String type, String text) {
  if (type == 'number') return num.tryParse(text.trim()) ?? 0;
  return text;
}

class _MigratingOverlay extends StatelessWidget {
  const _MigratingOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        key: const ValueKey('extra-fields-migrating'),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppSpinner(strokeWidth: 2),
                ),
                const SizedBox(width: AppDimensions.paddingM),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisposeOnUnmount extends StatefulWidget {
  const _DisposeOnUnmount({required this.onDispose, required this.child});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_DisposeOnUnmount> createState() => _DisposeOnUnmountState();
}

class _DisposeOnUnmountState extends State<_DisposeOnUnmount> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
