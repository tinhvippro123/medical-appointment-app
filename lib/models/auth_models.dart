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
  final String? email;

  RegisterRequest({
    required this.fullName,
    required this.phone,
    required this.password,
    this.email,
  });

  Map<String, dynamic> toJson() {
    final trimmedEmail = email?.trim();
    return {
      'fullName': fullName,
      'phone': phone,
      'password': password,
      if (trimmedEmail != null && trimmedEmail.isNotEmpty)
        'email': trimmedEmail,
    };
  }
}

class RegisterResult {
  final String message;
  final bool requiresEmailVerification;
  final String? email;
  final String? devOtp;

  const RegisterResult({
    required this.message,
    this.requiresEmailVerification = false,
    this.email,
    this.devOtp,
  });
}

class VerifyEmailRequest {
  final String email;
  final String otp;

  const VerifyEmailRequest({required this.email, required this.otp});

  Map<String, dynamic> toJson() => {'email': email, 'otp': otp};
}

class ChangePasswordRequest {
  final String oldPassword;
  final String newPassword;
  final String confirmPassword;

  ChangePasswordRequest({
    required this.oldPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() => {
    'oldPassword': oldPassword,
    'newPassword': newPassword,
    'confirmPassword': confirmPassword,
  };
}

class ForgotPasswordRequest {
  final String email;

  const ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

class ForgotPasswordResult {
  final String message;
  final String? devOtp;

  const ForgotPasswordResult({required this.message, this.devOtp});
}

class ResetPasswordRequest {
  final String email;
  final String otp;
  final String newPassword;

  const ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'otp': otp,
    'newPassword': newPassword,
  };
}
