enum UserRole {
  superAdmin,
  admin,
  finance,
  officeBoy;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.finance:
        return 'Finance Manager';
      case UserRole.officeBoy:
        return 'Office Boy';
    }
  }

  String get roleCode {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.finance:
        return 'finance';
      case UserRole.officeBoy:
        return 'office_boy';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase().replaceAll(' ', '_')) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'finance':
        return UserRole.finance;
      case 'office_boy':
      case 'officeboy':
      default:
        return UserRole.officeBoy;
    }
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;
  final String? password;
  final String? fcmToken;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    this.password,
    this.fcmToken,
  });

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin;
  bool get isFinance => role == UserRole.finance;
  bool get isOfficeBoy => role == UserRole.officeBoy;

  bool get canManageUsers => isSuperAdmin || isAdmin;
  bool get canManageAdmins => isSuperAdmin;
  bool get canApproveRequests => isFinance || isSuperAdmin;
  bool get canViewAllTransactions => isSuperAdmin || isAdmin || isFinance;
  bool get canDeleteTransactions => isSuperAdmin;
  bool get canOverrideStatus => isSuperAdmin;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.roleCode,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'isActive': isActive,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val) {
      if (val is String) {
        return DateTime.tryParse(val)?.toUtc() ?? DateTime.now().toUtc();
      }
      if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
      }
      return DateTime.now().toUtc();
    }

    return AppUser(
      uid: (map['uid'] ?? docId ?? '').toString(),
      name: (map['name'] ?? 'User').toString(),
      email: (map['email'] ?? '').toString(),
      role: UserRole.fromString(map['role']?.toString()),
      createdAt: parseDate(map['createdAt']),
      isActive: map['isActive'] == null ? true : (map['isActive'] as bool),
      password: null,
      fcmToken: map['fcmToken']?.toString(),
    );
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
    String? password,
    String? fcmToken,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      password: password ?? this.password,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
