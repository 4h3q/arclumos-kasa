import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/repo.dart';
import '../models/account.dart';

class TxFormScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String type; // IN/OUT
  const TxFormScreen({super.key, required this.userId, required this.userName, required this.type});

  @override
  State<TxFormScreen> createState() => _TxFormScreenState();
}

class _TxFormScreenState extends State<TxFormScreen> {
  List<Account> _accounts = [];
  Account? _sel;
  DateTime _date = DateTime.now();
  final _amount = TextEditingController();
  final _cat = TextEditingController();
  final _desc = TextEditingController();
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
      _sel = a.isNotEmpty ? a.first : null;
    });
  }

  Future<void> _save() async {
    setState(() => _msg = 'Kaydediliyor...');
    try {
      final acc = _sel;
      if (acc == null) throw Exception('Kasa yok');
      final amt = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
      await Repo.instance.addTx(
        type: widget.type,
        accountId: acc.id,
        currency: acc.currency,
        amount: amt,
        dateForRate: _date,
        category: _cat.text,
        description: _desc.text,
        createdByUserId: widget.userId,
        createdByName: widget.userName,
      );
      _amount.clear();
      _cat.clear();
      _desc.clear();
      if (!mounted) return;
      setState(() => _msg = 'Kaydedildi ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.type == 'IN';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(isIn ? 'Gelir Oluştur' : 'Gider Oluştur',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Account>(
                    value: _sel,
                    items: _accounts
                        .map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.currency})')))
                        .toList(),
                    onChanged: (v) => setState(() => _sel = v),
                    decoration: const InputDecoration(labelText: 'Kasa'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tarih'),
                    subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: _date,
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tutar'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cat,
                    decoration: const InputDecoration(labelText: 'Kategori (opsiyonel)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _desc,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(isIn ? 'Gelir Kaydet' : 'Gider Kaydet',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_msg, style: TextStyle(color: _msg.startsWith('Hata') ? Colors.red : Colors.black54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
