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

class MyProfile {
  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String roleKey;
  final String roleName;
  final DateTime? dateOfBirth;
  final String? gender;

  const MyProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.roleKey,
    required this.roleName,
    this.dateOfBirth,
    this.gender,
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    final rawDob = json['dateOfBirth']?.toString().trim();
    return MyProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (json['fullName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: json['email']?.toString(),
      roleKey: (json['roleKey'] ?? 'PATIENT').toString(),
      roleName: (json['roleName'] ?? 'Bệnh nhân').toString(),
      dateOfBirth: rawDob != null && rawDob.isNotEmpty
          ? DateTime.tryParse(rawDob)
          : null,
      gender: json['gender']?.toString(),
    );
  }
}

class UpdateMyProfileRequest {
  final String fullName;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;

  const UpdateMyProfileRequest({
    required this.fullName,
    this.email,
    this.dateOfBirth,
    this.gender,
  });

  Map<String, dynamic> toJson() {
    final trimmedEmail = email?.trim();
    final trimmedGender = gender?.trim();
    String? dobIso;
    if (dateOfBirth != null) {
      final y = dateOfBirth!.year.toString().padLeft(4, '0');
      final m = dateOfBirth!.month.toString().padLeft(2, '0');
      final d = dateOfBirth!.day.toString().padLeft(2, '0');
      dobIso = '$y-$m-$d';
    }
    return {
      'fullName': fullName.trim(),
      if (trimmedEmail != null && trimmedEmail.isNotEmpty)
        'email': trimmedEmail,
      'dateOfBirth': ?dobIso,
      if (trimmedGender != null && trimmedGender.isNotEmpty)
        'gender': trimmedGender,
    };
  }
}
