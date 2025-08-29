import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PARA COPIAR FOLIO
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/components/base64_image_widget.dart';
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
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
  bool _showFilters = false; // NUEVO: CONTROLAR VISIBILIDAD DE FILTROS

  late AnimationController _fadeController;
  late AnimationController _filterController; // NUEVA ANIMACIÓN PARA FILTROS
  late Animation<double> _fadeAnimation;
  late Animation<double> _filterAnimation;

  // Estados actualizados con sus colores correspondientes
  final List<Map<String, dynamic>> _filtros = [
    {'nombre': 'Todos', 'color': Colors.grey.shade600},
    {'nombre': 'Pendiente', 'color': Colors.grey.shade600},
    {'nombre': 'En Revisión', 'color': Colors.orange.shade600},
    {'nombre': 'Asignado', 'color': Colors.blue.shade600},
    {'nombre': 'En Proceso', 'color': Colors.yellow.shade700},
    {'nombre': 'Resuelto', 'color': Colors.green.shade600},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _filterController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _filterAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_filterController);

    _cargarReportes();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  // TOGGLE PARA MOSTRAR/OCULTAR FILTROS
  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });

    if (_showFilters) {
      _filterController.forward();
    } else {
      _filterController.reverse();
    }
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
      final estado = _normalizeEstado(reporte['estado']?.toString() ?? '');
      final filtroNormalizado = _normalizeEstado(_filtroActual);
      return estado == filtroNormalizado;
    }).toList();
  }

  // Normalizar estados para comparación
  String _normalizeEstado(String estado) {
    switch (estado.toLowerCase().trim()) {
      case 'pendiente':
      case 'nuevo':
        return 'pendiente';
      case 'en revision':
      case 'en revisión':
      case 'revision':
        return 'en revisión';
      case 'asignado':
        return 'asignado';
      case 'en proceso':
      case 'proceso':
        return 'en proceso';
      case 'resuelto':
      case 'completado':
      case 'terminado':
        return 'resuelto';
      default:
        return estado.toLowerCase();
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

                // Filtros compactos - SIMPLIFICADO
                if (_reportes.isNotEmpty) _buildCompactFilters(),

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

          // Botón de filtros
          Container(
            decoration: BoxDecoration(
              color: _showFilters
                  ? kPrimaryColor
                  : kPrimaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: AnimatedRotation(
                turns: _showFilters ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.filter_list,
                  color: _showFilters ? Colors.white : kPrimaryColor,
                ),
              ),
              onPressed: _toggleFilters,
            ),
          ),

          const SizedBox(width: 8),

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

  // FILTROS COMPACTOS - NUEVO DISEÑO
  Widget _buildCompactFilters() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showFilters ? 70 : 0,
      child: ClipRect(
        child: FadeTransition(
          opacity: _filterAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filtros.map((filtro) {
                  final isSelected = _filtroActual == filtro['nombre'];
                  final count = filtro['nombre'] == 'Todos'
                      ? _reportes.length
                      : _getCountForFilter(filtro['nombre']);

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        '${filtro['nombre']} ($count)',
                        style: TextStyle(
                          color: isSelected ? Colors.white : filtro['color'],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      selectedColor: filtro['color'],
                      backgroundColor: Colors.white,
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: filtro['color'].withOpacity(0.3),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _filtroActual = filtro['nombre'];
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _getCountForFilter(String filtro) {
    if (filtro == 'Todos') return _reportes.length;

    return _reportes.where((reporte) {
      final estado = _normalizeEstado(reporte['estado']?.toString() ?? '');
      final filtroNormalizado = _normalizeEstado(filtro);
      return estado == filtroNormalizado;
    }).length;
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
                    : 'No hay reportes con estado "$_filtroActual"',
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
      } else if (type.toLowerCase().contains('alcantarillado') || type.toLowerCase().contains('drenaje')) {
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
                // Borde izquierdo con color del estado
                border: Border(
                  left: BorderSide(
                    color: _getColorPorEstado(reporte['estado'] ?? ''),
                    width: 4,
                  ),
                ),
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
                        // Header del reporte con botón de copiar folio
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
                                  // FOLIO CLICKEABLE PARA COPIAR
                                  GestureDetector(
                                    onTap: () => _copyFolio(reporte['folio'] ?? 'Sin folio'),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Folio: ${reporte['folio'] ?? 'Sin folio'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getColorPorEstado(reporte['estado'] ?? ''),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getEstadoDisplayText(reporte['estado'] ?? '').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
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

  // FUNCIÓN PARA COPIAR FOLIO
  void _copyFolio(String folio) {
    Clipboard.setData(ClipboardData(text: folio));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.copy, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Folio $folio copiado'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
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
              // BOTÓN DE COPIAR EN EL MODAL TAMBIÉN
              IconButton(
                onPressed: () => _copyFolio(reporte['folio'] ?? 'Sin folio'),
                icon: const Icon(Icons.copy, color: kPrimaryColor, size: 20),
                tooltip: 'Copiar folio',
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Estado prominente
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _getColorPorEstado(reporte['estado'] ?? ''),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.circle, color: Colors.white, size: 8),
                      const SizedBox(width: 8),
                      Text(
                        'ESTADO: ${_getEstadoDisplayText(reporte['estado'] ?? '').toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

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

  // Obtener texto de display para el estado
  String _getEstadoDisplayText(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return 'Pendiente';
      case 'en revisión':
        return 'En Revisión';
      case 'asignado':
        return 'Asignado';
      case 'en proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      default:
        return estado;
    }
  }

  // Actualizar colores según los estados especificados
  Color _getColorPorEstado(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return Colors.grey.shade600; // Gris para Pendiente
      case 'en revisión':
        return Colors.orange.shade600; // Naranja para En Revisión
      case 'asignado':
        return Colors.blue.shade600; // Azul para Asignado
      case 'en proceso':
        return Colors.yellow.shade700; // Amarillo para En Proceso
      case 'resuelto':
        return Colors.green.shade600; // Verde para Resuelto
      default:
        return Colors.grey.shade600; // Gris por defecto
    }
  }
}