import 'package:flutter/material.dart';
import '../db/repo.dart';
import '../models/user.dart';
import 'tx_form_screen.dart';
import 'ledger_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.userId, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 2; // default to ledger
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await Repo.instance.getUserById(widget.userId);
    if (!mounted) return;
    setState(() => _user = u);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final title = _idx == 0 ? 'Gider' : _idx == 1 ? 'Gelir' : 'Kasa Defteri';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Cikis',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _idx,
              children: [
                TxFormScreen(userId: user.id, userName: user.fullName, type: 'OUT'),
                TxFormScreen(userId: user.id, userName: user.fullName, type: 'IN'),
                LedgerScreen(userId: user.id, userName: user.fullName),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.remove_circle_outline), label: 'Gider'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Gelir'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Kasa'),
        ],
      ),
    );
  }
}
