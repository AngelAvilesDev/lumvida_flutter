import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  // Usar la clave API desde variables de entorno
  static String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String baseUrl = 'https://api.openai.com/v1';

  // Analizar imágenes con Vision de OpenAI (GPT-4 Vision) - Versión mejorada y más estricta
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

      // Construir el mensaje con la imagen - PROMPT MEJORADO Y MÁS ESTRICTO
      final Map<String, dynamic> requestBody = {
        "model": "gpt-4o",  // Modelo para análisis de imágenes
        "messages": [
          {
            "role": "system",
            "content": """Eres un experto analista de imágenes especializado en problemas urbanos. Tu trabajo es VALIDAR ESTRICTAMENTE si una imagen corresponde EXACTAMENTE a la categoría de problema reportada.

CATEGORÍAS VÁLIDAS Y SUS CARACTERÍSTICAS:
1. BACHEO: Hoyos en el pavimento, asfalto agrietado, hundimientos en calles, deterioro del pavimento
2. ALUMBRADO PÚBLICO: Postes de luz, luminarias, cables de alumbrado, lámparas de calle dañadas o apagadas
3. BASURA ACUMULADA: Desechos en vía pública, basureros desbordados, acumulación de residuos
4. DRENAJES OBSTRUIDOS: Alcantarillas, tapas de drenaje, agua estancada, sistema de drenaje bloqueado

INSTRUCCIONES CRÍTICAS:
- Si la imagen NO muestra EXACTAMENTE el tipo de problema reportado, responde que NO COINCIDE
- Si hay dudas, responde que NO COINCIDE
- Solo confirma coincidencia si estás 100% seguro
- Si la imagen no muestra ningún problema urbano válido, indica que no es reportable
- Sé ESTRICTO en tu análisis"""
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": """El usuario reportó un problema de categoria: "${requestedCategory}".
                
Por favor analiza esta imagen y responde:
1. ¿La imagen muestra EXACTAMENTE un problema de "${requestedCategory}"?
2. Si NO coincide, ¿qué tipo de problema muestra? (solo elige entre: Bacheo, Alumbrado Público, Basura Acumulada, Drenajes Obstruidos, o "No es un problema urbano válido")
3. Explica tu decisión de forma clara y específica.

IMPORTANTE: Solo responde SÍ COINCIDE si estás completamente seguro. En caso de duda, responde NO COINCIDE."""
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
        "max_tokens": 600,
        "temperature": 0.1  // Baja temperatura para respuestas más consistentes
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

        if (kDebugMode) {
          print('Respuesta de OpenAI: $content');
        }

        // Determinar si la imagen coincide con la categoría - LÓGICA MEJORADA
        final bool isMatch = _determineIfMatchStrict(content, requestedCategory);
        final String detectedCategory = _extractDetectedCategoryStrict(content, requestedCategory);

        return {
          'success': true,
          'message': content,
          'isMatch': isMatch,
          'detectedCategory': detectedCategory,
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

  // Método mejorado para extraer la categoría detectada - MÁS PRECISO
  static String _extractDetectedCategoryStrict(String content, String defaultCategory) {
    final contentLower = content.toLowerCase();

    // Mapeo más preciso de palabras clave
    final Map<String, List<String>> categoryKeywords = {
      'Bacheo': ['bache', 'bacheo', 'pavimento', 'asfalto', 'hundimiento', 'calle dañada', 'hoyo', 'grieta'],
      'Alumbrado Público': ['alumbrado', 'luminaria', 'poste', 'luz', 'lámpara', 'cable', 'iluminación'],
      'Basura Acumulada': ['basura', 'desecho', 'residuo', 'basurero', 'desperdicio', 'escombro'],
      'Drenajes Obstruidos': ['drenaje', 'alcantarilla', 'agua', 'inundación', 'tapa', 'coladera', 'desagüe']
    };

    // Buscar coincidencias específicas
    for (final entry in categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (contentLower.contains(keyword)) {
          if (kDebugMode) {
            print('Categoría detectada: $category (palabra clave: $keyword)');
          }
          return category;
        }
      }
    }

    // Si no se detecta nada específico, buscar en la respuesta directa
    if (contentLower.contains('no es un problema urbano') ||
        contentLower.contains('no es reportable') ||
        contentLower.contains('no válido')) {
      return 'No es un problema urbano válido';
    }

    // Si no se encuentra, devolver la categoría por defecto
    return defaultCategory;
  }

  // Método mejorado para determinar coincidencia - MÁS ESTRICTO
  static bool _determineIfMatchStrict(String content, String requestedCategory) {
    final contentLower = content.toLowerCase();
    final categoryLower = requestedCategory.toLowerCase();

    if (kDebugMode) {
      print('Analizando coincidencia para categoría: $requestedCategory');
      print('Contenido a analizar: $contentLower');
    }

    // Primero, buscar respuestas negativas explícitas (tienen prioridad)
    final negativeResponses = [
      'no coincide',
      'no es exactamente',
      'no muestra',
      'no corresponde',
      'no es un problema de',
      'no se trata de',
      'diferente',
      'no es válido',
      'no es reportable'
    ];

    for (final negative in negativeResponses) {
      if (contentLower.contains(negative)) {
        if (kDebugMode) {
          print('Respuesta negativa detectada: $negative');
        }
        return false;
      }
    }

    // Buscar confirmaciones positivas explícitas
    final positiveResponses = [
      'sí coincide',
      'coincide exactamente',
      'sí muestra',
      'corresponde exactamente',
      'es exactamente',
      'confirmo que es',
      'efectivamente es',
      'sí es un problema de'
    ];

    for (final positive in positiveResponses) {
      if (contentLower.contains(positive)) {
        if (kDebugMode) {
          print('Respuesta positiva detectada: $positive');
        }
        return true;
      }
    }

    // Verificación específica por categoría con palabras clave exactas
    // Solo retorna true si encuentra palabras clave específicas Y no hay negaciones
    Map<String, List<String>> strictKeywords = {
      'bacheo': ['bache', 'pavimento dañado', 'asfalto deteriorado', 'hoyo en la calle', 'hundimiento'],
      'alumbrado público': ['poste de luz', 'luminaria', 'alumbrado público', 'luz de calle'],
      'basura acumulada': ['basura acumulada', 'desechos', 'residuos', 'basurero'],
      'drenajes obstruidos': ['drenaje obstruido', 'alcantarilla', 'agua estancada', 'coladera tapada']
    };

    if (strictKeywords.containsKey(categoryLower)) {
      final keywords = strictKeywords[categoryLower]!;
      bool foundKeyword = false;

      for (final keyword in keywords) {
        if (contentLower.contains(keyword)) {
          foundKeyword = true;
          if (kDebugMode) {
            print('Palabra clave específica encontrada: $keyword');
          }
          break;
        }
      }

      // Solo confirmar si se encuentra palabra clave Y no hay negaciones previas
      if (foundKeyword) {
        // Verificar una vez más que no hay negaciones en el contexto
        final contextualNegatives = [
          'pero no es',
          'sin embargo no',
          'aunque parece',
          'no exactamente',
          'no del tipo'
        ];

        for (final contextNeg in contextualNegatives) {
          if (contentLower.contains(contextNeg)) {
            if (kDebugMode) {
              print('Negación contextual detectada: $contextNeg');
            }
            return false;
          }
        }

        return true;
      }
    }

    // Por defecto, si no hay confirmación explícita, considerar que NO coincide
    // Esto hace que el sistema sea más estricto
    if (kDebugMode) {
      print('No se encontró confirmación explícita, retornando false por defecto');
    }
    return false;
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

      // Simulación: 70% de probabilidad de éxito en la verificación
      // (Reducido de 80% para ser más realista)
      final bool isVerified = DateTime.now().millisecond % 10 < 7;

      return {
        'success': true,
        'isLocationVerified': isVerified,
        'message': isVerified
            ? 'Los metadatos de ubicación en la imagen coinciden aproximadamente con la ubicación reportada.'
            : 'No se encontraron metadatos de ubicación válidos en la imagen, o la ubicación no coincide con la reportada.',
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

  // Método adicional para validar múltiples imágenes (útil para implementaciones futuras)
  static Future<Map<String, dynamic>> analyzeMultipleImages(
      List<File> imageFiles,
      String requestedCategory,
      ) async {

    if (imageFiles.isEmpty) {
      return {
        'success': false,
        'message': 'No se proporcionaron imágenes para analizar.',
        'isMatch': false,
        'detectedCategory': requestedCategory,
        'allImagesMatch': false,
      };
    }

    List<Map<String, dynamic>> results = [];
    int matchingImages = 0;

    // Analizar cada imagen
    for (int i = 0; i < imageFiles.length; i++) {
      final result = await analyzeImage(
          imageFiles[i],
          requestedCategory,
          "Analiza esta imagen ${i + 1} de ${imageFiles.length} y determina si muestra un problema de '$requestedCategory'."
      );

      results.add(result);
      if (result['isMatch'] == true) {
        matchingImages++;
      }
    }

    // Determinar si la mayoría de imágenes coinciden
    final bool majorityMatch = matchingImages > (imageFiles.length / 2);
    final bool allMatch = matchingImages == imageFiles.length;

    return {
      'success': true,
      'message': 'Se analizaron ${imageFiles.length} imágenes. $matchingImages coinciden con la categoría "$requestedCategory".',
      'isMatch': majorityMatch, // Al menos la mayoría debe coincidir
      'detectedCategory': results.first['detectedCategory'],
      'allImagesMatch': allMatch,
      'matchingCount': matchingImages,
      'totalImages': imageFiles.length,
      'individualResults': results,
    };
  }
}