import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../viewmodels/NotificacionesViewModel.dart';
import '../../shared/components/base64_image_widget.dart';
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../components/BottomNavigationWidget.dart';

class MisReportesScreen extends StatefulWidget {
  final String? folioInicial;
  const MisReportesScreen({Key? key, this.folioInicial}) : super(key: key);

  @override
  State<MisReportesScreen> createState() => _MisReportesScreenState();
}

class _MisReportesScreenState extends State<MisReportesScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _reportes = [];
  StreamSubscription? _reportesSubscription;
  bool _isLoading = false;
  bool _abiertoInicial = false;
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

    _escucharReportes();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _filterController.dispose();
    _reportesSubscription?.cancel();
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

  void _escucharReportes() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (!authViewModel.isAuthenticated) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _reportesSubscription?.cancel();
      _reportesSubscription = FirebaseFirestore.instance
          .collection('reportes')
          .where('userId', isEqualTo: authViewModel.user!.uid)
          .orderBy('fecha', descending: true)
          .snapshots()
          .listen((snapshot) {
        
        if (!mounted) return;
        final notifViewModel = Provider.of<NotificacionesViewModel>(context, listen: false);

        final reportes = snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            final id = doc.id;
            final folio = data['folio'] ?? 'Sin folio';
            final estado = data['estado'] ?? 'pendiente';

            return {
              'id': id,
              'folio': folio,
              'fecha': _formatearFecha(data['fecha']),
              'estado': estado,
              'tipo': data['categoria'] ?? 'Sin categoría',
              'descripcion': data['comentario'] ?? 'Sin descripción',
              'ubicacion': data['direccion'] ?? 'Sin ubicación',
              'direccion': data['direccion'] ?? '',
              'nombreCompleto': data['nombreCompleto'] ?? '',
              'telefono': data['telefono'] ?? '',
              'isAnonymous': data['isAnonymous'] ?? false,
              'imagenes': data['imagenes'] ?? [],
              'historialEstados': data['historialEstados'] ?? [],
              // Campos para reportes co-reportados (duplicados)
              'esDuplicado': data['esDuplicado'] ?? false,
              'reporteOriginalId': data['reporteOriginalId'],
              'contadorDuplicados': data['contadorDuplicados'] ?? 1,
            };
          } catch (e) {
            if (kDebugMode) print("Error parsing report ${doc.id}: $e");
            return null;
          }
        }).where((element) => element != null).cast<Map<String, dynamic>>().toList();

        if (mounted) {
          setState(() {
            _reportes = reportes;
            _isLoading = false;
          });
          _fadeController.forward();

          if (widget.folioInicial != null && !_abiertoInicial) {
            _abiertoInicial = true;
            final reporte = _reportes.firstWhere(
              (r) => r['folio'] == widget.folioInicial,
              orElse: () => {},
            );
            if (reporte.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mostrarDetalleReporte(context, reporte);
              });
            }
          }
        }
      }, onError: (e) {
        if (mounted) {
          setState(() {
            _error = 'Error al cargar reportes: $e';
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar reportes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refrescarReportes() async {
    _escucharReportes();
    await Future.delayed(const Duration(seconds: 1));
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
      case 'en_proceso':
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Botón de regreso
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFFFF0F3), // Fondo rosado suave
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF880E4F), size: 20), // Color vino
                ),
              ),

              Row(
                children: [
                  // Botón de filtros
                  Container(
                    decoration: BoxDecoration(
                      color: _showFilters ? Color(0xFF880E4F) : Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: _showFilters ? Colors.white : Color(0xFF880E4F),
                      ),
                      onPressed: _toggleFilters,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Botón de refrescar
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF880E4F)),
                      onPressed: _refrescarReportes,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Título Grande izquierda
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis\nReportes',
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF880E4F), // Color vino fuerte
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_reportesFiltrados.length} reportes encontrados',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
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
                onPressed: _refrescarReportes,
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
        onRefresh: _refrescarReportes,
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
    // Si es un reporte duplicado, mostrar card especial sin datos del autor original
    if (reporte['esDuplicado'] == true) {
      return _buildDuplicadoCard(context, reporte, index);
    }

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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _mostrarDetalleReporte(context, reporte),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header del card: Icono + Título + Status Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icono con fondo rosado suave
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFF0F3), // Mismo tono que los botones de arriba
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                getIconForType(reporte['tipo'] ?? ''),
                                color: Color(0xFF880E4F), // Color vino
                                size: 28,
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Título y Folio
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reporte['tipo'] ?? 'Sin categoría',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF880E4F), // Color vino
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 4),
                                  
                                  GestureDetector(
                                    onTap: () => _copyFolio(reporte['folio'] ?? 'Sin folio'),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Folio: ${reporte['folio'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Badge de Estado (Píldora)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade700, // Gris oscuro como en la imagen
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

                        const SizedBox(height: 20),

                        // Descripción o Título del problema (Negrita Negro)
                        Text(
                          reporte['descripcion'] ?? 'Sin descripción',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 16),

                        // Detalles: Ubicación
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 18, color: Color(0xFFFF80AB)), // Rosado
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reporte['ubicacion'] ?? 'Sin ubicación',
                                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        
                        // Detalles: Fecha
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFFF80AB)),
                            const SizedBox(width: 8),
                            Text(
                              'Reportado el ${reporte['fecha'] ?? ''}',
                              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Detalles: Imágenes
                         Row(
                          children: [
                            Icon(Icons.image_outlined, size: 18, color: Color(0xFFFF80AB)),
                            const SizedBox(width: 8),
                            Text(
                              '${(reporte['imagenes'] as List?)?.length ?? 0} imagen(es)',
                              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                        
                        // Preview de imagen grande abajo si existe
                        if (reporte['imagenes'] != null && (reporte['imagenes'] as List).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 120, // Altura fija para la imagen preview
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey.shade100,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Base64ImageWidget(
                                    base64String: (reporte['imagenes'] as List)[0],
                                    fit: BoxFit.cover,
                                  ),
                                  // Si hay más imágenes, mostrar overlay con contador
                                  if ((reporte['imagenes'] as List).length > 1)
                                    Container(
                                      color: Colors.black.withOpacity(0.4),
                                      alignment: Alignment.bottomRight,
                                      padding: EdgeInsets.all(8),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: Text(
                                          '+${(reporte['imagenes'] as List).length - 1}',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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

  // Card especial para reportes co-reportados (duplicados del usuario)
  // No muestra datos del autor original, solo el tipo, estado y contador de incidencias.
  Widget _buildDuplicadoCard(BuildContext context, Map<String, dynamic> reporte, int index) {
    final tipo = reporte['tipo'] ?? 'Problema reportado';
    final estado = reporte['estado'] ?? 'pendiente';
    final ubicacion = reporte['direccion'] ?? reporte['ubicacion'] ?? 'Sin ubicacion';
    final fecha = reporte['fecha'] ?? '';
    final contadorDuplicados = reporte['contadorDuplicados'] ?? 2;

    Color estadoColor;
    switch (estado.toLowerCase()) {
      case 'resuelto':
        estadoColor = Colors.green.shade600;
        break;
      case 'en proceso':
      case 'en_proceso':
        estadoColor = Colors.blue.shade600;
        break;
      case 'asignado':
        estadoColor = Colors.indigo.shade600;
        break;
      case 'en revision':
      case 'en revisión':
        estadoColor = Colors.orange.shade600;
        break;
      default:
        estadoColor = Colors.grey.shade600;
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge: Incidencia ya registrada
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Incidencia ya registrada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tipo + Estado
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.report_problem_outlined,
                            color: Colors.orange.shade700,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tipo,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$contadorDuplicados personas han reportado esta incidencia',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge de estado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: estadoColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            estado.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Ubicacion
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.orange.shade400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ubicacion,
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Fecha
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16, color: Colors.orange.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'Reportado el $fecha',
                          style: TextStyle(
                            color: Colors.blueGrey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _mostrarDetalleReporte(BuildContext context, Map<String, dynamic> reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Corregido: isScrollable -> isScrollControlled
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReportDetailSheet(reporte),
    );
  }

  Widget _buildReportDetailSheet(Map<String, dynamic> reporte) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF5F5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'DETALLE DEL REPORTE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '#${reporte['folio'] ?? 'SIN-FOLIO'}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFC62828),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _copyFolio(reporte['folio'] ?? ''),
                            child: const Icon(Icons.copy, color: Color(0xFFC62828), size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reporte['id'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade200,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.blueGrey.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ESTADO: ${_getEstadoDisplayText(reporte['estado'] ?? '').toUpperCase()}',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (reporte['imagenes'] != null && (reporte['imagenes'] as List).isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(Icons.image_outlined, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Imágenes del reporte',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Base64ImageWidget(
                                base64String: (reporte['imagenes'] as List)[0],
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '1/${(reporte['imagenes'] as List).length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FECHA',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reporte['fecha'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CATEGORÍA',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reporte['tipo'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.comment_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Comentario',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          reporte['descripcion'] ?? 'Sin comentarios adicionales.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Ubicación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.map, color: Colors.red.shade400, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reporte['ubicacion'] ?? 'Ubicación no disponible',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueGrey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.history, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Historial de seguimiento',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _buildTimeline(reporte['historialEstados']),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildTimeline(dynamic historial) {
    if (historial == null || (historial is List && historial.isEmpty)) {
      return const Text(
        'No hay historial de seguimiento disponible.',
        style: TextStyle(color: Colors.grey),
      );
    }

    final List<dynamic> listaOriginal = historial is List ? historial : [];
    final List<dynamic> lista = listaOriginal.reversed.toList();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final item = lista[index];
        final String estado = item['estado'] ?? 'Desconocido';
        final dynamic fechaRaw = item['fecha'];
        final String comentario = item['comentario'] ?? '';
        
        String fechaStr = 'Fecha desconocida';
        if (fechaRaw is Timestamp) {
          final fecha = fechaRaw.toDate();
          fechaStr = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
        } else if (fechaRaw is String) {
          fechaStr = fechaRaw;
        }

        final Color colorEstado = _getColorPorEstado(estado);
        final bool isLast = index == lista.length - 1;
        final bool isFirst = index == 0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorEstado,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorEstado.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getEstadoDisplayText(estado).toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorEstado,
                          ),
                        ),
                        if (isFirst) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorEstado.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACTUAL',
                              style: TextStyle(
                                color: colorEstado,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fechaStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (comentario.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          comentario,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}