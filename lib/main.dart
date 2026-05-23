// lib/main.dart
// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kIsWeb) {
    // IndexedDB-backed offline cache for web. Silent catch: some browsers
    // block IndexedDB (private mode, extensions), which is acceptable.
    FirebaseFirestore.instance
        .enablePersistence(const PersistenceSettings(synchronizeTabs: true))
        .catchError((_) {});
  }
  runApp(const ProviderScope(child: App()));
}
