import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/notes/notes_page.dart';

void main() {
  runApp(const CapyNotesApp());
}

class CapyNotesApp extends StatelessWidget {
  const CapyNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capy Notes',
      debugShowCheckedModeBanner: false,
      theme: buildCapyTheme(),
      home: const NotesPage(),
    );
  }
}
