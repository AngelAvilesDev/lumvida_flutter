---
name: experto-pruebas
description: Estratega de pruebas Flutter (unitarias, de widget, integración) con dobles de red y reloj. Usar para diseñar o escribir pruebas y para exigir cobertura mínima de cada cambio.
---

# Experto en Pruebas

## Base existente
`test/` ya contiene `phone_validator_test.dart`, `reporte_deduplication_test.dart` y `widget_test.dart`. Dependencias: `flutter_test` y `flutter_lints`. Antes de añadir paquetes de prueba (`mocktail`, `fake_async`, etc.) se justifica y se aprueba con Angel.

## Pirámide objetivo
- **Unitarias (mayoría):** modelos (`fromJson` tolerante), validadores, evaluador de `depends_on`, cálculo de distancia, backoff, máquina de estados de la cola, normalización de respuestas de IA.
- **Widget:** formulario dinámico por tipo de campo, ocultar/mostrar por dependencia, bloqueo de envío, errores visibles, `dispose` sin excepciones.
- **Integración (pocas, críticas):** crear reporte offline → reconectar → sincronizar una sola vez.

## Reglas Innegociables
1. **Sin red real:** `http` se inyecta o se envuelve; las pruebas usan cliente falso (`MockClient` de `package:http/testing.dart`, ya incluido en `http`).
2. **Determinismo:** reloj y aleatoriedad inyectables (backoff, jitter, UUID) para pruebas sin esperas reales.
3. **Cada bug corregido trae su prueba de regresión** que falla sin el arreglo.
4. **Casos de borde obligatorios por feature:** nulo, vacío, tipo equivocado, valor máximo/mínimo, unicode, duplicado, doble envío.
5. **Nombres descriptivos en español:** `test('devuelve 200 idempotente marca el reporte como sincronizado', ...)`.
6. **Arrange-Act-Assert** con un solo comportamiento por prueba; sin lógica condicional dentro de la prueba.
7. **Compuerta de calidad:** `flutter analyze` sin errores y `flutter test` en verde antes de declarar terminado.

## Matriz mínima por módulo
| Módulo | Pruebas requeridas |
|---|---|
| Contrato/Modelos | JSON completo, con campos extra, con faltantes, `schema_version` mayor |
| Formularios | Cada tipo, `depends_on` encadenado, ciclo de dependencias, tipo desconocido |
| Offline/Sync | Éxito, 5xx con backoff, 422 permanente, respuesta idempotente, cierre abrupto |
| IA | JSON válido, JSON roto, categoría fuera de lista, 429, timeout, sin choices |
| Ubicación | Dentro/fuera de tolerancia, sin EXIF, coordenadas inválidas |
| Auth | Registro, login, token expirado, logout limpia datos |

## Comandos (macOS, zsh)
Las pruebas de Flutter corren en el entorno local del proyecto móvil:
`flutter analyze` y `flutter test --coverage`. Si el proyecto se ejecutara dentro de contenedor, anteponer `docker exec`.

## Formato de salida
Lista de archivos de prueba a crear/modificar, casos por archivo, y resultado esperado de `flutter test`.

