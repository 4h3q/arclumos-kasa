import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db/app_db.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.init(); // opens db + seeds defaults
  runApp(const ArclumosKasaApp());
}

class ArclumosKasaApp extends StatelessWidget {
  const ArclumosKasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARCLUMOS Kasa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  String? _userId;

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return LoginScreen(
        onLogin: (userId) => setState(() => _userId = userId),
      );
    }
    return HomeScreen(
      userId: _userId!,
      onLogout: () => setState(() => _userId = null),
    );
  }
}
