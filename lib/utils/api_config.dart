import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // GOOGLE MAPS API KEY
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      if (kDebugMode) {
        print('❌ Google Maps API Key no encontrada en .env');
      }
      return '';
    }
    return key;
  }

  // OPENAI API KEY
  static String get openAiApiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      if (kDebugMode) {
        print('❌ OpenAI API Key no encontrada en .env');
      }
      return '';
    }
    return key;
  }

  // VERIFICAR QUE TODAS LAS KEYS ESTÉN CONFIGURADAS
  static bool get areKeysConfigured {
    final googleKey = googleMapsApiKey;
    final openAiKey = openAiApiKey;

    if (googleKey.isEmpty) {
      if (kDebugMode) {
        print('⚠️  Google Maps API Key faltante');
      }
      return false;
    }

    if (openAiKey.isEmpty) {
      if (kDebugMode) {
        print('⚠️  OpenAI API Key faltante');
      }
      return false;
    }

    return true;
  }

  // MÉTODO PARA DEBUG - MOSTRAR STATUS DE LAS KEYS
  static void debugApiKeys() {
    if (kDebugMode) {
      print('=== STATUS DE API KEYS ===');
      print('Google Maps: ${googleMapsApiKey.isNotEmpty ? "✅ Configurada" : "❌ Faltante"}');
      print('OpenAI: ${openAiApiKey.isNotEmpty ? "✅ Configurada" : "❌ Faltante"}');
      print('========================');
    }
  }

  // MÉTODO PARA VALIDAR FORMATO DE API KEY
  static bool isValidGoogleMapsKey(String key) {
    // Las API keys de Google Maps suelen empezar con "AIza"
    return key.isNotEmpty && key.startsWith('AIza') && key.length > 30;
  }

  static bool isValidOpenAiKey(String key) {
    // Las API keys de OpenAI suelen empezar con "sk-"
    return key.isNotEmpty && key.startsWith('sk-') && key.length > 40;
  }

  // VALIDAR TODAS LAS KEYS
  static Map<String, bool> validateAllKeys() {
    return {
      'google_maps': isValidGoogleMapsKey(googleMapsApiKey),
      'openai': isValidOpenAiKey(openAiApiKey),
    };
  }
}