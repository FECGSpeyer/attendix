import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/base_repository.dart';

/// SETTINGS2: Ionic settings "Administratoren" modal (super admins only):
/// list with "Erstellt am", tap to remove, + to add an admin by e-mail.
Future<void> showAdminsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _AdminsSheet(),
    ),
  );
}

String _errorText(Object e) =>
    e is RepositoryException ? e.message : (e is AdminException ? e.message : '$e');

class _AdminsSheet extends ConsumerWidget {
  const _AdminsSheet();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin hinzufügen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'E-Mail-Adresse'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !context.mounted) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ToastHelper.showError(context, 'Bitte gib eine gültige E-Mail-Adresse ein.');
      return;
    }
    try {
      await ref.read(adminNotifierProvider.notifier).create(email);
      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Der Admin wurde erfolgreich hinzugefügt.');
      }
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, _errorText(e));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, TenantAdmin admin) async {
    final ownId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (admin.userId == ownId) {
      ToastHelper.showError(context, 'Du kannst dich nicht selbst entfernen.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin entfernen?'),
        content: Text('Möchtest du ${admin.email ?? ''} wirklich entfernen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(adminNotifierProvider.notifier).remove(admin.userId);
      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Der Admin wurde erfolgreich entfernt.');
      }
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(adminsProvider);
    final busy = ref.watch(adminNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administratoren'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: busy ? null : () => _add(context, ref),
        child: busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          const Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.verified_user_outlined, size: 40, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text(
                    'Administratoren haben alle Rechte in der Instanz und können auch die Instanz löschen.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          ...adminsAsync.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [ListTile(title: Text('Fehler: ${_errorText(e)}'))],
            data: (admins) => admins
                .map((a) => ListTile(
                      title: Text(a.email ?? ''),
                      subtitle: a.createdAt != null
                          ? Text('Erstellt am: ${DateFormat('dd.MM.yyyy').format(a.createdAt!.toLocal())}')
                          : null,
                      onTap: () => _remove(context, ref, a),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
