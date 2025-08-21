import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../components/base64_image_widget.dart'; // Importar el nuevo widget
import '../components/BottomNavigationWidget.dart'; // Importar el nuevo componente

class MisReportesScreen extends StatefulWidget {
  const MisReportesScreen({Key? key}) : super(key: key);

  @override
  State<MisReportesScreen> createState() => _MisReportesScreenState();
}

class _MisReportesScreenState extends State<MisReportesScreen> {
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (!authViewModel.isAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: authViewModel.user!.uid)
          .orderBy('fecha', descending: true)
          .get();

      final reportes = reportesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'folio': data['folio'] ?? 'Sin folio',
          'fecha': _formatearFecha(data['fecha']),
          'estado': data['estado'] ?? 'pendiente',
          'tipo': data['categoria'] ?? 'Sin categoría',
          'descripcion': data['comentario'] ?? 'Sin descripción',
          'ubicacion': data['direccion'] ?? 'Sin ubicación',
          'nombreCompleto': data['nombreCompleto'] ?? '',
          'telefono': data['telefono'] ?? '',
          'isAnonymous': data['isAnonymous'] ?? false,
          'imagenes': data['imagenes'] ?? [], // Ahora son Base64
          'historialEstados': data['historialEstados'] ?? [],
        };
      }).toList();

      setState(() {
        _reportes = reportes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar reportes: $e';
        _isLoading = false;
      });
    }
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';

    try {
      if (timestamp is Timestamp) {
        final fecha = timestamp.toDate();
        return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      }
      return 'Fecha desconocida';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    if (!authViewModel.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mis Reportes', style: TextStyle(color: kPrimaryColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: kPrimaryColor),
        ),
        body: Container(
          decoration: backgroundDecoration,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Debes iniciar sesión para ver tus reportes',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarReportes,
          ),
        ],
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: _buildMainContent(),
      ),
      bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'inicio'), // Cambiado para usar el componente común
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kPrimaryColor),
            SizedBox(height: 16),
            Text('Cargando tus reportes...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarReportes,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_reportes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tienes reportes aún',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 8),
            Text(
              'Crea tu primer reporte desde la pantalla principal',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarReportes,
      color: kPrimaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportes.length,
        itemBuilder: (context, index) {
          final reporte = _reportes[index];
          return _buildReportCard(context, reporte);
        },
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> reporte) {
    IconData getIconForType(String type) {
      if (type.toLowerCase().contains('basura') || type.toLowerCase().contains('recolección')) {
        return Icons.delete_outline;
      } else if (type.toLowerCase().contains('alumbrado')) {
        return Icons.lightbulb_outline;
      } else if (type.toLowerCase().contains('baches') || type.toLowerCase().contains('bacheo')) {
        return Icons.car_repair;
      } else if (type.toLowerCase().contains('alcantarillado') || type.toLowerCase().contains('drenajes')) {
        return Icons.water_drop;
      }
      return Icons.report_problem_outlined;
    }

    // Crear historial simplificado basado en el estado actual
    List<Map<String, dynamic>> historialEstados = [
      {
        'estado': 'Reporte recibido',
        'fecha': reporte['fecha'],
        'hora': '09:00'
      }
    ];

    String estadoLower = reporte['estado']?.toString().toLowerCase() ?? '';
    if (estadoLower.contains('proceso') || estadoLower == 'asignado') {
      historialEstados.add({
        'estado': 'Asignado al departamento correspondiente',
        'fecha': reporte['fecha'],
        'hora': '10:30'
      });
    } else if (estadoLower == 'resuelto' || estadoLower == 'completado') {
      historialEstados.add({
        'estado': 'Asignado al departamento correspondiente',
        'fecha': reporte['fecha'],
        'hora': '10:30'
      });
      historialEstados.add({
        'estado': 'Problema solucionado',
        'fecha': reporte['fecha'],
        'hora': '14:45'
      });
    }

    return GestureDetector(
      onTap: () => _mostrarDetalleReporte(context, reporte),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con icono y título
              Row(
                children: [
                  Icon(
                    getIconForType(reporte['tipo'] ?? ''),
                    color: kPrimaryColor,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reporte['tipo'] ?? 'Sin categoría',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getColorPorEstado(reporte['estado'] ?? ''),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (reporte['estado'] ?? 'PENDIENTE').toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Número de folio
              Text(
                'Folio: ${reporte['folio'] ?? 'Sin folio'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),

              // Descripción
              Text(
                reporte['descripcion'] ?? 'Sin descripción',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Ubicación
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reporte['ubicacion'] ?? 'Sin ubicación',
                      style: TextStyle(color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Fecha
              Text(
                'Reportado el ${reporte['fecha'] ?? 'Fecha desconocida'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),

              // Mostrar preview de imágenes si existen
              if (reporte['imagenes'] != null && (reporte['imagenes'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.image, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${(reporte['imagenes'] as List).length} imagen(es)',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ReportImageGallery(
                    base64Images: List<String>.from(reporte['imagenes']),
                    imageSize: 60,
                    onImageTap: (index, base64) {
                      FullScreenImageModal.show(
                        context,
                        base64,
                        title: 'Imagen ${index + 1} - ${reporte['folio']}',
                      );
                    },
                  ),
                ),
              ],

              const Divider(height: 24),

              // Seguimiento de estados
              const Text(
                'Seguimiento del reporte',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Estados del reporte
              ...List.generate(historialEstados.length, (index) {
                final estado = historialEstados[index];
                String estadoTexto = estado['estado'] ?? 'Estado desconocido';
                String fechaHora = '${estado['fecha'] ?? reporte['fecha']} • ${estado['hora'] ?? '00:00'}';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estadoTexto,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              fechaHora,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return const BottomNavigationWidget(currentScreen: 'inicio'); // Usar el componente común
  }

  void _mostrarDetalleReporte(BuildContext context, Map<String, dynamic> reporte) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reporte #${reporte['folio'] ?? 'Sin folio'}',
              style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostrar galería de imágenes si existen
                if (reporte['imagenes'] != null && (reporte['imagenes'] as List).isNotEmpty) ...[
                  const Text(
                    'Imágenes del reporte:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ReportImageGallery(
                      base64Images: List<String>.from(reporte['imagenes']),
                      imageSize: 120,
                      onImageTap: (index, base64) {
                        FullScreenImageModal.show(
                          context,
                          base64,
                          title: 'Imagen ${index + 1} - ${reporte['folio']}',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Fecha y estado
                _buildDetailRow('Fecha', reporte['fecha'] ?? 'Fecha desconocida'),
                _buildDetailRow('Estado', reporte['estado'] ?? 'Sin estado'),

                // Categoría y descripción
                _buildDetailRow('Categoría', reporte['tipo'] ?? 'Sin categoría'),
                _buildDetailSection('Comentario', reporte['descripcion'] ?? 'Sin descripción'),

                // Ubicación
                _buildDetailSection('Ubicación', reporte['ubicacion'] ?? 'Sin ubicación'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: kPrimaryColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getColorPorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
      case 'nuevo':
        return Colors.grey;
      case 'en revision':
      case 'en revisión':
        return Colors.orange;
      case 'asignado':
        return Colors.blue;
      case 'en proceso':
        return Colors.yellow.shade700;
      case 'resuelto':
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}