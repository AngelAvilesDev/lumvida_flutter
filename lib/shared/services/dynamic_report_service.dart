// Servicio para el despacho desacoplado y sincronización de reportes al backend

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/dynamic_schema/dynamic_report_payload.dart';
import 'tenant_schema_service.dart';

class DynamicReportService {
  final http.Client _client;
  final TenantSchemaService _schemaService;
  final Uuid _uuid;

  DynamicReportService({
    http.Client? client,
    TenantSchemaService? schemaService,
  })  : _client = client ?? http.Client(),
        _schemaService = schemaService ?? TenantSchemaService(),
        _uuid = const Uuid();

  String get _baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.trim().isEmpty) {
      throw StateError('API_BASE_URL no está configurada en el archivo .env');
    }
    return url.trim();
  }

  // Subir evidencia fotográfica al endpoint de almacenamiento modular del backend
  Future<String> uploadEvidence({
    required File file,
    required String tenantId,
    String? authToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/storage/upload');
    final request = http.MultipartRequest('POST', uri);

    if (authToken != null && authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    request.fields['tenant_id'] = tenantId;
    request.fields['context'] = 'report_evidence';

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      file.path,
    );
    request.files.add(multipartFile);

    final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final filePath = decoded['file_path'] as String?;
      if (filePath == null || filePath.isEmpty) {
        throw const FormatException('El servidor no retornó el file_path de la evidencia');
      }
      return filePath;
    }

    throw HttpException('Fallo al subir evidencia: ${response.statusCode} - ${response.body}');
  }

  // Enviar reporte al backend con soporte de idempotencia y encolado offline
  Future<bool> submitReport({
    required String tenantId,
    required String categoryId,
    required String reportTypeId,
    required int schemaVersion,
    required ReportLocation location,
    required Map<String, dynamic> rawFormData,
    required List<File> localEvidenceFiles,
    String? authToken,
    String? existingUuid,
  }) async {
    final clientUuid = existingUuid ?? _uuid.v4();

    try {
      // Subir primero las evidencias fotográficas si existen archivos locales
      final List<String> remoteFilePaths = [];
      for (final file in localEvidenceFiles) {
        final path = await uploadEvidence(
          file: file,
          tenantId: tenantId,
          authToken: authToken,
        );
        remoteFilePaths.add(path);
      }

      final effectiveFormData = Map<String, dynamic>.from(rawFormData);
      if (remoteFilePaths.isNotEmpty) {
        effectiveFormData['fotos_evidencia'] = remoteFilePaths;
      }

      final payload = DynamicReportPayload(
        clientReportUuid: clientUuid,
        tenantId: tenantId,
        categoryId: categoryId,
        reportTypeId: reportTypeId,
        schemaVersion: schemaVersion,
        clientMetadata: ClientMetadata(
          offlineCreatedAt: DateTime.now(),
          devicePlatform: Platform.operatingSystem,
          appVersion: dotenv.env['APP_VERSION'] ?? '1.0.0+1',
        ),
        location: location,
        formData: effectiveFormData,
      );

      final uri = Uri.parse('$_baseUrl/api/v1/reports');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(payload.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      throw HttpException('Error del servidor al registrar reporte: ${response.statusCode}');
    } on SocketException {
      // Ante fallo de red: persistir en la cola offline para reintento automático
      final offlinePayload = DynamicReportPayload(
        clientReportUuid: clientUuid,
        tenantId: tenantId,
        categoryId: categoryId,
        reportTypeId: reportTypeId,
        schemaVersion: schemaVersion,
        clientMetadata: ClientMetadata(
          offlineCreatedAt: DateTime.now(),
          devicePlatform: Platform.operatingSystem,
          appVersion: dotenv.env['APP_VERSION'] ?? '1.0.0+1',
        ),
        location: location,
        formData: rawFormData,
      );
      await _schemaService.queueOfflineReport(offlinePayload);
      return false;
    }
  }

  // Procesar cola de reportes pendientes al recuperar conectividad
  Future<int> processOfflineQueue({String? authToken}) async {
    final pending = await _schemaService.getPendingOfflineReports();
    int syncedCount = 0;

    for (final item in pending) {
      try {
        final uri = Uri.parse('$_baseUrl/api/v1/reports');
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        if (authToken != null && authToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $authToken';
        }

        final response = await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(item.toJson()),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _schemaService.removePendingOfflineReport(item.clientReportUuid);
          syncedCount++;
        }
      } catch (_) {
        // Detener procesamiento en lote ante fallo de red subsecuente
        break;
      }
    }

    return syncedCount;
  }
}

