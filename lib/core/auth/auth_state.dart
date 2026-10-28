enum AuthStatus {
  /// Session has not been checked yet (app is on the splash screen).
  unknown,
  authenticated,
  unauthenticated,
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
      );

  final String id;
  final String name;
  final String email;
  final String? phone;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
      };
}

class AuthResult {
  const AuthResult._(this.isSuccess, this.message);

  const AuthResult.success([String? message]) : this._(true, message);
  const AuthResult.failure(String message) : this._(false, message);

  final bool isSuccess;
  final String? message;
}
