# Contrato Técnico: Reportes Dinámicos y Multi-Tenant (Lumvida)

Este documento define el contrato de datos inmutable entre el backend (API REST), el panel de administración web (`lumvida_web`) y la aplicación móvil (`lumvida_flutter`).

---

## 1. Configuración de Tenant y Catálogo de Reportes

- **Endpoint:** `GET /api/v1/tenant/config`
- **Headers:**
  - `Authorization: Bearer <token>` (opcional si es catálogo público de captura ciudadana)
  - `If-None-Match: <hash_version>` o parámetro `?current_schema_version=<int>`
- **Códigos de respuesta:**
  - `200 OK`: Devuelve el esquema completo y actualiza caché local.
  - `304 Not Modified`: El cliente mantiene su caché local; no se transfieren datos de catálogo.

### Estructura de Respuesta (`200 OK`)

```json
{
  "tenant": {
    "id": "mun_san_pedro",
    "name": "Municipio de San Pedro",
    "slug": "san-pedro",
    "schema_version": 4,
    "updated_at": "2026-11-05T10:00:00Z",
    "branding": {
      "primary_color": "#1E3A8A",
      "secondary_color": "#0D9488",
      "accent_color": "#F59E0B",
      "background_color": "#F8FAFC",
      "logo_url": "https://api.lumvida.gob.mx/storage/san-pedro/branding/logo.png",
      "coat_of_arms_url": "https://api.lumvida.gob.mx/storage/san-pedro/branding/escudo.png"
    }
  },
  "categories": [
    {
      "id": "cat_alumbrado",
      "name": "Servicios Públicos",
      "slug": "servicios-publicos",
      "icon": "lightbulb",
      "sort_order": 1,
      "is_active": true,
      "max_visible_reports": 5,
      "report_types": [
        {
          "id": "rep_luminaria_fundida",
          "name": "Luminaria apagada / descompuesta",
          "slug": "luminaria-apagada",
          "description": "Reporte de fallas en alumbrado público de calles y parques",
          "icon": "bolt-slash",
          "sort_order": 1,
          "is_active": true,
          "requires_location": true,
          "requires_evidence": true,
          "form_schema": [
            {
              "key": "poste_id",
              "label": "Número o código visible en el poste",
              "type": "text",
              "placeholder": "Ej. LP-450",
              "help_text": "Se encuentra grabado en una placa metálica en el poste",
              "validation": {
                "required": false,
                "max_length": 30
              }
            },
            {
              "key": "tipo_luminaria",
              "label": "¿Qué tipo de luminaria es?",
              "type": "select",
              "options": [
                { "value": "led", "label": "Lámpara LED" },
                { "value": "vapor_sodio", "label": "Vapor de Sodio (Amarilla)" },
                { "value": "desconocido", "label": "No lo sé" }
              ],
              "validation": {
                "required": true
              }
            },
            {
              "key": "afectacion_inseguridad",
              "label": "¿La falta de luz genera un punto de riesgo inmediato?",
              "type": "boolean",
              "default_value": false,
              "validation": {
                "required": true
              }
            },
            {
              "key": "solicita_patrullaje",
              "label": "¿Requiere presencia de seguridad pública preventiva?",
              "type": "boolean",
              "default_value": false,
              "depends_on": {
                "field_key": "afectacion_inseguridad",
                "operator": "equals",
                "value": true
              },
              "validation": {
                "required": false
              }
            },
            {
              "key": "detalles_adicionales",
              "label": "Descripción del problema",
              "type": "textarea",
              "placeholder": "Indica si parpadea, está rota o no enciende",
              "validation": {
                "required": false,
                "max_length": 500
              }
            },
            {
              "key": "fotos_evidencia",
              "label": "Fotografías del reporte",
              "type": "file",
              "validation": {
                "required": true,
                "min_files": 1,
                "max_files": 3,
                "allowed_mimes": ["image/jpeg", "image/png", "image/webp"],
                "max_file_size_mb": 10
              }
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 2. Almacenamiento Modular de Archivos (`STORAGE_DRIVER`)

Los clientes nunca se comunican con sistemas de archivos, discos locales o buckets S3 de forma directa. Toda carga de evidencias se realiza a través del backend.

- **Endpoint:** `POST /api/v1/storage/upload`
- **Headers:**
  - `Authorization: Bearer <token>`
  - `Content-Type: multipart/form-data`
- **Payload multipart:**
  - `tenant_id` (string): Identificador del municipio.
  - `context` (string): `report_evidence` | `branding` | `user_avatar`.
  - `file` (binary): Archivo a subir.

### Estructura de Respuesta (`201 Created`)

```json
{
  "file_path": "temp_uploads/san-pedro/2026/11/rep_01_a8f9.jpg",
  "public_url": "https://api.lumvida.gob.mx/storage/san-pedro/2026/11/rep_01_a8f9.jpg",
  "mime_type": "image/jpeg",
  "size_bytes": 2458900,
  "driver": "local",
  "created_at": "2026-11-05T10:43:10Z"
}
```

---

## 3. Envío e Idempotencia de Reportes

- **Endpoint:** `POST /api/v1/reports`
- **Headers:**
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`

### Estructura de Solicitud (`POST`)

```json
{
  "client_report_uuid": "e8b2b9c4-1234-4567-89ab-cdef01234567",
  "tenant_id": "mun_san_pedro",
  "category_id": "cat_alumbrado",
  "report_type_id": "rep_luminaria_fundida",
  "schema_version": 4,
  "client_metadata": {
    "offline_created_at": "2026-11-05T09:15:22Z",
    "synced_at": "2026-11-05T10:44:00Z",
    "device_platform": "android",
    "app_version": "1.0.0+1"
  },
  "location": {
    "latitude": 25.6667,
    "longitude": -100.3167,
    "accuracy_meters": 4.5,
    "address_reference": "Esquina con Av. Hidalgo, frente a tienda"
  },
  "form_data": {
    "poste_id": "LP-450",
    "tipo_luminaria": "led",
    "afectacion_inseguridad": true,
    "solicita_patrullaje": true,
    "detalles_adicionales": "La lámpara se cayó tras tormenta",
    "fotos_evidencia": [
      "temp_uploads/san-pedro/2026/11/rep_01_a8f9.jpg"
    ]
  }
}
```

### Reglas de Negocio en Backend
1. **Idempotencia:** La tabla `reports` debe tener restricción única `UNIQUE KEY unique_tenant_client_report (tenant_id, client_report_uuid)`.
2. **Reintentos offline:** Si llega un `client_report_uuid` existente, el backend responde `200 OK` con el reporte ya persistido (sin duplicar ni emitir error 500).
3. **Validación Espejo:** Cada clave dentro de `form_data` se valida contra las reglas del `form_schema` del tipo de reporte (`required`, `min_length`, `max_length`, `in`, `mimes`, etc.).

