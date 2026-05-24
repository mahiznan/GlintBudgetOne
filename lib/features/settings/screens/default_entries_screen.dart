import 'package:flutter/material.dart';

class DefaultEntriesScreen extends StatelessWidget {
  const DefaultEntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default Entries')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
