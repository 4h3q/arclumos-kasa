import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'arclumos_kasa.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await _createSchema(db);
        await _seedDefaults(db);
      },
    );

    await _ensureDefaults(_db!);
  }

  Database get db {
    final d = _db;
    if (d == null) throw StateError('DB not initialized');
    return d;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute("""
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        pin TEXT NOT NULL,
        fullName TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      );
    """);

    await db.execute("""
      CREATE TABLE accounts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        currency TEXT NOT NULL,
        openingBalance REAL NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1
      );
    """);

    await db.execute("""
      CREATE TABLE tx(
        id TEXT PRIMARY KEY,
        seqNo INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL,
        accountId TEXT NOT NULL,
        currency TEXT NOT NULL,
        amount REAL NOT NULL,
        fxToTRY REAL NOT NULL,
        amountTRY REAL NOT NULL,
        category TEXT,
        description TEXT,
        createdByUserId TEXT NOT NULL,
        createdByName TEXT NOT NULL,
        groupId TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0
      );
    """);

    await db.execute('CREATE INDEX idx_tx_date ON tx(timestamp);');
    await db.execute('CREATE INDEX idx_tx_account ON tx(accountId);');
    await db.execute('CREATE INDEX idx_tx_deleted ON tx(isDeleted);');

    await db.execute("""
      CREATE TABLE fx_cache(
        ymd TEXT NOT NULL,
        currency TEXT NOT NULL,
        fxToTRY REAL NOT NULL,
        PRIMARY KEY (ymd, currency)
      );
    """);
  }

  Future<void> _seedDefaults(Database db) async {
    await db.insert('users', {
      'id': _uuid(),
      'username': 'admin',
      'pin': '1234',
      'fullName': 'Admin',
      'isActive': 1,
    });

    await db.insert('accounts', {
      'id': _uuid(),
      'name': 'ARCLUMOS TL',
      'currency': 'TRY',
      'openingBalance': 0.0,
      'isActive': 1,
    });
  }

  Future<void> _ensureDefaults(Database db) async {
    final u = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users'));
    if ((u ?? 0) == 0) {
      await _seedDefaults(db);
      return;
    }
    final a = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM accounts'));
    if ((a ?? 0) == 0) {
      await db.insert('accounts', {
        'id': _uuid(),
        'name': 'ARCLUMOS TL',
        'currency': 'TRY',
        'openingBalance': 0.0,
        'isActive': 1,
      });
    }
  }

  String _uuid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    final ts = DateTime.now().microsecondsSinceEpoch;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '\${hex}\${ts}';
  }
}
