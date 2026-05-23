import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/currency.dart';

DocumentReference<Map<String, dynamic>> _prefDoc(String uid) =>
    FirebaseFirestore.instance.collection('preference').doc(uid);

Future<void> updateTheme(String uid, String themeId) =>
    _prefDoc(uid).set({'themeId': themeId}, SetOptions(merge: true));

Future<void> updateSpendingChartType(String uid, String chartType) =>
    _prefDoc(uid).set({'spendingChartType': chartType}, SetOptions(merge: true));

Future<void> updateDefaultCurrency(String uid, Currency currency) =>
    _prefDoc(uid).set(
      {'default_currency': currency.toFirestore()},
      SetOptions(merge: true),
    );

/// Writes entries as a Firestore Map (normalised format), regardless of how
/// they were originally stored by the Swift app.
Future<void> updateDefaultEntries(String uid, Map<String, String> entries) =>
    _prefDoc(uid).set({'default_entries': entries}, SetOptions(merge: true));
