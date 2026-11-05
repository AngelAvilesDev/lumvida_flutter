// Pantalla para captura y despacho de reportes basada en esquemas dinámicos

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../shared/models/dynamic_schema/tenant_config_model.dart';
import '../../shared/models/dynamic_schema/dynamic_report_payload.dart';
import '../../shared/services/dynamic_report_service.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../../shared/widgets/dynamic_form_widget.dart';
import 'LocationSelectionScreen.dart';

class DynamicReportScreen extends StatefulWidget {
  final String tenantId;
  final int schemaVersion;
  final CategorySchema category;
  final ReportTypeSchema reportType;

  const DynamicReportScreen({
    Key? key,
    required this.tenantId,
    required this.schemaVersion,
    required this.category,
    required this.reportType,
  }) : super(key: key);

  @override
  State<DynamicReportScreen> createState() => _DynamicReportScreenState();
}

class _DynamicReportScreenState extends State<DynamicReportScreen> {
  final DynamicReportService _reportService = DynamicReportService();

  LatLng? _selectedLocation;
  String _addressText = 'Toca para seleccionar ubicación exacta';
  Map<String, dynamic> _formData = {};
  bool _isFormValid = false;
  bool _isSubmitting = false;

  // Manejar cambios en el formulario dinámico
  void _onFormChanged(Map<String, dynamic> values, bool isValid) {
    setState(() {
      _formData = values;
      _isFormValid = isValid;
    });
  }

  // Obtener ubicación inicial del dispositivo si no está seleccionada
  Future<LatLng> _getEffectiveInitialLocation() async {
    if (_selectedLocation != null) return _selectedLocation!;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return const LatLng(25.6866, -100.3161);
    }
  }

  // Navegar a la pantalla de selección de ubicación en Google Maps
  Future<void> _selectLocationOnMap() async {
    final initialPos = await _getEffectiveInitialLocation();

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSelectionScreen(initialLocation: initialPos),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _selectedLocation = result;
        _addressText = 'Lat: ${result.latitude.toStringAsFixed(5)}, Lng: ${result.longitude.toStringAsFixed(5)}';
      });
    }
  }

  // Enviar reporte al backend o guardar en cola local
  Future<void> _submitReport() async {
    if (widget.reportType.requiresLocation && _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona la ubicación en el mapa')),
      );
      return;
    }

    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos requeridos')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final authToken = authViewModel.user?.uid;

      // Extraer archivos locales del form_data si existen
      final List<File> localFiles = [];
      for (final entry in _formData.entries) {
        if (entry.value is List) {
          for (final item in entry.value) {
            if (item is String && File(item).existsSync()) {
              localFiles.add(File(item));
            }
          }
        }
      }

      final location = ReportLocation(
        latitude: _selectedLocation?.latitude ?? 0.0,
        longitude: _selectedLocation?.longitude ?? 0.0,
        addressReference: _addressText,
      );

      final success = await _reportService.submitReport(
        tenantId: widget.tenantId,
        categoryId: widget.category.id,
        reportTypeId: widget.reportType.id,
        schemaVersion: widget.schemaVersion,
        location: location,
        rawFormData: _formData,
        localEvidenceFiles: localFiles,
        authToken: authToken,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        _showSuccessDialog('Reporte Enviado', 'Tu reporte ha sido recibido y registrado en el sistema municipal.');
      } else {
        _showSuccessDialog('Modo Fuera de Línea', 'Sin conexión a internet. Tu reporte fue guardado y se enviará automáticamente al recuperar señal.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar reporte: $e')),
      );
    }
  }

  // Mostrar diálogo de confirmación tras envío o encolado
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportType.name),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con información del tipo de reporte
                Text(
                  widget.reportType.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (widget.reportType.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.reportType.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 20),

                // Selector de ubicación GPS
                if (widget.reportType.requiresLocation) ...[
                  const Text(
                    'Ubicación del Reporte *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectLocationOnMap,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: _selectedLocation != null ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _addressText,
                              style: TextStyle(
                                color: _selectedLocation != null ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Formulario dinámico Server-Driven UI
                DynamicFormWidget(
                  fields: widget.reportType.formSchema,
                  onChanged: _onFormChanged,
                ),
                const SizedBox(height: 24),

                // Botón de despacho del reporte
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || !_isFormValid ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Enviar Reporte',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Indicador visual de carga durante el despacho
          if (_isSubmitting)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
