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

  factory Tenant.fromJson(Map<String, dynamic> json) {
    // Handle branding field conversion from Map to TenantBranding
    TenantBranding? branding;
    if (json['branding'] != null) {
      final brandingData = json['branding'];
      if (brandingData is Map) {
        branding = TenantBranding.fromJson(
          Map<String, dynamic>.from(brandingData),
        );
      }
    }

    return Tenant(
      id: json['id'] as String,
      name: json['name'] as String,
      logo: json['logo'] as String?,
      branding: branding,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
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
