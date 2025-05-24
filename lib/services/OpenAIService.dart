import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  // Usar la clave API desde variables de entorno
  static String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String baseUrl = 'https://api.openai.com/v1';

  // Analizar imágenes con Vision de OpenAI (GPT-4 Vision)
  static Future<Map<String, dynamic>> analyzeImage(
      File imageFile,
      String requestedCategory,
      String prompt,
      ) async {
    try {
      // Convertir imagen a base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // URL para la API de Chat Completions (que soporta GPT-4 Vision)
      final Uri url = Uri.parse('$baseUrl/chat/completions');

      // Construir el mensaje con la imagen
      final Map<String, dynamic> requestBody = {
        "model": "gpt-4o",  // Modelo para análisis de imágenes
        "messages": [
          {
            "role": "system",
            "content": "Eres un asistente especializado en analizar imágenes para reportes de problemas urbanos. Tu trabajo es determinar si la imagen muestra el problema reportado."
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "El usuario está reportando un problema de '$requestedCategory'. $prompt"
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/jpeg;base64,$base64Image"
                }
              }
            ]
          }
        ],
        "max_tokens": 500
      };

      // Realizar la petición a la API
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Extraer la respuesta generada
        final String content = responseData['choices'][0]['message']['content'];

        // Determinar si la imagen coincide con la categoría
        final bool isMatch = _determineIfMatch(content, requestedCategory);

        return {
          'success': true,
          'message': content,
          'isMatch': isMatch,
          'detectedCategory': _extractDetectedCategory(content, requestedCategory),
        };
      } else {
        if (kDebugMode) {
          print('Error en API OpenAI: ${response.statusCode}, ${response.body}');
        }
        return {
          'success': false,
          'message': 'Error al analizar la imagen: Código ${response.statusCode}',
          'isMatch': false,
          'detectedCategory': requestedCategory,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Excepción al analizar imagen: $e');
      }
      return {
        'success': false,
        'message': 'Error al procesar la imagen: $e',
        'isMatch': false,
        'detectedCategory': requestedCategory,
      };
    }
  }

  // Extraer la categoría detectada del texto de respuesta
  static String _extractDetectedCategory(String content, String defaultCategory) {
    // Categorías posibles (mismo orden que en tu app)
    final categories = [
      'bacheo', 'bache', 'pavimento',
      'alumbrado', 'luminaria', 'luz',
      'basura', 'desechos', 'residuos',
      'drenaje', 'alcantarilla', 'agua'
    ];

    // Verificar coincidencias con categorías conocidas
    final contentLower = content.toLowerCase();
    for (final keyword in categories) {
      if (contentLower.contains(keyword)) {
        if (keyword.contains('bache') || keyword.contains('pavimento')) {
          return 'Bacheo';
        } else if (keyword.contains('alumbrado') || keyword.contains('luminaria') || keyword.contains('luz')) {
          return 'Alumbrado Público';
        } else if (keyword.contains('basura') || keyword.contains('desecho') || keyword.contains('residuo')) {
          return 'Basura Acumulada';
        } else if (keyword.contains('drenaje') || keyword.contains('alcantarilla') || keyword.contains('agua')) {
          return 'Drenajes Obstruidos';
        }
      }
    }

    // Si no se encuentra, devolver la categoría por defecto
    return defaultCategory;
  }

  // Determinar si el contenido de la respuesta indica coincidencia con la categoría
  static bool _determineIfMatch(String content, String requestedCategory) {
    final contentLower = content.toLowerCase();
    final categoryLower = requestedCategory.toLowerCase();

    // Verificar confirmación positiva en la respuesta
    if (contentLower.contains('sí coincide') ||
        contentLower.contains('coincide con') ||
        contentLower.contains('es correcto') ||
        contentLower.contains('confirmo que')) {
      return true;
    }

    // Verificar palabras clave específicas por categoría
    switch (categoryLower) {
      case 'bacheo':
        return contentLower.contains('bache') ||
            contentLower.contains('pavimento dañado') ||
            contentLower.contains('asfalto deteriorado');
      case 'alumbrado público':
        return contentLower.contains('luminaria') ||
            contentLower.contains('alumbrado') ||
            contentLower.contains('poste de luz');
      case 'basura acumulada':
        return contentLower.contains('basura') ||
            contentLower.contains('desechos') ||
            contentLower.contains('residuos');
      case 'drenajes obstruidos':
        return contentLower.contains('drenaje') ||
            contentLower.contains('alcantarilla') ||
            contentLower.contains('agua estancada');
      default:
        return false;
    }
  }

  // Verificar metadatos de ubicación en la imagen
  static Future<Map<String, dynamic>> verifyLocationMetadata(
      File imageFile,
      double reportedLatitude,
      double reportedLongitude,
      ) async {
    try {
      // En una implementación real, aquí extraeríamos los metadatos EXIF
      // Para esta demostración, simulamos el resultado

      // Simulación: 80% de probabilidad de éxito en la verificación
      final bool isVerified = DateTime.now().millisecond % 10 < 8;

      return {
        'success': true,
        'isLocationVerified': isVerified,
        'message': isVerified
            ? 'Los metadatos de ubicación coinciden con la ubicación reportada.'
            : 'No se encontraron metadatos de ubicación válidos en la imagen.',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar metadatos: $e');
      }
      return {
        'success': false,
        'isLocationVerified': false,
        'message': 'Error al verificar metadatos de ubicación: $e',
      };
    }
  }
}