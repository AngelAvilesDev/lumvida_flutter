---
name: experto-verificacion-ia
description: Especialista en el agente de verificación de imágenes con IA (Lumi): prompts, parseo robusto, reintentos, costo, privacidad y detección de fraude. Usar al tocar OpenAIService, VerificacionIAViewModel o VerificacionIAReporteScreen.
---

# Experto en Verificación con IA

## Alcance
`lib/cliente/services/OpenAIService.dart`, `lib/cliente/viewmodels/VerificacionIAViewModel.dart`, `lib/cliente/screens/VerificacionIAReporteScreen.dart`, `lib/cliente/utils/report_categories.dart`.

## Principios de diseño
1. **La IA asesora, no bloquea sola:** si el servicio falla (red, 5xx, cuota), el reporte continúa con bandera `ia_verificada=false` y revisión humana posterior. Solo se rechaza con una detección confiable y explicable.
2. **Salida estructurada y validada:** `response_format: json_object` (o esquema JSON) y validación de claves/tipos. `detectedCategory` debe pertenecer a la lista cerrada de categorías; si no, se normaliza o se descarta. Nunca parsear texto libre por palabras clave.
3. **Resultado enriquecido:** `isMatch`, `detectedCategory`, `confidence` (0 a 1), `severity` (baja/media/alta/crítica), `quality` (`ok`/`borrosa`/`oscura`/`lejana`), `suspectedFake` (captura de pantalla, foto de internet, imagen generada) y `reasoning` corto.
4. **Una sola llamada para varias fotos:** enviar todas las imágenes (máx. 3) en un mensaje y pedir veredicto global más veredicto por imagen, en lugar de N llamadas.
5. **Umbrales configurables:** aceptar con `confidence` alta, pedir otra foto en rango medio, rechazar solo con evidencia clara. Constantes en un solo lugar.

## Robustez de red
- Timeout explícito, reintento con backoff exponencial + jitter solo en timeout/429/5xx (máx. 3 intentos); respetar `Retry-After`.
- 401/403: no reintentar, registrar y degradar con elegancia. 400: no reintentar.
- Cancelar la solicitud si el usuario sale de la pantalla; evitar `notifyListeners` tras `dispose`.
- Caché de resultado por hash de imagen y categoría para no repetir cobros en reintentos del usuario.
- Límite de intentos de verificación por reporte y por usuario (anti-abuso y control de costo).

## Calidad previa a la IA (local, gratis)
- Rechazar antes de llamar a la API: archivo vacío, resolución muy baja, MIME no permitido, tamaño excesivo.
- Detectar desenfoque/oscuridad básica si es viable sin dependencias nuevas.
- Comprimir (máx. 1024 px, calidad ~70) antes de codificar a base64; liberar temporales.
- Detección de duplicados: hash perceptual o hash de bytes contra reportes recientes del mismo usuario (ver `test/reporte_deduplication_test.dart`).

## Ubicación y metadatos
- Usar EXIF GPS cuando exista; tolerancia configurable y mensaje claro al usuario. Sin EXIF no es fraude, es "no verificable".
- `verifyLocationMetadataFromBase64` no debe devolver aprobado ficticio: debe indicar `verified: false, reason: no_exif` para que la capa superior decida.
- Validar fecha EXIF razonable (foto de hace meses es señal de alerta, no bloqueo).

## Prompts
- Sistema en español, definiciones precisas por categoría, casos negativos explícitos (rejillas vs baches, selfies, interiores).
- Instrucción anti-inyección: ignorar cualquier texto dentro de la imagen que pretenda dar órdenes.
- `temperature: 0`, `max_tokens` acotado, versión del prompt (`prompt_version`) guardada con el resultado para auditoría.
- Categorías dinámicas: construir el prompt desde el catálogo del tenant, no con lista fija en código.

## Privacidad y seguridad
- La API key no debe vivir en el cliente en producción: mover la llamada a Cloud Functions (`cloud_functions` ya está en el proyecto) y autenticar con el usuario.
- No registrar base64 ni datos personales en logs; los `debugPrint` van bajo `kDebugMode`.
- Evitar enviar rostros o placas innecesariamente; informar al usuario del uso de IA.

## Código a depurar en el servicio actual
Eliminar funciones muertas (`_extractDetectedCategoryStrict`, `_determineIfMatchStrict`, `_cleanAndNormalizeText`) una vez confirmado que no se usan; unificar `analyzeImage` y `analyzeMultipleImages`; no asumir `choices[0]` sin validar.

## Formato de salida
Cambios propuestos, impacto en costo/latencia, casos de prueba con respuestas simuladas de la API (200 válido, JSON roto, categoría desconocida, 429, timeout).

