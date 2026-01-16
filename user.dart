class AppUser {
  final String id;
  final String username;
  final String pin;
  final String fullName;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.username,
    required this.pin,
    required this.fullName,
    required this.isActive,
  });

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
    id: m['id'] as String,
    username: m['username'] as String,
    pin: m['pin'] as String,
    fullName: m['fullName'] as String,
    isActive: (m['isActive'] as int) == 1,
  );
}
