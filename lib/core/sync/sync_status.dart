enum SyncStatus { synced, pending, offline }

SyncStatus syncStatusFromFlags({
  required bool hasPendingWrites,
  required bool isFromCache,
}) {
  if (hasPendingWrites) return SyncStatus.pending;
  if (isFromCache) return SyncStatus.offline;
  return SyncStatus.synced;
}
