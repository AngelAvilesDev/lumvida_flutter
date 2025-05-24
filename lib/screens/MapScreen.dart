import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/OSMMapComponent.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true;
  List<MarkerData> _reportMarkers = [];
  String? _selectedFilter;
  late osm.MapController _mapController;

  @override
  void initState() {
    super.initState();
    _loadReportLocations();
  }

  Future<void> _loadReportLocations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Consulta Firestore para obtener reportes
      final reportesSnapshot = await FirebaseFirestore.instance
          .collection('reportes')
          .get();

      if (kDebugMode) {
        print('Número de reportes encontrados: ${reportesSnapshot.docs.length}');
      }

      final markers = <MarkerData>[];

      for (var doc in reportesSnapshot.docs) {
        final data = doc.data();

        // Debug: Imprimir los datos del reporte
        if (kDebugMode) {
          print('Datos del reporte: $data');
        }

        // Verificar si el reporte tiene coordenadas - Usamos campos actualizados
        double? latitud;
        double? longitud;

        // Intentar obtener coordenadas de ambas formas posibles según tu estructura
        // Primera forma: campos latitud/longitud directos
        if (data['latitud'] != null && data['longitud'] != null) {
          latitud = (data['latitud'] as num).toDouble();
          longitud = (data['longitud'] as num).toDouble();
        }
        // Segunda forma: dentro del campo ubicacion
        else if (data['ubicacion'] != null &&
            data['ubicacion'] is Map &&
            data['ubicacion']['latitud'] != null &&
            data['ubicacion']['longitud'] != null) {
          latitud = (data['ubicacion']['latitud'] as num).toDouble();
          longitud = (data['ubicacion']['longitud'] as num).toDouble();
        }

        if (latitud != null && longitud != null) {
          // Definir un icono basado en la categoría
          Icon markerIcon;
          final categoria = data['categoria']?.toString().toLowerCase() ?? '';

          if (kDebugMode) {
            print('Categoría del reporte: $categoria');
          }

          switch (categoria) {
            case 'bacheo':
              markerIcon = const Icon(Icons.car_repair, color: Colors.red, size: 48);
              break;
            case 'alumbrado público':
              markerIcon = const Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 48);
              break;
            case 'basura acumulada':
              markerIcon = const Icon(Icons.delete_outline, color: Colors.orange, size: 48);
              break;
            case 'drenajes obstruidos':
              markerIcon = const Icon(Icons.water_drop, color: Colors.blue, size: 48);
              break;
            default:
              markerIcon = const Icon(Icons.report_problem, color: Colors.red, size: 48);
          }

          if (kDebugMode) {
            print('Añadiendo marcador en: Lat $latitud, Lon $longitud');
          }

          markers.add(
            MarkerData(
              position: osm.GeoPoint(
                latitude: latitud,
                longitude: longitud,
              ),
              icon: osm.MarkerIcon(icon: markerIcon),
              title: '${data['categoria'] ?? 'Sin categoría'} - ${data['folio'] ?? 'Sin folio'}',
            ),
          );
        } else {
          if (kDebugMode) {
            print('Reporte sin coordenadas válidas: ${doc.id}');
          }
        }
      }

      if (kDebugMode) {
        print('Total de marcadores creados: ${markers.length}');
      }

      setState(() {
        _reportMarkers = markers;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error cargando ubicaciones: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para aplicar filtros y actualizar el mapa
  Future<void> _applyFilter(String? filter) async {
    setState(() {
      _selectedFilter = filter;
    });

    if (kDebugMode) {
      print('Aplicando filtro: $filter');
    }

    // Eliminar todos los marcadores existentes y agregar solo los filtrados
    try {
      // Obtener marcadores filtrados
      final filteredMarkers = _getFilteredMarkers();

      if (kDebugMode) {
        print('Número de marcadores filtrados: ${filteredMarkers.length}');
      }

      // Recrear el componente del mapa para forzar la actualización
      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('Error al aplicar filtro: $e');
      }
    }
  }

  List<MarkerData> _getFilteredMarkers() {
    if (_selectedFilter == null || _selectedFilter == 'Todos') {
      return _reportMarkers;
    }

    // Filtrar marcadores según el filtro seleccionado
    return _reportMarkers.where((marker) {
      String categoriaOriginal = marker.title?.split(' - ').first.toLowerCase() ?? '';
      String filtro = _selectedFilter!.toLowerCase();

      if (kDebugMode) {
        print('Comparando categoría: "$categoriaOriginal" con filtro: "$filtro"');
      }

      // Verificar si la categoría coincide con el filtro
      if (filtro == 'bacheo' && categoriaOriginal.contains('bacheo')) {
        return true;
      } else if (filtro == 'alumbrado' && categoriaOriginal.contains('alumbrado')) {
        return true;
      } else if (filtro == 'basura' && categoriaOriginal.contains('basura')) {
        return true;
      } else if (filtro == 'drenajes' && (
          categoriaOriginal.contains('drenajes') ||
              categoriaOriginal.contains('obstruidos'))) {
        return true;
      }

      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Obtener marcadores filtrados
    final filteredMarkers = _getFilteredMarkers();

    if (kDebugMode) {
      print('Construyendo mapa con ${filteredMarkers.length} marcadores');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Reportes', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadReportLocations();
            },
          ),
        ],
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: Column(
          children: [
            // Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todos', _selectedFilter == null || _selectedFilter == 'Todos', () {
                      _applyFilter('Todos');
                    }),
                    _buildFilterChip('Bacheo', _selectedFilter == 'Bacheo', () {
                      _applyFilter('Bacheo');
                    }),
                    _buildFilterChip('Alumbrado', _selectedFilter == 'Alumbrado', () {
                      _applyFilter('Alumbrado');
                    }),
                    _buildFilterChip('Basura', _selectedFilter == 'Basura', () {
                      _applyFilter('Basura');
                    }),
                    _buildFilterChip('Drenajes', _selectedFilter == 'Drenajes', () {
                      _applyFilter('Drenajes');
                    }),
                  ],
                ),
              ),
            ),

            // Mapa - El key fuerza la reconstrucción completa cuando cambian los filtros
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                  : Padding(
                padding: const EdgeInsets.all(16.0),
                child: OSMMapComponent(
                  key: ValueKey('osm_map_${_selectedFilter ?? "todos"}_${filteredMarkers.length}'),
                  height: double.infinity,
                  trackMyLocation: true,
                  markers: filteredMarkers,
                ),
              ),
            ),

            // Contador de reportes (opcional, para depuración)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Mostrando ${filteredMarkers.length} reportes',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
                  IconButton(
                    icon: const Icon(Icons.location_on, color: Colors.white, size: 28),
                    onPressed: () {
                      // Recargar datos
                      _loadReportLocations();
                    },
                  ),
                  Consumer<AuthViewModel>(
                    builder: (context, authViewModel, _) => IconButton(
                      icon: const Icon(Icons.person, color: Colors.white, size: 28),
                      onPressed: () {
                        if (authViewModel.isAuthenticated) {
                          _mostrarDialogoCerrarSesion(context);
                        } else {
                          // Navegar a la pantalla de login
                        }
                      },
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.grey.shade200,
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
              onPressed: () async {
                final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
                await authViewModel.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop();
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