import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart';

CollectionReference<Map<String, dynamic>> _txCollection() =>
    FirebaseFirestore.instance.collection('transactions');

Future<void> addTransaction(Transaction t) =>
    _txCollection().doc(t.id).set(t.toFirestore());

Future<void> updateTransaction(Transaction t) =>
    _txCollection().doc(t.id).set(t.toFirestore(), SetOptions(merge: true));

Future<void> deleteTransaction(String id) =>
    _txCollection().doc(id).delete();
