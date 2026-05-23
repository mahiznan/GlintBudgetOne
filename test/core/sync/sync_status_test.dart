import 'package:flutter_test/flutter_test.dart';
import 'package:glintbudgetone/core/sync/sync_status.dart';

void main() {
  group('syncStatusFromFlags', () {
    test('hasPendingWrites → pending', () {
      expect(
        syncStatusFromFlags(hasPendingWrites: true, isFromCache: false),
        SyncStatus.pending,
      );
    });

    test('isFromCache → offline', () {
      expect(
        syncStatusFromFlags(hasPendingWrites: false, isFromCache: true),
        SyncStatus.offline,
      );
    });

    test('neither → synced', () {
      expect(
        syncStatusFromFlags(hasPendingWrites: false, isFromCache: false),
        SyncStatus.synced,
      );
    });

    test('hasPendingWrites takes priority over isFromCache', () {
      // Firestore can have pending writes while from cache simultaneously.
      expect(
        syncStatusFromFlags(hasPendingWrites: true, isFromCache: true),
        SyncStatus.pending,
      );
    });
  });
}
