import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/team_org/team_org.dart';
import 'base_repository.dart';

/// Provider for AgendaItemRepository
final agendaItemRepositoryProvider = Provider<AgendaItemRepository>((ref) {
  return AgendaItemRepository(ref);
});

/// Select with the joined responsible person and proposer (Ionic AGENDA_ITEM_SELECT).
const String agendaItemSelect =
    '*, responsible_person:player!responsible_person_id(id, firstName, lastName), proposer:player!proposed_by(id, firstName, lastName)';

/// Repository for topics of the Teamorganisation (table `agenda_items`).
///
/// The tenant column of this table is `tenant_id` (snake_case). RLS on top:
/// leadership sees all topics, members only their own suggestions.
class AgendaItemRepository extends BaseRepository with TenantAwareRepository {
  AgendaItemRepository(super.ref);

  /// Leadership: all topics. Members: only their own suggestions (RLS).
  Future<List<AgendaItem>> getAgendaItems() async {
    try {
      final response = await supabase
          .from('agenda_items')
          .select(agendaItemSelect)
          .eq('tenant_id', currentTenantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => AgendaItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAgendaItems');
      rethrow;
    }
  }

  Future<AgendaItem?> getAgendaItemById(String id) async {
    try {
      final response = await supabase
          .from('agenda_items')
          .select(agendaItemSelect)
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return AgendaItem.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getAgendaItemById');
      rethrow;
    }
  }

  Future<List<AgendaItem>> getAgendaItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await supabase
          .from('agenda_items')
          .select(agendaItemSelect)
          .inFilter('id', ids)
          .eq('tenant_id', currentTenantId);

      return (response as List)
          .map((e) => AgendaItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getAgendaItemsByIds');
      rethrow;
    }
  }

  /// Creates a topic (leadership).
  Future<AgendaItem> createAgendaItem(AgendaItem item) async {
    ensureNotDemo('createAgendaItem'); // DEMO_GUARD
    try {
      final data = <String, dynamic>{
        ..._writeFields(item),
        'tenant_id': currentTenantId,
      };

      final response = await supabase
          .from('agenda_items')
          .insert(data)
          .select(agendaItemSelect)
          .single();

      return AgendaItem.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createAgendaItem');
      rethrow;
    }
  }

  /// A member suggests a topic; it waits for the leadership's decision.
  /// Members can't read the row back before RLS lets them, so no select here.
  Future<void> proposeAgendaItem({
    required String title,
    String? description,
    required int proposedBy,
  }) async {
    ensureNotDemo('proposeAgendaItem'); // DEMO_GUARD
    try {
      await supabase.from('agenda_items').insert({
        'tenant_id': currentTenantId,
        'title': title,
        'description': description,
        'proposed_by': proposedBy,
        'status': 'open',
        'priority': 'medium',
        'proposal_status': 'pending',
      });
    } catch (e, stack) {
      handleError(e, stack, 'proposeAgendaItem');
      rethrow;
    }
  }

  /// Updates the given columns (snake_case keys) of a topic.
  Future<AgendaItem> updateAgendaItem(String id, Map<String, dynamic> updates) async {
    ensureNotDemo('updateAgendaItem'); // DEMO_GUARD
    try {
      final data = Map<String, dynamic>.from(updates)
        ..remove('id')
        ..remove('tenant_id')
        ..remove('created_at')
        ..remove('responsible_person')
        ..remove('proposer');

      final response = await supabase
          .from('agenda_items')
          .update(data)
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select(agendaItemSelect)
          .single();

      return AgendaItem.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updateAgendaItem');
      rethrow;
    }
  }

  Future<void> deleteAgendaItem(String id) async {
    ensureNotDemo('deleteAgendaItem'); // DEMO_GUARD
    try {
      final response = await supabase
          .from('agenda_items')
          .delete()
          .eq('id', id)
          .eq('tenant_id', currentTenantId)
          .select('id');

      if ((response as List).isEmpty) {
        throw const RepositoryException(
          message: 'Keine Berechtigung zum Löschen',
          operation: 'deleteAgendaItem',
        );
      }
    } catch (e, stack) {
      if (e is RepositoryException) rethrow;
      handleError(e, stack, 'deleteAgendaItem');
      rethrow;
    }
  }

  /// Verlauf eines Themas (RPC `get_agenda_item_history`).
  /// The function checks `is_tenant_leader(ai.tenant_id)` server-side; the
  /// topic id is first verified to belong to the current tenant.
  Future<List<AgendaItemHistoryEntry>> getHistory(String agendaItemId) async {
    try {
      final owned = await supabase
          .from('agenda_items')
          .select('id')
          .eq('id', agendaItemId)
          .eq('tenant_id', currentTenantId)
          .maybeSingle();
      if (owned == null) return [];

      final response = await supabase.rpc(
        'get_agenda_item_history',
        params: {'p_agenda_item_id': agendaItemId},
      );

      return ((response as List?) ?? const [])
          .map((e) => AgendaItemHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getHistory');
      rethrow;
    }
  }

  Map<String, dynamic> _writeFields(AgendaItem item) => {
        'title': item.title,
        'description': item.description,
        'status': item.status,
        'priority': item.priority,
        'responsible_person_id': item.responsiblePersonId,
        'default_duration': item.defaultDuration,
        if (item.proposedBy != null) 'proposed_by': item.proposedBy,
        if (item.proposalStatus != null) 'proposal_status': item.proposalStatus,
        if (item.decisionNote != null) 'decision_note': item.decisionNote,
      };
}
