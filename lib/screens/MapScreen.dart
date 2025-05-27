import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/OSMMapComponent.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/MapViewModel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapViewModel _mapViewModel;

  @override
  void initState() {
    super.initState();
    _mapViewModel = MapViewModel();

    // Cargar datos después de que se construya el widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapViewModel.cargarUbicacionesReportes();
    });
  }

  @override
  void dispose() {
    _mapViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _mapViewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mapa de Reportes', style: TextStyle(color: kPrimaryColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: kPrimaryColor),
          actions: [
            Consumer<MapViewModel>(
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
                      : const Icon(Icons.refresh),
                  onPressed: mapVM.isLoading ? null : () {
                    mapVM.recargar();
                  },
                );
              },
            ),
          ],
        ),
        body: Container(
          decoration: backgroundDecoration,
          child: Consumer<MapViewModel>(
            builder: (context, mapVM, child) {
              return Column(
                children: [
                  // Filtros
                  _buildFiltersSection(mapVM),

                  // Estadísticas rápidas
                  _buildStatsSection(mapVM),

                  // Mapa
                  Expanded(
                    child: mapVM.isLoading
                        ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: kPrimaryColor),
                          SizedBox(height: 16),
                          Text('Cargando reportes...'),
                        ],
                      ),
                    )
                        : mapVM.error != null
                        ? _buildErrorSection(mapVM)
                        : _buildMapSection(mapVM),
                  ),

                  // Contador de reportes
                  _buildReportCounter(mapVM),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildFiltersSection(MapViewModel mapVM) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              'Todos',
              mapVM.selectedFilter == null || mapVM.selectedFilter == 'Todos',
                  () => mapVM.aplicarFiltro('Todos'),
            ),
            _buildFilterChip(
              'Bacheo',
              mapVM.selectedFilter == 'Bacheo',
                  () => mapVM.aplicarFiltro('Bacheo'),
            ),
            _buildFilterChip(
              'Alumbrado',
              mapVM.selectedFilter == 'Alumbrado',
                  () => mapVM.aplicarFiltro('Alumbrado'),
            ),
            _buildFilterChip(
              'Basura',
              mapVM.selectedFilter == 'Basura',
                  () => mapVM.aplicarFiltro('Basura'),
            ),
            _buildFilterChip(
              'Drenajes',
              mapVM.selectedFilter == 'Drenajes',
                  () => mapVM.aplicarFiltro('Drenajes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(MapViewModel mapVM) {
    if (mapVM.isLoading) return const SizedBox.shrink();

    final statsPorEstado = mapVM.obtenerEstadisticasPorEstado();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Estado de los reportes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          // Estadísticas por estado con nuevos colores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Pendientes', statsPorEstado['pendiente'] ?? 0, Colors.grey),
              _buildStatItem('En Revisión', statsPorEstado['en revision'] ?? 0, Colors.orange),
              _buildStatItem('Asignado', statsPorEstado['asignado'] ?? 0, Colors.blue),
              _buildStatItem('En Proceso', statsPorEstado['en proceso'] ?? 0, Colors.yellow),
              _buildStatItem('Resuelto', statsPorEstado['resuelto'] ?? 0, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection(MapViewModel mapVM) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar el mapa',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              mapVM.error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => mapVM.recargar(),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(MapViewModel mapVM) {
    final filteredMarkers = mapVM.filteredMarkers;

    if (kDebugMode) {
      print('Construyendo mapa con ${filteredMarkers.length} marcadores');
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: OSMMapComponent(
        key: ValueKey('osm_map_${mapVM.selectedFilter ?? "todos"}_${filteredMarkers.length}'),
        height: double.infinity,
        trackMyLocation: true,
        markers: filteredMarkers,
      ),
    );
  }

  Widget _buildReportCounter(MapViewModel mapVM) {
    if (mapVM.isLoading) return const SizedBox.shrink();

    final filteredCount = mapVM.filteredMarkers.length;
    final totalCount = mapVM.reportMarkers.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $filteredCount de $totalCount reportes',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (mapVM.selectedFilter != null && mapVM.selectedFilter != 'Todos')
            TextButton.icon(
              onPressed: () => mapVM.aplicarFiltro('Todos'),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Limpiar filtro'),
              style: TextButton.styleFrom(
                foregroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
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

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: kSecondaryColor,
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
                Consumer<MapViewModel>(
                  builder: (context, mapVM, child) {
                    return IconButton(
                      icon: const Icon(Icons.location_on, color: Colors.white, size: 28),
                      onPressed: () => mapVM.recargar(),
                    );
                  },
                ),
                Consumer<AuthViewModel>(
                  builder: (context, authViewModel, _) => IconButton(
                    icon: const Icon(Icons.person, color: Colors.white, size: 28),
                    onPressed: () {
                      if (authViewModel.isAuthenticated) {
                        _mostrarDialogoCerrarSesion(context, authViewModel);
                      } else {
                        // Navegar a la pantalla de login
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Inicia sesión para acceder a más funciones'),
                            backgroundColor: kPrimaryColor,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCerrarSesion(BuildContext context, AuthViewModel authViewModel) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión', style: TextStyle(color: kPrimaryColor)),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                await authViewModel.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}