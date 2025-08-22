import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../components/base64_image_widget.dart';
import '../components/BottomNavigationWidget.dart';

class MisReportesScreen extends StatefulWidget {
  const MisReportesScreen({Key? key}) : super(key: key);

  @override
  State<MisReportesScreen> createState() => _MisReportesScreenState();
}

class _MisReportesScreenState extends State<MisReportesScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = false;
  String? _error;
  String _filtroActual = 'Todos';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _filtros = ['Todos', 'Pendientes', 'En Proceso', 'Resueltos'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);

    _cargarReportes();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
          'imagenes': data['imagenes'] ?? [],
          'historialEstados': data['historialEstados'] ?? [],
        };
      }).toList();

      setState(() {
        _reportes = reportes;
        _isLoading = false;
      });

      _fadeController.forward();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar reportes: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _reportesFiltrados {
    if (_filtroActual == 'Todos') {
      return _reportes;
    }

    return _reportes.where((reporte) {
      final estado = reporte['estado']?.toString().toLowerCase() ?? '';
      switch (_filtroActual) {
        case 'Pendientes':
          return estado == 'pendiente' || estado == 'nuevo';
        case 'En Proceso':
          return estado.contains('proceso') || estado == 'asignado' || estado.contains('revision');
        case 'Resueltos':
          return estado == 'resuelto' || estado == 'completado';
        default:
          return true;
      }
    }).toList();
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
      return _buildNotAuthenticatedView();
    }

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: .8),
                Colors.white.withValues(alpha: .95),
                kPrimaryColor.withValues(alpha: .03),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header moderno
                _buildModernHeader(),

                // Filtros
                if (_reportes.isNotEmpty) _buildFilterTabs(),

                // Contenido principal
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'inicio'),
    );
  }

  Widget _buildNotAuthenticatedView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Debes iniciar sesión para ver tus reportes',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón de regreso
          Container(
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryColor),
            ),
          ),

          const SizedBox(width: 16),

          // Título y estadísticas
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis Reportes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_reportesFiltrados.length} reportes encontrados',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Botón de refrescar
          Container(
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: kPrimaryColor),
              onPressed: _cargarReportes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filtros.map((filtro) {
            final isSelected = _filtroActual == filtro;
            final count = filtro == 'Todos' ? _reportes.length : _reportesFiltrados.length;

            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  '$filtro ${filtro == _filtroActual ? '($count)' : ''}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selectedColor: kPrimaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(color: kPrimaryColor.withValues(alpha: .3)),
                onSelected: (selected) {
                  setState(() {
                    _filtroActual = filtro;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: kPrimaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando tus reportes...',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
        ),
      );
    }

    if (_reportesFiltrados.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _filtroActual == 'Todos'
                    ? 'No tienes reportes aún'
                    : 'No hay reportes con filtro "$_filtroActual"',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea tu primer reporte desde la pantalla principal',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _cargarReportes,
        color: kPrimaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _reportesFiltrados.length,
          itemBuilder: (context, index) {
            final reporte = _reportesFiltrados[index];
            return _buildModernReportCard(context, reporte, index);
          },
        ),
      ),
    );
  }

  Widget _buildModernReportCard(BuildContext context, Map<String, dynamic> reporte, int index) {
    IconData getIconForType(String type) {
      if (type.toLowerCase().contains('basura') || type.toLowerCase().contains('recolección')) {
        return Icons.delete_outline;
      } else if (type.toLowerCase().contains('alumbrado')) {
        return Icons.lightbulb_outline;
      } else if (type.toLowerCase().contains('baches') || type.toLowerCase().contains('bacheo')) {
        return Icons.directions_car;
      } else if (type.toLowerCase().contains('alcantarillado') || type.toLowerCase().contains('drenajes')) {
        return Icons.water_drop;
      }
      return Icons.report_problem_outlined;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _mostrarDetalleReporte(context, reporte),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header del reporte
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                getIconForType(reporte['tipo'] ?? ''),
                                color: kPrimaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reporte['tipo'] ?? 'Sin categoría',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Folio: ${reporte['folio'] ?? 'Sin folio'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
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

                        const SizedBox(height: 12),

                        // Descripción
                        Text(
                          reporte['descripcion'] ?? 'Sin descripción',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Ubicación y fecha
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reporte['ubicacion'] ?? 'Sin ubicación',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              'Reportado el ${reporte['fecha'] ?? 'Fecha desconocida'}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),

                        // Imágenes preview
                        if (reporte['imagenes'] != null && (reporte['imagenes'] as List).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.image, size: 16, color: Colors.grey.shade500),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarDetalleReporte(BuildContext context, Map<String, dynamic> reporte) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: kPrimaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reporte #${reporte['folio'] ?? 'Sin folio'}',
                  style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
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

                _buildDetailRow('Fecha', reporte['fecha'] ?? 'Fecha desconocida'),
                _buildDetailRow('Estado', reporte['estado'] ?? 'Sin estado'),
                _buildDetailRow('Categoría', reporte['tipo'] ?? 'Sin categoría'),
                _buildDetailSection('Comentario', reporte['descripcion'] ?? 'Sin descripción'),
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