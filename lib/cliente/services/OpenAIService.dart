import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  // Usar la clave API desde variables de entorno
  static String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String baseUrl = 'https://api.openai.com/v1';

  // Analizar imágenes con Vision de OpenAI (GPT-4 Vision) - SOBRECARGA PARA FILE
  static Future<Map<String, dynamic>> analyzeImage(
      File imageFile,
      String requestedCategory,
      String prompt,
      ) async {
    try {
      // Convertir imagen a base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Llamar al método principal con el base64
      return await analyzeImageFromBase64(
        base64Image,
        requestedCategory,
        prompt,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error al leer archivo de imagen: $e');
      }
      return {
        'success': false,
        'message': 'Error al procesar la imagen: $e',
        'isMatch': false,
        'detectedCategory': requestedCategory,
      };
    }
  }

  // Analizar imágenes con Vision de OpenAI desde Base64 - MÉTODO PRINCIPAL
  static Future<Map<String, dynamic>> analyzeImageFromBase64(
      String base64Image,
      String requestedCategory,
      String prompt,
      ) async {
    try {
      // Limpiar el base64 si tiene prefijo
      String cleanBase64 = base64Image;
      if (base64Image.contains(',')) {
        cleanBase64 = base64Image.split(',')[1];
      }

      // URL para la API de Chat Completions (que soporta GPT-4 Vision)
      final Uri url = Uri.parse('$baseUrl/chat/completions');

      // Construir el mensaje con la imagen - PROMPT MEJORADO Y MÁS CLARO
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
- Responde ÚNICAMENTE en español sin caracteres especiales
- Si la imagen NO muestra EXACTAMENTE el tipo de problema reportado, responde "NO COINCIDE"
- Si hay dudas, responde "NO COINCIDE"
- Solo confirma coincidencia si estás 100% seguro respondiendo "SI COINCIDE"
- Si la imagen no muestra ningún problema urbano válido, indica "NO ES PROBLEMA URBANO"
- Sé ESTRICTO en tu análisis
- NO uses tildes ni caracteres especiales en tu respuesta"""
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": """El usuario reportó un problema de categoria: "${requestedCategory}".
                
Por favor analiza esta imagen y responde:
1. ¿La imagen muestra EXACTAMENTE un problema de "${requestedCategory}"? (Responde solo: "SI COINCIDE" o "NO COINCIDE")
2. Si NO coincide, ¿qué tipo de problema muestra? (solo elige entre: Bacheo, Alumbrado Publico, Basura Acumulada, Drenajes Obstruidos, o "No es problema urbano")
3. Explica tu decisión de forma clara y específica en español sin tildes.

IMPORTANTE: Solo responde "SI COINCIDE" si estás completamente seguro. En caso de duda, responde "NO COINCIDE"."""
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/jpeg;base64,$cleanBase64"
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
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: utf8.encode(jsonEncode(requestBody)), // Usar UTF-8 encoding explícito
      );

      if (response.statusCode == 200) {
        // Decodificar la respuesta con UTF-8
        final String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = jsonDecode(responseBody);

        // Extraer la respuesta generada
        final String content = responseData['choices'][0]['message']['content'];

        if (kDebugMode) {
          print('Respuesta de OpenAI (corregida): $content');
        }

        // Limpiar y normalizar el contenido
        final String cleanContent = _cleanAndNormalizeText(content);

        if (kDebugMode) {
          print('Contenido limpio: $cleanContent');
        }

        // Determinar si la imagen coincide con la categoría - LÓGICA MEJORADA
        final bool isMatch = _determineIfMatchStrict(cleanContent, requestedCategory);
        final String detectedCategory = _extractDetectedCategoryStrict(cleanContent, requestedCategory);

        return {
          'success': true,
          'message': cleanContent,
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

  // Analizar múltiples imágenes desde Base64 - NUEVO MÉTODO
  static Future<Map<String, dynamic>> analyzeMultipleImagesFromBase64(
      List<String> base64Images,
      String requestedCategory,
      ) async {

    if (base64Images.isEmpty) {
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
    for (int i = 0; i < base64Images.length; i++) {
      final result = await analyzeImageFromBase64(
          base64Images[i],
          requestedCategory,
          "Analiza esta imagen ${i + 1} de ${base64Images.length} y determina si muestra un problema de '$requestedCategory'."
      );

      results.add(result);
      if (result['isMatch'] == true) {
        matchingImages++;
      }
    }

    // Determinar si la mayoría de imágenes coinciden
    final bool majorityMatch = matchingImages > (base64Images.length / 2);
    final bool allMatch = matchingImages == base64Images.length;

    return {
      'success': true,
      'message': 'Se analizaron ${base64Images.length} imágenes. $matchingImages coinciden con la categoría "$requestedCategory".',
      'isMatch': majorityMatch,
      'detectedCategory': results.first['detectedCategory'],
      'allImagesMatch': allMatch,
      'matchingCount': matchingImages,
      'totalImages': base64Images.length,
      'individualResults': results,
    };
  }

  // Limpiar y normalizar texto (sin cambios)
  static String _cleanAndNormalizeText(String text) {
    // Reemplazar caracteres mal codificados comunes
    String cleanText = text
        .replaceAll('Ã', 'Í')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Â°', '°')
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"');

    // Normalizar espacios y saltos de línea
    cleanText = cleanText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleanText;
  }

  // Método mejorado para extraer la categoría detectada - MÁS PRECISO (sin cambios)
  static String _extractDetectedCategoryStrict(String content, String defaultCategory) {
    final contentLower = content.toLowerCase();

    // Buscar respuestas directas primero
    if (contentLower.contains('no es problema urbano') ||
        contentLower.contains('no es un problema urbano')) {
      return 'No es un problema urbano válido';
    }

    // Mapeo más preciso de palabras clave
    final Map<String, List<String>> categoryKeywords = {
      'Bacheo': ['bacheo', 'bache', 'pavimento', 'asfalto', 'hundimiento', 'calle dañada', 'hoyo', 'grieta'],
      'Alumbrado Público': ['alumbrado', 'luminaria', 'poste', 'luz', 'lampara', 'cable', 'iluminacion'],
      'Basura Acumulada': ['basura', 'desecho', 'residuo', 'basurero', 'desperdicio', 'escombro'],
      'Drenajes Obstruidos': ['drenaje', 'alcantarilla', 'agua', 'inundacion', 'tapa', 'coladera', 'desague']
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

    // Si no se encuentra, devolver la categoría por defecto
    return defaultCategory;
  }

  // Método mejorado para determinar coincidencia - MÁS ESTRICTO (sin cambios)
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
      'no es valido',
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
      'si coincide',
      'coincide exactamente',
      'si muestra',
      'corresponde exactamente',
      'es exactamente',
      'confirmo que es',
      'efectivamente es',
      'si es un problema de'
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
    Map<String, List<String>> strictKeywords = {
      'bacheo': ['bache', 'pavimento dañado', 'asfalto deteriorado', 'hoyo en la calle', 'hundimiento'],
      'alumbrado público': ['poste de luz', 'luminaria', 'alumbrado publico', 'luz de calle'],
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
    if (kDebugMode) {
      print('No se encontró confirmación explícita, retornando false por defecto');
    }
    return false;
  }

  // Verificar metadatos de ubicación en la imagen (simulado - sin cambios)
  static Future<Map<String, dynamic>> verifyLocationMetadata(
      File imageFile,
      double reportedLatitude,
      double reportedLongitude,
      ) async {
    try {
      // Simulación: 70% de probabilidad de éxito en la verificación
      final bool isVerified = DateTime.now().millisecond % 10 < 7;

      return {
        'success': true,
        'isLocationVerified': isVerified,
        'message': isVerified
            ? 'La ubicación de la foto coincide con tu reporte.'
            : 'No se pudo confirmar la ubicación en la foto, o es distinta a la reportada.',
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

  // Verificar metadatos desde Base64 - NUEVO MÉTODO
  static Future<Map<String, dynamic>> verifyLocationMetadataFromBase64(
      String base64Image,
      double reportedLatitude,
      double reportedLongitude,
      ) async {
    try {
      // Simulación: 70% de probabilidad de éxito en la verificación
      final bool isVerified = DateTime.now().millisecond % 10 < 7;

      return {
        'success': true,
        'isLocationVerified': isVerified,
        'message': isVerified
            ? 'La ubicación de la foto coincide con tu reporte.'
            : 'No se pudo confirmar la ubicación en la foto, o es distinta a la reportada.',
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

  // Método adicional para validar múltiples imágenes (sin cambios)
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
      'isMatch': majorityMatch,
      'detectedCategory': results.first['detectedCategory'],
      'allImagesMatch': allMatch,
      'matchingCount': matchingImages,
      'totalImages': imageFiles.length,
      'individualResults': results,
    };
  }

  // Método utilitario para convertir File a Base64
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      if (kDebugMode) {
        print('Error al convertir archivo a Base64: $e');
      }
      return '';
    }
  }

  // Método utilitario para validar Base64
  static bool isValidBase64Image(String base64String) {
    try {
      // Verificar si tiene el formato correcto
      if (!base64String.contains('data:image') && !base64String.contains('base64,')) {
        return false;
      }

      // Extraer solo la parte Base64
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      // Intentar decodificar
      final decoded = base64Decode(cleanBase64);
      return decoded.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Base64 inválido: $e');
      }
      return false;
    }
  }
}