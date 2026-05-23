// lib/core/store/firestore_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/preference.dart';
import '../models/transaction.dart';

/// Raw Firebase auth stream. Used by other providers to get the current uid.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// All transactions for the signed-in user, ordered by date descending.
/// Returns an empty list when unauthenticated.
final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('transactions')
      .where('user_id', isEqualTo: uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map(Transaction.fromFirestore).toList());
});

/// Raw preference DocumentSnapshot — metadata preserved for syncStatusProvider.
/// Returns a null stream when unauthenticated.
final preferenceSnapshotProvider = StreamProvider<DocumentSnapshot?>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('preference')
      .doc(uid)
      .snapshots()
      .cast<DocumentSnapshot?>();
});

/// Decoded Preference. Derives from preferenceSnapshotProvider.
/// Always has a value (Preference.defaults() when loading or doc absent).
final preferenceStreamProvider = Provider<Preference>((ref) {
  final snapshot = ref.watch(preferenceSnapshotProvider).valueOrNull;
  if (snapshot == null || !snapshot.exists) return Preference.defaults();
  return Preference.fromFirestore(snapshot);
});
