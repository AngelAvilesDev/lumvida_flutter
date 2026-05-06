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
      // Limpiar el base64 si tiene prefijo data:image/...
      String cleanBase64 = base64Image;
      String mimeType = 'image/jpeg'; // default

      if (base64Image.contains(',')) {
        final parts = base64Image.split(',');
        cleanBase64 = parts[1];
        // Extraer el MIME real del prefijo
        if (parts[0].contains('image/png')) {
          mimeType = 'image/png';
        } else if (parts[0].contains('image/webp')) {
          mimeType = 'image/webp';
        } else if (parts[0].contains('image/gif')) {
          mimeType = 'image/gif';
        } else {
          mimeType = 'image/jpeg';
        }
      }

      // Detectar tipo de imagen por los primeros bytes (magic bytes)
      try {
        final firstBytes = base64Decode(cleanBase64.substring(0, cleanBase64.length > 20 ? 20 : cleanBase64.length));
        if (firstBytes.length >= 4) {
          if (firstBytes[0] == 0x89 && firstBytes[1] == 0x50) {
            mimeType = 'image/png'; // PNG magic bytes
          } else if (firstBytes[0] == 0xFF && firstBytes[1] == 0xD8) {
            mimeType = 'image/jpeg'; // JPEG magic bytes
          } else if (firstBytes[0] == 0x52 && firstBytes[1] == 0x49) {
            mimeType = 'image/webp'; // RIFF/WebP
          }
        }
      } catch (_) {
        // Si no se puede detectar, usar el default
      }

      if (kDebugMode) {
        print('Tipo MIME detectado: $mimeType');
        print('Categoria solicitada: $requestedCategory');
        print('Longitud del base64: ${cleanBase64.length}');
      }

      // URL para la API de Chat Completions
      final Uri url = Uri.parse('$baseUrl/chat/completions');

      final Map<String, dynamic> requestBody = {
        "model": "gpt-4o",
        "response_format": { "type": "json_object" },
        "messages": [
          {
            "role": "system",
            "content": """Eres un analista de imágenes experto en problemas urbanos. Tu trabajo es verificar si una imagen coincide razonablemente con la categoría reportada por el ciudadano.

CATEGORÍAS VÁLIDAS Y SUS CARACTERÍSTICAS:
1. BACHEO: Hoyos en el pavimento, asfalto agrietado, hundimientos en calles, alcantarillas colapsadas o rotas que forman un hoyo peligroso.
2. ALUMBRADO PÚBLICO: Postes de luz, luminarias, cables de alumbrado, lámparas de calle dañadas o apagadas.
3. BASURA ACUMULADA: Desechos en vía pública, basureros desbordados, acumulación de residuos, escombros.
4. DRENAJES OBSTRUIDOS: Alcantarillas o tapas de drenaje rotas, colapsadas o bloqueadas, agua estancada.

INSTRUCCIONES:
- Responde con un JSON estrictamente con esta estructura:
{
  "isMatch": true o false,
  "detectedCategory": "Bacheo" | "Alumbrado Público" | "Basura Acumulada" | "Drenajes Obstruidos" | "No es problema urbano",
  "reasoning": "Explicación breve en español de lo observado."
}
- "isMatch": true si la imagen muestra un daño urbano que encaja razonablemente con la categoría reportada.
- TOLERANCIA ENTRE CATEGORÍAS SIMILARES: "Bacheo" y "Drenajes Obstruidos" se confunden visualmente (ej. drenaje colapsado = bache). Si el daño es real y cercano a lo reportado, acepta con isMatch = true.
- RECHAZA SOLO si la imagen es claramente spam (selfies, objetos personales, mascotas, interiores de casas) o muestra una calle/lugar en perfecto estado sin ningún daño visible.
- Ante cualquier duda con un daño urbano real: isMatch = true."""
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "El usuario reportó la categoría: '$requestedCategory'. Analiza la imagen y devuelve el JSON requerido."
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:$mimeType;base64,$cleanBase64",
                  "detail": "high"
                }
              }
            ]
          }
        ],
        "max_tokens": 400,
        "temperature": 0.0
      };

      // Realizar la petición a la API
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: utf8.encode(jsonEncode(requestBody)),
      );

      if (kDebugMode) {
        print('OpenAI status code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = jsonDecode(responseBody);
        final String content = responseData['choices'][0]['message']['content'];

        if (kDebugMode) {
          print('Respuesta de OpenAI: $content');
        }

        // Limpiar posibles bloques markdown
        String cleanJsonStr = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        try {
          final Map<String, dynamic> jsonResponse = jsonDecode(cleanJsonStr);
          final bool isMatch = jsonResponse['isMatch'] ?? false;
          final String detectedCategory = jsonResponse['detectedCategory'] ?? 'No es problema urbano';
          final String reasoning = jsonResponse['reasoning'] ?? '';

          if (kDebugMode) {
            print('isMatch: $isMatch | detectedCategory: $detectedCategory');
            print('reasoning: $reasoning');
          }

          return {
            'success': true,
            'message': reasoning,
            'isMatch': isMatch,
            'detectedCategory': detectedCategory,
          };
        } catch (e) {
          if (kDebugMode) {
            print('Error parseando JSON de OpenAI: $e');
            print('Contenido recibido: $content');
          }
          // Si no se puede parsear el JSON, asumir rechazo por seguridad
          return {
            'success': false,
            'message': 'Error al interpretar la respuesta del análisis. Intenta de nuevo.',
            'isMatch': false,
            'detectedCategory': requestedCategory,
          };
        }
      } else {
        // Log detallado del error para diagnosticar
        final String errorBody = utf8.decode(response.bodyBytes);
        if (kDebugMode) {
          print('Error en API OpenAI: ${response.statusCode}');
          print('Error body: $errorBody');
        }
        return {
          'success': false,
          'message': 'Error al analizar la imagen (código ${response.statusCode}). Verifica tu conexión e intenta de nuevo.',
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

    // Ya no usamos palabras clave aisladas porque causan falsos positivos
    // (ej. "No veo ninguna luminaria" marcaba isMatch = true por la palabra "luminaria")
    
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