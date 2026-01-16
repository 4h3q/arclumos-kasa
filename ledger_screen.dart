import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../db/repo.dart';
import '../models/account.dart';
import '../models/tx.dart';
import 'transfer_screen.dart';

class LedgerScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const LedgerScreen({super.key, required this.userId, required this.userName});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<Account> _accounts = [];
  String _type = 'ALL';
  String _accountId = '';
  String _cat = '';
  String _q = '';
  DateTime? _from;
  DateTime? _to;
  String _sort = 'date_desc';

  List<Tx> _rows = [];
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _from = DateTime.now();
    _to = DateTime.now().add(const Duration(hours: 23, minutes: 59, seconds: 59));
    refresh();
  }

  Future<void> _loadAccounts() async {
    final a = await Repo.instance.getAccounts();
    if (!mounted) return;
    setState(() => _accounts = a);
  }

  Future<void> refresh() async {
    setState(() => _msg = 'Yukleniyor...');
    try {
      final parts = _sort.split('_');
      final sortKey = parts[0];
      final sortDir = parts[1];
      final rows = await Repo.instance.queryTx(
        from: _from,
        to: _to,
        type: _type,
        accountId: _accountId,
        categoryContains: _cat,
        q: _q,
        sortKey: sortKey,
        sortDir: sortDir,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _msg = 'Guncel ✅';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = 'Hata: $e');
    }
  }

  String _money(double n) => NumberFormat.currency(locale: 'tr_TR', symbol: '').format(n);

  Future<void> _exportCSV() async {
    final header = ['FisNo','Tarih/Saat','Tur','Kasa','Doviz','Tutar','Kur(TRY)','Tutar(TRY)','Kategori','Aciklama','Yazan'];
    final lines = <String>[];
    lines.add(header.map(_esc).join(','));

    final accName = {for (final a in _accounts) a.id : a.name};

    for (final r in _rows) {
      lines.add([
        r.seqNo.toString().padLeft(6,'0'),
        DateFormat('dd.MM.yyyy HH:mm').format(r.timestamp),
        r.type == 'IN' ? 'Gelir' : 'Gider',
        accName[r.accountId] ?? r.accountId,
        r.currency,
        r.amount,
        r.fxToTRY,
        r.amountTRY,
        r.category ?? '',
        r.description ?? '',
        r.createdByName,
      ].map(_esc).join(','));
    }

    final csv = '\uFEFF' + lines.join('\n');
    final file = await _tmpFile('arclumos_kasa.csv');
    await file.writeAsString(csv, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'ARCLUMOS Kasa CSV');
  }

  Future<void> _exportExcel() async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Kasa'];
    final accName = {for (final a in _accounts) a.id : a.name};

    sheet.appendRow(['FisNo','Tarih/Saat','Tur','Kasa','Doviz','Tutar','Kur(TRY)','Tutar(TRY)','Kategori','Aciklama','Yazan']);
    for (final r in _rows) {
      sheet.appendRow([
        r.seqNo.toString().padLeft(6,'0'),
        DateFormat('dd.MM.yyyy HH:mm').format(r.timestamp),
        r.type == 'IN' ? 'Gelir' : 'Gider',
        accName[r.accountId] ?? r.accountId,
        r.currency,
        r.amount,
        r.fxToTRY,
        r.amountTRY,
        r.category ?? '',
        r.description ?? '',
        r.createdByName,
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final file = await _tmpFile('arclumos_kasa.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'ARCLUMOS Kasa Excel');
  }

  Future<void> _exportPDF() async {
    final doc = pw.Document();
    final accName = {for (final a in _accounts) a.id : a.name};

    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text('ARCLUMOS Kasa Raporu', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Olusturan: ${widget.userName}'),
          pw.Text('Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['FisNo','Tarih','Tur','Kasa','Doviz','Tutar','TRY','Kategori','Aciklama','Yazan'],
            data: _rows.map((r) => [
              r.seqNo.toString().padLeft(6,'0'),
              DateFormat('dd.MM HH:mm').format(r.timestamp),
              r.type == 'IN' ? 'Gelir' : 'Gider',
              accName[r.accountId] ?? r.accountId,
              r.currency,
              r.amount.toStringAsFixed(2),
              r.amountTRY.toStringAsFixed(2),
              r.category ?? '',
              r.description ?? '',
              r.createdByName,
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'arclumos_kasa.pdf');
  }

  String _esc(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"' + s.replaceAll('"','""') + '"';
    }
    return s;
  }

  Future<File> _tmpFile(String name) async {
    final dir = await Directory.systemTemp.createTemp('arclumos_kasa_');
    return File('${dir.path}/$name');
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last = first.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    // simple: today shortcut
    setState(() {
      _from = first;
      _to = last;
    });
    await refresh();
  }

  Future<void> _editTx(Tx tx) async {
    final acc = _accounts.firstWhere((a) => a.id == tx.accountId, orElse: () => _accounts.first);
    Account sel = acc;
    final amount = TextEditingController(text: tx.amount.toStringAsFixed(2));
    final cat = TextEditingController(text: tx.category ?? '');
    final desc = TextEditingController(text: tx.description ?? '');
    String type = tx.type;
    DateTime date = DateTime.now();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (ctx2, setS) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Islem Duzenle • ${tx.seqNo.toString().padLeft(6,'0')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'IN', child: Text('Gelir')),
                      DropdownMenuItem(value: 'OUT', child: Text('Gider')),
                    ],
                    onChanged: (v) => setS(() => type = v ?? 'IN'),
                    decoration: const InputDecoration(labelText: 'Tur'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Account>(
                    value: sel,
                    items: _accounts.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.currency})'))).toList(),
                    onChanged: (v) => setS(() => sel = v ?? sel),
                    decoration: const InputDecoration(labelText: 'Kasa'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: amount, decoration: const InputDecoration(labelText: 'Tutar')),
                  const SizedBox(height: 8),
                  TextField(controller: cat, decoration: const InputDecoration(labelText: 'Kategori')),
                  const SizedBox(height: 8),
                  TextField(controller: desc, decoration: const InputDecoration(labelText: 'Aciklama'), maxLines: 2),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Tarih (kur icin)'),
                    subtitle: Text(DateFormat('dd.MM.yyyy').format(date)),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final p = await showDatePicker(context: ctx2, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date);
                      if (p != null) setS(() => date = p);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx2,
                              builder: (_) => AlertDialog(
                                title: const Text('Silinsin mi?'),
                                content: const Text('Bu islem silinecek (geri alma yok).'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Vazgec')),
                                  FilledButton(onPressed: () => Navigator.pop(_, true), child: const Text('Sil')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await Repo.instance.deleteTx(tx.id);
                              if (ctx2.mounted) Navigator.pop(ctx2, true);
                            }
                          },
                          child: const Text('Sil'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final amt = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
                            await Repo.instance.updateTx(
                              txId: tx.id,
                              type: type,
                              accountId: sel.id,
                              currency: sel.currency,
                              amount: amt,
                              dateForRate: date,
                              category: cat.text,
                              description: desc.text,
                            );
                            if (ctx2.mounted) Navigator.pop(ctx2, true);
                          },
                          child: const Text('Kaydet'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          }),
        );
      },
    );

    if (ok == true) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accItems = [
      const DropdownMenuItem(value: '', child: Text('Tumu')),
      ..._accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.currency})'))),
    ];

    double inTRY = 0, outTRY = 0;
    for (final r in _rows) {
      if (r.type == 'IN') inTRY += r.amountTRY;
      if (r.type == 'OUT') outTRY += r.amountTRY;
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Filtre', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('Hepsi')),
                            DropdownMenuItem(value: 'IN', child: Text('Gelir')),
                            DropdownMenuItem(value: 'OUT', child: Text('Gider')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'ALL'),
                          decoration: const InputDecoration(labelText: 'Islem'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _accountId,
                          items: accItems,
                          onChanged: (v) => setState(() => _accountId = v ?? ''),
                          decoration: const InputDecoration(labelText: 'Kasa'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Kategori (icerir)'),
                    onChanged: (v) => _cat = v,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Arama'),
                    onChanged: (v) => _q = v,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: 'date_desc', child: Text('Tarih (Yeni→Eski)')),
                      DropdownMenuItem(value: 'date_asc', child: Text('Tarih (Eski→Yeni)')),
                      DropdownMenuItem(value: 'amount_desc', child: Text('Tutar (Buyuk→Kucuk)')),
                      DropdownMenuItem(value: 'amount_asc', child: Text('Tutar (Kucuk→Buyuk)')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'date_desc'),
                    decoration: const InputDecoration(labelText: 'Sirala'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: _pickRange, child: const Text('Bugun'))),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: refresh, child: const Text('Filtrele'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: _exportCSV, child: const Text('CSV'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: _exportExcel, child: const Text('Excel'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: _exportPDF, child: const Text('PDF'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen(userId: widget.userId, userName: widget.userName)));
                      await refresh();
                    },
                    child: const Text('Transfer'),
                  ),
                  const SizedBox(height: 8),
                  Text(_msg, style: TextStyle(color: _msg.startsWith('Hata') ? Colors.red : Colors.black54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _kv('Toplam Gelir (TRY)', _money(inTRY)),
                  _kv('Toplam Gider (TRY)', _money(outTRY)),
                  _kv('Bakiye (TRY)', _money(inTRY - outTRY), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._rows.map((r) => Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text('${r.seqNo.toString().padLeft(6,'0')} • ${r.type == 'IN' ? 'Gelir' : 'Gider'} • ${_money(r.amount)} ${r.currency}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${DateFormat('dd.MM.yyyy HH:mm').format(r.timestamp)} • TRY: ${_money(r.amountTRY)} • ${r.createdByName}\n${(r.category ?? '')}${(r.description ?? '').isEmpty ? '' : ' • ${r.description}'}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.edit),
                  onTap: () => _editTx(r),
                ),
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
        ],
      ),
    );
  }
}
