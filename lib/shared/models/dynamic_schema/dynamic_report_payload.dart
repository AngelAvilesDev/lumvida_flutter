// Modelo para el envío e idempotencia de reportes dinámicos

class ReportLocation {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? addressReference;

  const ReportLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.addressReference,
  });

  factory ReportLocation.fromJson(Map<String, dynamic> json) => ReportLocation(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
    addressReference: json['address_reference'],
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
    if (addressReference != null) 'address_reference': addressReference,
  };
}

class ClientMetadata {
  final DateTime offlineCreatedAt;
  final DateTime? syncedAt;
  final String devicePlatform;
  final String appVersion;

  const ClientMetadata({
    required this.offlineCreatedAt,
    this.syncedAt,
    required this.devicePlatform,
    required this.appVersion,
  });

  factory ClientMetadata.fromJson(Map<String, dynamic> json) => ClientMetadata(
    offlineCreatedAt: DateTime.parse(json['offline_created_at']),
    syncedAt: json['synced_at'] != null ? DateTime.parse(json['synced_at']) : null,
    devicePlatform: json['device_platform'] ?? 'unknown',
    appVersion: json['app_version'] ?? '1.0.0',
  );

  Map<String, dynamic> toJson() => {
    'offline_created_at': offlineCreatedAt.toIso8601String(),
    if (syncedAt != null) 'synced_at': syncedAt!.toIso8601String(),
    'device_platform': devicePlatform,
    'app_version': appVersion,
  };
}

class DynamicReportPayload {
  final String clientReportUuid;
  final String tenantId;
  final String categoryId;
  final String reportTypeId;
  final int schemaVersion;
  final ClientMetadata clientMetadata;
  final ReportLocation location;
  final Map<String, dynamic> formData;

  const DynamicReportPayload({
    required this.clientReportUuid,
    required this.tenantId,
    required this.categoryId,
    required this.reportTypeId,
    required this.schemaVersion,
    required this.clientMetadata,
    required this.location,
    required this.formData,
  });

  factory DynamicReportPayload.fromJson(Map<String, dynamic> json) => DynamicReportPayload(
    clientReportUuid: json['client_report_uuid'] ?? '',
    tenantId: json['tenant_id'] ?? '',
    categoryId: json['category_id'] ?? '',
    reportTypeId: json['report_type_id'] ?? '',
    schemaVersion: json['schema_version'] ?? 1,
    clientMetadata: ClientMetadata.fromJson(json['client_metadata'] as Map<String, dynamic>? ?? {}),
    location: ReportLocation.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
    formData: (json['form_data'] as Map<String, dynamic>? ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'client_report_uuid': clientReportUuid,
    'tenant_id': tenantId,
    'category_id': categoryId,
    'report_type_id': reportTypeId,
    'schema_version': schemaVersion,
    'client_metadata': clientMetadata.toJson(),
    'location': location.toJson(),
    'form_data': formData,
  };
}

