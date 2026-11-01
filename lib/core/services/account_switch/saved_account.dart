/// ACCOUNT_SWITCH: one account remembered on this device for the account
/// switcher (new design / Beta).
///
/// Holds the newest refresh token of the account's own session, so the
/// switcher can bring the account back without its password. A missing
/// token means the session ended elsewhere (password change, "überall
/// abmelden", token expired) – the account then needs a normal login.
class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.email,
    this.refreshToken,
    this.name,
    this.label,
    this.lastUsedAt,
  });

  /// Supabase auth user id.
  final String userId;
  final String email;

  /// Newest refresh token of this account's session on this device.
  final String? refreshToken;

  /// "Vorname Nachname" as last seen on the Ich page.
  final String? name;

  /// "Spieler · SO" (role and group) as last seen on the Ich page.
  final String? label;

  /// When this account was last the active one.
  final DateTime? lastUsedAt;

  /// The account can be opened without password.
  bool get canResume => (refreshToken ?? '').isNotEmpty;

  /// Name if known, otherwise the e-mail address.
  String get title => (name ?? '').trim().isNotEmpty ? name!.trim() : email;

  SavedAccount copyWith({
    String? email,
    String? refreshToken,
    bool clearRefreshToken = false,
    String? name,
    String? label,
    DateTime? lastUsedAt,
  }) {
    return SavedAccount(
      userId: userId,
      email: email ?? this.email,
      refreshToken: clearRefreshToken ? null : (refreshToken ?? this.refreshToken),
      name: name ?? this.name,
      label: label ?? this.label,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        if (refreshToken != null) 'refreshToken': refreshToken,
        if (name != null) 'name': name,
        if (label != null) 'label': label,
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
      };

  /// Null for entries that are not readable (older or damaged data).
  static SavedAccount? fromJson(Object? json) {
    if (json is! Map) return null;
    final userId = json['userId'];
    final email = json['email'];
    if (userId is! String || userId.isEmpty || email is! String) return null;
    final token = json['refreshToken'];
    final name = json['name'];
    final label = json['label'];
    final used = json['lastUsedAt'];
    return SavedAccount(
      userId: userId,
      email: email,
      refreshToken: token is String && token.isNotEmpty ? token : null,
      name: name is String ? name : null,
      label: label is String ? label : null,
      lastUsedAt: used is String ? DateTime.tryParse(used) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavedAccount &&
      other.userId == userId &&
      other.email == email &&
      other.refreshToken == refreshToken &&
      other.name == name &&
      other.label == label &&
      other.lastUsedAt == lastUsedAt;

  @override
  int get hashCode => Object.hash(userId, email, refreshToken, name, label, lastUsedAt);
}
