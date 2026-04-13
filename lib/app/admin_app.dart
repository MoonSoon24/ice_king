import 'package:flutter/material.dart';

import '../screens/admin_screen.dart';
import '../screens/driver_screen.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Es King',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            AdminScreen(onToggleDashboard: () => setState(() => _index = 1)),
            DriverScreen(onToggleDashboard: () => setState(() => _index = 0)),
          ],
        ),
      ),
    );
  }
}
