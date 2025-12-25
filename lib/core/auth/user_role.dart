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

  factory UserTenantRole.fromJson(Map<String, dynamic> json) =>
      _$UserTenantRoleFromJson(json);
}
