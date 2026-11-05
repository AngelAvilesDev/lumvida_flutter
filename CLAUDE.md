# Lumvida Flutter (Móvil)

Aplicación móvil municipal para reporte de incidencias urbanas construida en Flutter (iOS y Android).

## Documentación de Referencia Obligatoria
Antes de modificar modelos, lógica de sincronización o pantallas de captura, es obligatorio consultar:
- `docs/CONTRATO_REPORTES_DINAMICOS.md`

## Agentes del Proyecto
| Agente | Enfoque |
|---|---|
| `experto-contrato-api` | Valida compatibilidad y consistencia de payloads con el backend |
| `experto-formularios-dinamicos` | Implementa y refina el motor Server-Driven UI en Flutter |
| `experto-offline-sync` | Gestiona el almacenamiento local (SQLite/Hive), colas y reintentos idempotentes |
| `revisor-adversarial` | Ataca y audita código antes de autorizar cambios |
| `experto-verificacion-ia` | Robustece el agente Lumi (OpenAI): parseo, reintentos, costo, fraude |
| `experto-seguridad` | Secretos, auth, reglas Firebase, privacidad y permisos |
| `experto-pruebas` | Estrategia y cobertura de pruebas unitarias, widget e integración |

## Convenciones de Desarrollo
- **Entorno:** macOS (zsh).
- **Control de versiones:** Convención Conventional Commits en español (`feat: ...`, `fix: ...`). **PROHIBIDO auto-commit** sin autorización explícita de Angel.
- **Comentarios:** Exclusivamente una línea: `// (lo que se hace)`. Prohibidos bloques largos o docstrings no solicitados.
- **Arquitectura:** Offline-first. Todo reporte nace con `client_report_uuid`.

