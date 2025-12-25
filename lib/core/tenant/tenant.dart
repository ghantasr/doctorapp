import 'package:freezed_annotation/freezed_annotation.dart';

part 'tenant.freezed.dart';
part 'tenant.g.dart';

@freezed
class Tenant with _$Tenant {
  const factory Tenant({
    required String id,
    required String name,
    String? logo,
    TenantBranding? branding,
    DateTime? createdAt,
  }) = _Tenant;

  factory Tenant.fromJson(Map<String, dynamic> json) =>
      _$TenantFromJson(json);
}

@freezed
class TenantBranding with _$TenantBranding {
  const factory TenantBranding({
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? logoUrl,
    String? fontFamily,
  }) = _TenantBranding;

  factory TenantBranding.fromJson(Map<String, dynamic> json) =>
      _$TenantBrandingFromJson(json);
}
