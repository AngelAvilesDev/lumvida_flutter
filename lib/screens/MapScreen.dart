import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/GoogleMapComponent.dart';
import '../components/BottomNavigationWidget.dart';
import '../components/report_info_modal.dart'; // NUEVO MODAL
import '../utils/constants.dart';
import '../viewmodels/MapViewModel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapViewModel _mapViewModel;
  late AnimationController _filterAnimationController;
  late AnimationController _fabAnimationController;
  bool _isFilterExpanded = false;

  // GlobalKey para acceder al GoogleMapComponent
  final GlobalKey<GoogleMapComponentState> _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mapViewModel = MapViewModel();

    // Animaciones
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Cargar datos después de que se construya el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapViewModel.cargarUbicacionesReportes();
      _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _fabAnimationController.dispose();
    _mapViewModel.dispose();
    super.dispose();
  }

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });

    if (_isFilterExpanded) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }
  }

  void _goToMyLocation() {
    // Acceder al GoogleMapComponent a través del GlobalKey
    if (_mapKey.currentState != null) {
      _mapKey.currentState!.goToMyLocation();
    }
  }

  // NUEVO: Función para centrar en todos los reportes
  void _centerAllReports() {
    final bounds = _mapViewModel.obtenerBoundsFiltrados();
    if (bounds != null) {
      // Esta funcionalidad se puede expandir en el GoogleMapComponent si es necesario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mostrando ${_mapViewModel.filteredMarkers.length} reportes'),
          backgroundColor: kPrimaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay reportes para mostrar'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // NUEVO: Manejar tap en marcador
  void _onMarkerTapped(Map<String, dynamic> reportData) {
    if (kDebugMode) {
      print('Marcador tocado: ${reportData['folio']} - ${reportData['categoria']}');
    }

    // Mostrar modal con información del reporte
    ReportInfoModal.show(context, reportData);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _mapViewModel,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .7),
                  Colors.black.withValues(alpha: .3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          title: const Text(
            'Mapa de Reportes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 3,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Consumer<MapViewModel>(
                builder: (context, mapVM, child) {
                  return IconButton(
                    icon: mapVM.isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: kPrimaryColor,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.refresh, color: kPrimaryColor),
                    onPressed: mapVM.isLoading ? null : () => mapVM.recargar(),
                    tooltip: 'Actualizar reportes',
                  );
                },
              ),
            ),
          ],
        ),
        body: Consumer<MapViewModel>(
          builder: (context, mapVM, child) {
            return Stack(
              children: [
                // Mapa principal - ACTUALIZADO PARA GOOGLE MAPS CON onMarkerTap
                _buildMapSection(mapVM),

                // Filtros flotantes - DINÁMICOS
                _buildFloatingFilters(mapVM),

                // Contador flotante
                _buildFloatingCounter(mapVM),

                // FABs flotantes
                _buildFloatingActionButtons(),
              ],
            );
          },
        ),
        bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'mapa'),
      ),
    );
  }

  Widget _buildMapSection(MapViewModel mapVM) {
    if (mapVM.isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: kPrimaryColor,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando reportes...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Localizando problemas en tu zona',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (mapVM.error != null) {
      return _buildErrorSection(mapVM);
    }

    final filteredMarkers = mapVM.filteredMarkers;

    if (kDebugMode) {
      print('Construyendo mapa de Google con ${filteredMarkers.length} marcadores');
    }

    // COMPONENTE DE GOOGLE MAPS CON CALLBACK DE TAP EN MARCADORES
    return GoogleMapComponent(
      key: _mapKey,
      height: double.infinity,
      trackMyLocation: true,
      markers: filteredMarkers,
      showLocationButton: false, // Lo manejamos nosotros
      onMarkerTap: _onMarkerTapped, // NUEVO CALLBACK
    );
  }

  Widget _buildErrorSection(MapViewModel mapVM) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFEBEE),
            Color(0xFFFFCDD2),
          ],
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.shade400,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Error al cargar el mapa',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mapVM.error ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => mapVM.recargar(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FILTROS DINÁMICOS - USANDO availableFilters DEL VIEWMODEL
  Widget _buildFloatingFilters(MapViewModel mapVM) {
    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Botón de filtros
          GestureDetector(
            onTap: _toggleFilter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isFilterExpanded ? kPrimaryColor : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    color: _isFilterExpanded ? Colors.white : kPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      color: _isFilterExpanded ? Colors.white : kPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isFilterExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: _isFilterExpanded ? Colors.white : kPrimaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lista de filtros expandible - FILTROS DINÁMICOS
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isFilterExpanded ? 60 : 0,
            child: AnimatedOpacity(
              opacity: _isFilterExpanded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: mapVM.availableFilters.map((filter) {
                      final isSelected = mapVM.selectedFilter == filter ||
                          (filter == 'Todos' && mapVM.selectedFilter == null);
                      return _buildFilterChip(filter, isSelected, () => mapVM.aplicarFiltro(filter));
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? kPrimaryColor : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCounter(MapViewModel mapVM) {
    if (mapVM.isLoading) return const SizedBox.shrink();

    final filteredCount = mapVM.filteredMarkers.length;
    final totalCount = mapVM.reportMarkers.length;

    return Positioned(
      bottom: 100,
      left: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: kPrimaryColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$filteredCount de $totalCount reportes',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.elasticOut,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón de ubicación
            FloatingActionButton(
              heroTag: "location_fab",
              onPressed: _goToMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: kPrimaryColor,
              elevation: 8,
              child: const Icon(Icons.my_location, size: 24),
            ),
            const SizedBox(height: 12),
            // Botón de centrar todos los reportes
            FloatingActionButton(
              heroTag: "center_all_fab",
              onPressed: _centerAllReports,
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 8,
              child: const Icon(Icons.center_focus_strong, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}