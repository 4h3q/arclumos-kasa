import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import '../db/app_db.dart';

/// FX service:
/// - TRY => 1
/// - For other currencies: tries cache (fx_cache), then tries TCMB today XML (only if ymd == today)
/// - If offline or not found: throws
class FxService {
  FxService._();
  static final FxService instance = FxService._();

  Database get _db => AppDb.instance.db;

  Future<double> getFxToTRY({required String ymd, required String currency}) async {
    currency = currency.toUpperCase().trim();
    if (currency == 'TRY') return 1.0;

    final cached = await _db.query('fx_cache',
        where: 'ymd = ? AND currency = ?', whereArgs: [ymd, currency], limit: 1);
    if (cached.isNotEmpty) {
      return (cached.first['fxToTRY'] as num).toDouble();
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (ymd != today) {
      throw Exception('Kur cache yok ve tarih bugun degil: $ymd ($currency)');
    }

    // TCMB today XML
    final url = Uri.parse('https://tcmb1.tcmb.gov.tr/kurlar/today.xml');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Kur alinamadi (internet?): ${res.statusCode}');
    }
    final xml = res.body;

    // very light parse: find CurrencyCode="USD" ... <ForexSelling>...</ForexSelling>
    final rate = _extractRate(xml, currency);
    if (rate == null || rate <= 0) {
      throw Exception('Kur bulunamadi: $currency');
    }

    await _db.insert('fx_cache', {'ymd': ymd, 'currency': currency, 'fxToTRY': rate},
        conflictAlgorithm: ConflictAlgorithm.replace);

    return rate;
  }

  double? _extractRate(String xml, String currency) {
    final code = 'CurrencyCode="$currency"';
    final idx = xml.indexOf(code);
    if (idx < 0) return null;
    final chunk = xml.substring(idx, (idx + 2000).clamp(0, xml.length));
    String? selling = _tagValue(chunk, 'ForexSelling');
    String? buying = _tagValue(chunk, 'ForexBuying');
    final v = (selling != null && selling.trim().isNotEmpty) ? selling : buying;
    if (v == null) return null;
    final s = v.replaceAll(',', '.').trim();
    return double.tryParse(s);
  }

  String? _tagValue(String s, String tag) {
    final a = '<$tag>';
    final b = '</$tag>';
    final i = s.indexOf(a);
    if (i < 0) return null;
    final j = s.indexOf(b, i + a.length);
    if (j < 0) return null;
    return s.substring(i + a.length, j);
  }
}
