import '../../../../core/database/clinic_data_database.dart';
import '../../../../core/money/currency.dart';
import '../../domain/entities/fee_defaults.dart';
import '../../domain/entities/phrase_kind.dart';

class ClinicDefaultsLocalDataSource {
  const ClinicDefaultsLocalDataSource(this._db);

  final ClinicDataDatabase _db;

  Future<FeeDefaults> getFeeDefaults() async {
    final db = await _db.database;
    final rows = await db.query(
      'clinic_settings',
      columns: [
        'consultation_fee',
        'checkup_fee',
        'default_currency',
        'usd_rate',
      ],
      where: 'id = 1',
    );
    if (rows.isEmpty) return const FeeDefaults();
    return FeeDefaults(
      consultationFee: (rows.first['consultation_fee'] as num?)?.toDouble(),
      checkupFee: (rows.first['checkup_fee'] as num?)?.toDouble(),
      currency: Currency.fromCode(rows.first['default_currency'] as String?),
      usdRate: (rows.first['usd_rate'] as num?)?.toDouble(),
    );
  }

  Future<void> saveFeeDefaults(FeeDefaults defaults) async {
    final db = await _db.database;
    await db.update('clinic_settings', {
      'consultation_fee': defaults.consultationFee,
      'checkup_fee': defaults.checkupFee,
      'default_currency': defaults.currency.code,
      'usd_rate': defaults.usdRate,
    }, where: 'id = 1');
  }

  Future<List<String>> listPhrases(PhraseKind kind) async {
    final db = await _db.database;
    final rows = await db.query(
      'phrases',
      columns: ['text'],
      where: 'kind = ?',
      whereArgs: [kind.name],
      orderBy: 'uses DESC, id DESC',
      limit: 40,
    );
    return rows.map((r) => r['text']! as String).toList();
  }

  Future<void> recordPhrase(PhraseKind kind, String text) async {
    final db = await _db.database;
    final updated = await db.rawUpdate(
      'UPDATE phrases SET uses = uses + 1 WHERE kind = ? AND text = ?',
      [kind.name, text],
    );
    if (updated == 0) {
      await db.insert('phrases', {'kind': kind.name, 'text': text, 'uses': 1});
    }
  }

  Future<void> deletePhrase(PhraseKind kind, String text) async {
    final db = await _db.database;
    await db.delete(
      'phrases',
      where: 'kind = ? AND text = ?',
      whereArgs: [kind.name, text],
    );
  }
}
