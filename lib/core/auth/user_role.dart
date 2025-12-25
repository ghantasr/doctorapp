import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_role.freezed.dart';
part 'user_role.g.dart';

enum UserRole {
  @JsonValue('doctor')
  doctor,
  @JsonValue('admin')
  admin,
  @JsonValue('patient')
  patient;

  bool get isDoctor => this == UserRole.doctor;
  bool get isAdmin => this == UserRole.admin;
  bool get isPatient => this == UserRole.patient;

  bool get canAccessDoctorApp => isDoctor || isAdmin;
  bool get canAccessPatientApp => isPatient;
}

@freezed
class UserTenantRole with _$UserTenantRole {
  const factory UserTenantRole({
    required String userId,
    required String tenantId,
    required UserRole role,
    DateTime? createdAt,
  }) = _UserTenantRole;

  factory UserTenantRole.fromJson(Map<String, dynamic> json) {
    // Handle role field - convert string to enum
    UserRole role;
    final roleValue = json['role'];
    
    if (roleValue is String) {
      role = UserRole.values.firstWhere(
        (e) => e.name == roleValue,
        orElse: () => UserRole.patient,
      );
    } else {
      // If it's already a UserRole or enum, use it
      role = roleValue as UserRole? ?? UserRole.patient;
    }

    return UserTenantRole(
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      role: role,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'tenant_id': tenantId,
    'role': role.name,
    'created_at': createdAt?.toIso8601String(),
  };
}
