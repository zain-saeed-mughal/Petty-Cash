class AppConstants {
  static const String appName = 'Petty Cash Manager';
  static const String appVersion = '1.0.0';

  // Currency
  static const String defaultCurrencySymbol = 'Rs. ';
  static const String defaultCurrencyCode = 'PKR';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String requestsCollection = 'requests';

  // Storage paths
  static const String receiptStoragePath = 'receipts';

  // Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdmin = 'admin';
  static const String roleFinance = 'finance';
  static const String roleOfficeBoy = 'office_boy';

  // Statuses
  static const String statusPending = 'Pending';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';
  static const String statusPaid = 'Paid';
}
