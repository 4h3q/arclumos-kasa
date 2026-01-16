class Tx {
  final String id;
  final int seqNo;
  final DateTime timestamp;
  final String type; // IN / OUT
  final String accountId;
  final String currency;
  final double amount;
  final double fxToTRY;
  final double amountTRY;
  final String? category;
  final String? description;
  final String createdByName;
  final String? groupId;

  const Tx({
    required this.id,
    required this.seqNo,
    required this.timestamp,
    required this.type,
    required this.accountId,
    required this.currency,
    required this.amount,
    required this.fxToTRY,
    required this.amountTRY,
    required this.category,
    required this.description,
    required this.createdByName,
    required this.groupId,
  });

  factory Tx.fromMap(Map<String, Object?> m) => Tx(
    id: m['id'] as String,
    seqNo: m['seqNo'] as int,
    timestamp: DateTime.parse(m['timestamp'] as String),
    type: m['type'] as String,
    accountId: m['accountId'] as String,
    currency: m['currency'] as String,
    amount: (m['amount'] as num).toDouble(),
    fxToTRY: (m['fxToTRY'] as num).toDouble(),
    amountTRY: (m['amountTRY'] as num).toDouble(),
    category: m['category'] as String?,
    description: m['description'] as String?,
    createdByName: m['createdByName'] as String,
    groupId: m['groupId'] as String?,
  );
}
