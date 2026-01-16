import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/repo.dart';
import '../models/account.dart';

class TransferScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const TransferScreen({super.key, required this.userId, required this.userName});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  List<Account> _accounts = [];
  Account? _from;
  Account? _to;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await Repo.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = a;
      if (a.length >= 2) {
        _from = a[0];
        _to = a[1];
      } else if (a.isNotEmpty) {
        _from = a.first;
        _to = a.first;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _msg = 'Kaydediliyor...');
    try {
      final f = _from;
      final t = _to;
      if (f == null || t == null) throw Exception('Kasa secilmeli');
      final amt = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
      await Repo.instance.createTransfer(
        fromAccountId: f.id,
        toAccountId: t.id,
        fromAmount: amt,
        dateForRate: _date,
        createdByUserId: widget.userId,
        createdByName: widget.userName,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() => _msg = 'Transfer kaydedildi ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Account>(
                  value: _from,
                  items: _accounts.map((a) => DropdownMenuItem(value: a, child: Text('Cikan: ${a.name} (${a.currency})'))).toList(),
                  onChanged: (v) => setState(() => _from = v),
                  decoration: const InputDecoration(labelText: 'Cikis Kasasi'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Account>(
                  value: _to,
                  items: _accounts.map((a) => DropdownMenuItem(value: a, child: Text('Giren: ${a.name} (${a.currency})'))).toList(),
                  onChanged: (v) => setState(() => _to = v),
                  decoration: const InputDecoration(labelText: 'Giris Kasasi'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tarih (kur icin)'),
                  subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cikan tutar (from kasa dovizi)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _save,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Transfer Kaydet', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_msg, style: TextStyle(color: _msg.startsWith('Hata') ? Colors.red : Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
