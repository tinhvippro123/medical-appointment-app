class FormValidators {
  static final RegExp vnPhoneRegex = RegExp(r'^0\d{9}$');
  static final RegExp roleKeyRegex = RegExp(r'^[A-Za-z0-9_]+$');
  static final RegExp emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp otp6Regex = RegExp(r'^\d{6}$');

  static String? validateFullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }
    if (trimmed.length < 2 || trimmed.length > 40) {
      return 'Họ tên phải từ 2 đến 40 ký tự';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (!vnPhoneRegex.hasMatch(trimmed)) {
      return 'Số điện thoại phải gồm 10 chữ số và bắt đầu bằng số 0';
    }
    return null;
  }

  static String? validateOptionalEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > 100) {
      return 'Email tối đa 100 ký tự';
    }
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Email không đúng định dạng';
    }
    return null;
  }

  static String? validateRequiredEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    if (trimmed.length > 100) {
      return 'Email tối đa 100 ký tự';
    }
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Email không đúng định dạng';
    }
    return null;
  }

  static String? validateOtp6(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập mã OTP';
    }
    if (!otp6Regex.hasMatch(trimmed)) {
      return 'Mã OTP phải gồm đúng 6 chữ số';
    }
    return null;
  }

  static String? validatePassword(String? value, {String label = 'Mật khẩu'}) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Vui lòng nhập ${label.toLowerCase()}';
    }
    if (text.length < 6 || text.length > 50) {
      return '$label phải từ 6 đến 50 ký tự';
    }
    return null;
  }

  static String? validateRoleKey(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập mã vai trò';
    }
    if (trimmed.length < 2 || trimmed.length > 30) {
      return 'Mã vai trò phải từ 2 đến 30 ký tự';
    }
    if (!roleKeyRegex.hasMatch(trimmed)) {
      return 'Mã vai trò chỉ gồm chữ, số và dấu gạch dưới (_)';
    }
    return null;
  }

  static String? validateRoleName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Vui lòng nhập tên vai trò';
    }
    if (trimmed.length < 2 || trimmed.length > 50) {
      return 'Tên vai trò phải từ 2 đến 50 ký tự';
    }
    return null;
  }

  static String? validateRoleDescription(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 200) {
      return 'Mô tả tối đa 200 ký tự';
    }
    return null;
  }
}
