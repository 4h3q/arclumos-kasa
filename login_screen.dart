import 'package:flutter/material.dart';
import '../db/repo.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String userId) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  String _msg = '';

  Future<void> _login() async {
    setState(() => _msg = 'Giris yapiliyor...');
    try {
      final user = await Repo.instance.login(_u.text, _p.text);
      if (user == null) {
        setState(() => _msg = 'Hatali kullanici adi veya PIN');
        return;
      }
      widget.onLogin(user.id);
    } catch (e) {
      setState(() => _msg = 'Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('ARCLUMOS Kasa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Offline kasa defteri • SQLite', style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _u,
                        decoration: const InputDecoration(labelText: 'Kullanici adi'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _p,
                        decoration: const InputDecoration(labelText: 'PIN'),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _login,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Giris Yap', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_msg, style: TextStyle(color: _msg.startsWith('Hata') || _msg.startsWith('Hatali') ? Colors.red : Colors.black54)),
                      const SizedBox(height: 6),
                      const Text('Ilk giris: admin / 1234', style: TextStyle(color: Colors.black45, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
