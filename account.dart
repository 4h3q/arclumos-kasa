class Account {
  final String id;
  final String name;
  final String currency;
  final double openingBalance;
  final bool isActive;

  const Account({
    required this.id,
    required this.name,
    required this.currency,
    required this.openingBalance,
    required this.isActive,
  });

  factory Account.fromMap(Map<String, Object?> m) => Account(
    id: m['id'] as String,
    name: m['name'] as String,
    currency: m['currency'] as String,
    openingBalance: (m['openingBalance'] as num).toDouble(),
    isActive: (m['isActive'] as int) == 1,
  );
}
