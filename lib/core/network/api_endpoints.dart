class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'http://localhost:8000/api';

  static const String checkout = '/checkout';
  static const String orderDetails = '/orders';
  static const String customerAddresses = '/customer/addresses';

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
}
