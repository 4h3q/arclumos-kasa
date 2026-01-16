import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../db/app_db.dart';
import '../models/account.dart';
import '../models/user.dart';
import '../models/tx.dart';
import '../services/fx_service.dart';

class Repo {
  Repo._();
  static final Repo instance = Repo._();

  Database get _db => AppDb.instance.db;

  Future<AppUser?> login(String username, String pin) async {
    final rows = await _db.query(
      'users',
      where: 'username = ? AND pin = ? AND isActive = 1',
      whereArgs: [username.trim(), pin.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserById(String id) async {
    final rows = await _db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<Account>> getAccounts() async {
    final rows = await _db.query('accounts', where: 'isActive = 1', orderBy: 'name ASC');
    return rows.map(Account.fromMap).toList();
  }

  Future<Map<String, double>> getAccountBalances() async {
    final accounts = await getAccounts();
    final balances = <String, double>{};
    for (final a in accounts) {
      balances[a.id] = a.openingBalance;
    }

    final rows = await _db.query('tx', where: 'isDeleted = 0');
    for (final r in rows) {
      final type = r['type'] as String;
      final acc = r['accountId'] as String;
      final amt = (r['amount'] as num).toDouble();
      balances[acc] = (balances[acc] ?? 0) + (type == 'IN' ? amt : -amt);
    }
    return balances;
  }

  Future<int> _nextSeqNo() async {
    final res = await _db.rawQuery('SELECT MAX(seqNo) as m FROM tx');
    final m = res.first['m'] as int?;
    return (m ?? 0) + 1;
  }

  Future<void> addTx({
    required String type,
    required String accountId,
    required String currency,
    required double amount,
    required DateTime dateForRate,
    String? category,
    String? description,
    required String createdByUserId,
    required String createdByName,
    String? groupId,
  }) async {
    if (amount <= 0) throw Exception('Tutar pozitif olmalı');
    final seqNo = await _nextSeqNo();

    final ymd = DateFormat('yyyy-MM-dd').format(dateForRate);
    final fx = await FxService.instance.getFxToTRY(ymd: ymd, currency: currency);
    final amountTRY = currency == 'TRY' ? amount : (amount * fx);

    await _db.insert('tx', {
      'id': _uuid(),
      'seqNo': seqNo,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'accountId': accountId,
      'currency': currency,
      'amount': amount,
      'fxToTRY': fx,
      'amountTRY': amountTRY,
      'category': (category ?? '').trim().isEmpty ? null : category!.trim(),
      'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'groupId': groupId,
      'isDeleted': 0,
    });
  }

  Future<void> updateTx({
    required String txId,
    required String type,
    required String accountId,
    required String currency,
    required double amount,
    required DateTime dateForRate,
    String? category,
    String? description,
  }) async {
    final ymd = DateFormat('yyyy-MM-dd').format(dateForRate);
    final fx = await FxService.instance.getFxToTRY(ymd: ymd, currency: currency);
    final amountTRY = currency == 'TRY' ? amount : (amount * fx);

    await _db.update(
      'tx',
      {
        'type': type,
        'accountId': accountId,
        'currency': currency,
        'amount': amount,
        'fxToTRY': fx,
        'amountTRY': amountTRY,
        'category': (category ?? '').trim().isEmpty ? null : category!.trim(),
        'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      },
      where: 'id = ?',
      whereArgs: [txId],
    );
  }

  Future<void> deleteTx(String txId) async {
    await _db.update('tx', {'isDeleted': 1}, where: 'id = ?', whereArgs: [txId]);
  }

  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double fromAmount,
    required DateTime dateForRate,
    required String createdByUserId,
    required String createdByName,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) throw Exception('Aynı kasa arasında transfer olmaz');
    if (fromAmount <= 0) throw Exception('Tutar pozitif olmalı');

    final accounts = await getAccounts();
    final from = accounts.firstWhere((a) => a.id == fromAccountId);
    final to = accounts.firstWhere((a) => a.id == toAccountId);

    final ymd = DateFormat('yyyy-MM-dd').format(dateForRate);
    final fxFrom = await FxService.instance.getFxToTRY(ymd: ymd, currency: from.currency);
    final fromAmountTRY = from.currency == 'TRY' ? fromAmount : (fromAmount * fxFrom);

    double toAmount = fromAmountTRY;
    if (to.currency != 'TRY') {
      final fxTo = await FxService.instance.getFxToTRY(ymd: ymd, currency: to.currency);
      toAmount = fromAmountTRY / fxTo;
    }

    final gid = _uuid();
    await addTx(
      type: 'OUT',
      accountId: from.id,
      currency: from.currency,
      amount: fromAmount,
      dateForRate: dateForRate,
      category: 'TRANSFER',
      description: 'Transfer → ${to.name}${(note ?? '').trim().isEmpty ? '' : ' • ${note!.trim()}'}',
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      groupId: gid,
    );

    await addTx(
      type: 'IN',
      accountId: to.id,
      currency: to.currency,
      amount: toAmount,
      dateForRate: dateForRate,
      category: 'TRANSFER',
      description: 'Transfer ← ${from.name}${(note ?? '').trim().isEmpty ? '' : ' • ${note!.trim()}'}',
      createdByUserId: createdByUserId,
      createdByName: createdByName,
      groupId: gid,
    );
  }

  Future<List<Tx>> queryTx({
    required DateTime? from,
    required DateTime? to,
    required String type, // ALL/IN/OUT
    required String accountId, // '' all
    required String categoryContains,
    required String q,
    required String sortKey, // date/amount
    required String sortDir, // asc/desc
    int limit = 200,
  }) async {
    final where = <String>['isDeleted = 0'];
    final args = <Object?>[];

    if (from != null) {
      where.add('timestamp >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('timestamp <= ?');
      args.add(to.toIso8601String());
    }
    if (type != 'ALL') {
      where.add('type = ?');
      args.add(type);
    }
    if (accountId.isNotEmpty) {
      where.add('accountId = ?');
      args.add(accountId);
    }
    if (categoryContains.trim().isNotEmpty) {
      where.add('LOWER(COALESCE(category, \'\')) LIKE ?');
      args.add('%${categoryContains.trim().toLowerCase()}%');
    }
    if (q.trim().isNotEmpty) {
      where.add("(LOWER(COALESCE(description,'')) LIKE ? OR LOWER(COALESCE(category,'')) LIKE ? OR LOWER(createdByName) LIKE ? OR CAST(seqNo AS TEXT) LIKE ?)");
      final qq = '%${q.trim().toLowerCase()}%';
      args.addAll([qq, qq, qq, qq]);
    }

    final orderBy = (sortKey == 'amount')
        ? 'amountTRY ${sortDir.toUpperCase()}'
        : 'timestamp ${sortDir.toUpperCase()}';

    final rows = await _db.query('tx',
        where: where.join(' AND '), whereArgs: args, orderBy: orderBy, limit: limit);

    return rows.map(Tx.fromMap).toList();
  }

  String _uuid() {
    // same style as db uuid
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = now % 1000000;
    return '${now}_$rand';
  }
}
