import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dynamic_schema/tenant_config_model.dart';
import '../models/dynamic_schema/dynamic_report_payload.dart';

class TenantSchemaService {
  static const String _cacheKey = 'tenant_config_cache';
  static const String _versionKey = 'tenant_schema_version';
  static const String _offlineQueueKey = 'pending_offline_reports';

  final http.Client _client;

  TenantSchemaService({http.Client? client}) : _client = client ?? http.Client();

  String get _baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.trim().isEmpty) {
      throw StateError('API_BASE_URL no está configurada en el archivo .env');
    }
    return url.trim();
  }

  // Obtener la configuración actual priorizando la caché offline
  Future<TenantConfig?> getCachedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString(_cacheKey);
    if (cachedString == null || cachedString.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(cachedString) as Map<String, dynamic>;
      return TenantConfig.fromJson(decoded);
    } catch (e) {
      if (kDebugMode) {
        print('// Error al parsear caché local de tenant config: $e');
      }
      return null;
    }
  }

  // Sincronizar catálogo con el backend validando schema_version
  Future<TenantConfig> fetchAndSyncConfig({required String tenantId}) async {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('El identificador de tenant no puede estar vacío');
    }
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt(_versionKey) ?? 0;

    final uri = Uri.parse('$_baseUrl/api/v1/tenant/config').replace(
      queryParameters: {
        'tenant_id': tenantId.trim(),
        'current_schema_version': currentVersion.toString(),
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'If-None-Match': currentVersion.toString(),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 304) {
        // Esquema no modificado: devolver versión persistida
        final cached = await getCachedConfig();
        if (cached != null) return cached;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final newConfig = TenantConfig.fromJson(decoded);

        // Actualizar caché atómica
        await prefs.setString(_cacheKey, response.body);
        await prefs.setInt(_versionKey, newConfig.schemaVersion);

        return newConfig;
      }

      throw HttpException('Respuesta inesperada del servidor: ${response.statusCode}');
    } catch (e) {
      // Fallback inmediato a caché local ante falta de red
      final cached = await getCachedConfig();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  // Guardar reporte en la cola offline local
  Future<void> queueOfflineReport(DynamicReportPayload payload) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentQueue = prefs.getStringList(_offlineQueueKey) ?? [];

    // Serializar reporte y agregar a la cola
    currentQueue.add(jsonEncode(payload.toJson()));
    await prefs.setStringList(_offlineQueueKey, currentQueue);
  }

  // Obtener reportes pendientes de sincronización
  Future<List<DynamicReportPayload>> getPendingOfflineReports() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentQueue = prefs.getStringList(_offlineQueueKey) ?? [];

    return currentQueue.map((item) {
      final decoded = jsonDecode(item) as Map<String, dynamic>;
      return DynamicReportPayload.fromJson(decoded);
    }).toList();
  }

  // Purgar reporte sincronizado por su UUID
  Future<void> removePendingOfflineReport(String clientReportUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentQueue = prefs.getStringList(_offlineQueueKey) ?? [];

    currentQueue.removeWhere((item) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        return decoded['client_report_uuid'] == clientReportUuid;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(_offlineQueueKey, currentQueue);
  }
}

