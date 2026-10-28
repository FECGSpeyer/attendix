import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/live_activity_repository.dart';
import 'tenant_providers.dart';

// LIVE_ACTIVITY: the service itself lives in
// core/services/live_activity_service.dart (liveActivityServiceProvider).

/// LiveActivityRepository with tenant set
final liveActivityRepositoryWithTenantProvider = Provider<LiveActivityRepository>((ref) {
  final repo = ref.watch(liveActivityRepositoryProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId != null) repo.setTenantId(tenantId);
  return repo;
});
