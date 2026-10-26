class LoginRequest {
  final String phone;
  final String password;

  LoginRequest({required this.phone, required this.password});

  Map<String, dynamic> toJson() => {'phone': phone, 'password': password};
}

class RegisterRequest {
  final String fullName;
  final String phone;
  final String password;

  RegisterRequest({
    required this.fullName,
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'password': password,
  };
}
