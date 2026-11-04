/// A stored Garmin Connect authorization. The access token is short-lived;
/// the refresh token lets later syncs skip the sign-in form.
class GarminAccount {
  const GarminAccount({
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.clientId,
    required this.accessTokenExpiresAt,
  });

  final String email;
  final String accessToken;
  final String refreshToken;
  final String clientId;
  final DateTime accessTokenExpiresAt;

  bool get canRefresh => refreshToken.isNotEmpty && clientId.isNotEmpty;

  bool expiresSoon({Duration window = const Duration(minutes: 15)}) =>
      !accessTokenExpiresAt.isAfter(DateTime.now().add(window));

  GarminAccount copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
  }) {
    return GarminAccount(
      email: email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      clientId: clientId,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'clientId': clientId,
    'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
  };

  factory GarminAccount.fromJson(Map<String, dynamic> json) {
    return GarminAccount(
      email: json['email'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      clientId: json['clientId'] as String,
      accessTokenExpiresAt: DateTime.parse(
        json['accessTokenExpiresAt'] as String,
      ),
    );
  }
}
