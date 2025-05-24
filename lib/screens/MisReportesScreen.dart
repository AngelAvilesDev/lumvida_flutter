import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';

class MisReportesScreen extends StatefulWidget {
  const MisReportesScreen({Key? key}) : super(key: key);

  @override
  State<MisReportesScreen> createState() => _MisReportesScreenState();
}

class _MisReportesScreenState extends State<MisReportesScreen> {
  String _filtroActual = 'Todos';
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _reportes = [];

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (!authViewModel.isAuthenticated) {
      setState(() {
        _isLoading = false;
        _error = 'Usuario no autenticado';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = authViewModel.user!.uid;

      // Obtener reportes del usuario desde Firestore
      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: userId)
          .orderBy('fecha', descending: true)
          .get();

      if (reportesSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _reportes = [];
        });
        return;
      }

      // Transformar los documentos en una lista de mapas
      final reportes = reportesSnapshot.docs.map((doc) {
        final data = doc.data();
        // Asegurar que todas las propiedades necesarias estén disponibles
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
          // Otros campos que puedan ser necesarios
          'historialEstados': data['historialEstados'] ?? [],
        };
      }).toList();

      setState(() {
        _reportes = reportes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar reportes: $e';
      });
    }
  }

  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';

    try {
      if (timestamp is Timestamp) {
        final fecha = timestamp.toDate();
        return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      } else {
        return 'Fecha desconocida';
      }
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  List<Map<String, dynamic>> _filtrarReportes() {
    if (_filtroActual == 'Todos') {
      return _reportes;
    } else {
      // Convertir el filtro actual a un formato estándar para comparación
      String filtro = _filtroActual.toLowerCase();
      // Corregir los nombres de filtro para que coincidan con los estados reales
      if (filtro == 'pendientes') filtro = 'pendiente';
      else if (filtro == 'resueltos') filtro = 'resuelto';
      else if (filtro == 'en proceso') filtro = 'en proceso';

      return _reportes.where((reporte) =>
      reporte['estado'].toLowerCase() == filtro
      ).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final reportesFiltrados = _filtrarReportes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: Column(
          children: [
            // Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todos', _filtroActual == 'Todos'),
                    _buildFilterChip('Pendientes', _filtroActual == 'Pendientes'),
                    _buildFilterChip('En proceso', _filtroActual == 'En proceso'),
                    _buildFilterChip('Resueltos', _filtroActual == 'Resueltos'),
                  ],
                ),
              ),
            ),

            // Contenido principal
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              )
                  : _error != null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _cargarReportes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
                  : reportesFiltrados.isEmpty
                  ? const Center(
                child: Text(
                  'No tienes reportes en esta categoría',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _cargarReportes,
                color: kPrimaryColor,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reportesFiltrados.length,
                  itemBuilder: (context, index) {
                    final reporte = reportesFiltrados[index];
                    return _buildReportCard(
                      context: context,
                      reporte: reporte,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Expanded(
              child: Center(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.location_on, color: Colors.white, size: 28),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.white, size: 28),
                    onPressed: () => _mostrarDialogoCerrarSesion(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtroActual = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required Map<String, dynamic> reporte,
  }) {
    IconData getIconForType(String type) {
      if (type.toLowerCase().contains('basura') || type.toLowerCase().contains('recolección')) {
        return Icons.delete_outline;
      } else if (type.toLowerCase().contains('alumbrado')) {
        return Icons.lightbulb_outline;
      } else if (type.toLowerCase().contains('baches')) {
        return Icons.car_repair;
      } else if (type.toLowerCase().contains('alcantarillado')) {
        return Icons.water_drop;
      }
      return Icons.report_problem_outlined;
    }

    // Simplificar para mostrar solo el estado actual como historial
    List<dynamic> historialEstados = [
      {
        'estado': 'Reporte recibido',
        'fecha': reporte['fecha'],
        'hora': '09:00'
      }
    ];

    // Si está en proceso o resuelto, mostrar estados adicionales
    if (reporte['estado'].toLowerCase() == 'en proceso') {
      historialEstados.add({
        'estado': 'Asignado al departamento correspondiente',
        'fecha': reporte['fecha'],
        'hora': '10:30'
      });
    } else if (reporte['estado'].toLowerCase() == 'resuelto') {
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
                    getIconForType(reporte['tipo']),
                    color: kPrimaryColor,
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reporte['tipo'],
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
                      color: _getColorPorEstado(reporte['estado']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      reporte['estado'].toUpperCase(),
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
                'Folio: ${reporte['folio']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),

              // Descripción
              Text(
                reporte['descripcion'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),

              // Ubicación
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reporte['ubicacion'],
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
                'Reportado el ${reporte['fecha']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),

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
                String estadoTexto = estado is Map ? estado['estado'] ?? 'Estado desconocido' : 'Estado desconocido';
                String fechaHora = estado is Map
                    ? '${estado['fecha'] ?? reporte['fecha']} • ${estado['hora'] ?? '00:00'}'
                    : '${reporte['fecha']} • 00:00';

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
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
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

  void _mostrarDetalleReporte(BuildContext context, Map<String, dynamic> reporte) {
    // Verificar si el reporte tiene una imagen en base64
    Widget? imagenWidget;
    if (reporte['foto'] != null && reporte['foto'].toString().isNotEmpty) {
      try {
        final imageBytes = base64Decode(reporte['foto']);
        imagenWidget = Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
        );
      } catch (e) {
        print("Error decodificando imagen: $e");
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reporte #${reporte['folio']}',
              style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mostrar imagen si existe
                if (imagenWidget != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imagenWidget,
                  ),
                  const SizedBox(height: 16),
                ],

                // Fecha y estado
                _buildDetailRow('Fecha', reporte['fecha']),
                _buildDetailRow('Estado', reporte['estado']),

                // Categoría y descripción
                _buildDetailRow('Categoría', reporte['tipo']),
                _buildDetailSection('Comentario', reporte['descripcion']),

                // Ubicación
                _buildDetailSection('Ubicación', reporte['ubicacion']),

                // Datos del denunciante (si no es anónimo)
                if (!reporte['isAnonymous'] && reporte['nombreCompleto'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  _buildDetailRow('Reportado por', reporte['nombreCompleto']),
                  if (reporte['telefono'].isNotEmpty)
                    _buildDetailRow('Teléfono', reporte['telefono']),
                ],
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

// Métodos auxiliares para construir la vista de detalles
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
        return Colors.orange;
      case 'en proceso':
        return Colors.blue;
      case 'resuelto':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _mostrarDialogoCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión', style: TextStyle(color: kPrimaryColor)),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                // Cerrar sesión
                final authViewModel = Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                );
                authViewModel.signOut();

                // Cerrar todos los diálogos y navegar a la pantalla inicial
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}