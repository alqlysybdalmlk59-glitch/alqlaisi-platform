class AuthValidators {
  AuthValidators._();

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'أدخل الاسم الكامل.';
    }

    if (name.length < 3) {
      return 'الاسم قصير جدًا.';
    }

    return null;
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'أدخل رقم الهاتف.';
    }

    final normalized = phone.replaceAll(RegExp(r'[\s-]'), '');

    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(normalized)) {
      return 'أدخل رقم هاتف صحيحًا.';
    }

    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'أدخل كلمة المرور.';
    }

    if (password.length < 8) {
      return 'كلمة المرور يجب أن تتكون من 8 أحرف على الأقل.';
    }

    return null;
  }

  static String? confirmPassword(
    String? value,
    String originalPassword,
  ) {
    if (value == null || value.isEmpty) {
      return 'أعد كتابة كلمة المرور.';
    }

    if (value != originalPassword) {
      return 'كلمتا المرور غير متطابقتين.';
    }

    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return null;

    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email)) {
      return 'أدخل بريدًا إلكترونيًا صحيحًا.';
    }

    return null;
  }
}
