import 'package:flutter/material.dart';

import 'chats.dart';

// --- API config (no auth yet; test header) ---
const String apiBaseUrl = 'http://10.42.3.100:3000';
Map<String, String> get apiHeaders => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-User-Id': '12345',
};

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ChatPage());
  }
}

