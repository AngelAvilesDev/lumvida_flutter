import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class OSMMapComponent extends StatefulWidget {
  final double height;
  final bool trackMyLocation;
  final bool allowPicking;
  final Function(GeoPoint)? onLocationSelected;
  final GeoPoint? initialPosition;
  final List<MarkerData>? markers;
  final bool showLocationButton;

  const OSMMapComponent({
    Key? key,
    this.height = 300.0,
    this.trackMyLocation = true,
    this.allowPicking = false,
    this.onLocationSelected,
    this.initialPosition,
    this.markers,
    this.showLocationButton = true,
  }) : super(key: key);

  @override
  State<OSMMapComponent> createState() => OSMMapComponentState();
}

class OSMMapComponentState extends State<OSMMapComponent> {
  late MapController _mapController;
  bool _isMapReady = false;
  GeoPoint? _selectedLocation;
  String _addressText = '';
  Timer? _debounceTimer;
  bool _isLocatingUser = false;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    // Ubicación inicial en Chetumal, México (no en África)
    _mapController = MapController(
      initPosition: widget.initialPosition ?? GeoPoint(latitude: 18.5074, longitude: -88.2958),
    );
  }

  // Método público para ir a una ubicación específica
  Future<void> goToLocation(GeoPoint location) async {
    if (!_isMapReady) return;

    try {
      await _mapController.moveTo(location);
      await _mapController.zoomIn(); // Zoom apropiado
    } catch (e) {
      debugPrint('Error al ir a ubicación: $e');
    }
  }

  // Método público para ir a la ubicación del usuario (OPTIMIZADO)
  Future<void> goToMyLocation() async {
    if (_isLocatingUser || !_isMapReady) return; // Evitar múltiples llamadas

    setState(() {
      _isLocatingUser = true;
    });

    try {
      // Verificar permisos primero
      final permStatus = await Permission.location.status;

      if (!permStatus.isGranted) {
        final newStatus = await Permission.location.request();
        if (!newStatus.isGranted) {
          _showLocationError('Permisos de ubicación denegados');
          return;
        }
      }

      // Obtener ubicación actual RÁPIDAMENTE
      final currentLocation = await _mapController.myLocation();

      if (currentLocation != null) {
        // Mover el mapa inmediatamente a la ubicación con zoom específico
        await _mapController.moveTo(currentLocation);
        await _mapController.zoomIn(); // Zoom más cercano para mejor visibilidad

        // Activar tracking si está habilitado
        if (widget.trackMyLocation && _isMapReady) {
          await _mapController.enableTracking();
        }

        if (widget.onLocationSelected != null) {
          widget.onLocationSelected!(currentLocation);
        }

        _showLocationSuccess();
      } else {
        _showLocationError('No se pudo obtener la ubicación');
      }
    } catch (e) {
      _showLocationError('Error al obtener ubicación: $e');
    } finally {
      setState(() {
        _isLocatingUser = false;
      });
    }
  }

  void _showLocationSuccess() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Ubicación actualizada'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _enableUserLocation() async {
    if (_isLocatingUser) return;

    setState(() {
      _isLocatingUser = true;
    });

    try {
      // Verificar y solicitar permisos MÁS RÁPIDO
      final permStatus = await Permission.location.status;

      if (permStatus.isGranted) {
        // Si ya tenemos permisos, obtener ubicación inmediatamente
        await _mapController.currentLocation();
        if (widget.trackMyLocation) {
          await _mapController.enableTracking();
        }
      } else {
        // Solicitar permisos
        final newStatus = await Permission.location.request();
        if (newStatus.isGranted) {
          await _mapController.currentLocation();
          if (widget.trackMyLocation) {
            await _mapController.enableTracking();
          }
        }
      }
    } catch (e) {
      debugPrint('Error enabling location: $e');
    } finally {
      setState(() {
        _isLocatingUser = false;
      });
    }
  }

  Future<void> updateMarkers(List<MarkerData> newMarkers) async {
    if (!_isMapReady) return;

    try {
      await _mapController.removeAllShapes();
      for (final marker in newMarkers) {
        await _mapController.addMarker(
          marker.position,
          markerIcon: marker.icon ?? const MarkerIcon(
            icon: Icon(
              Icons.location_on,
              color: Colors.red,
              size: 48,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error actualizando marcadores: $e');
    }
  }

  Future<void> _addMarkers() async {
    if (widget.markers == null || !_isMapReady) return;

    try {
      await _mapController.removeAllShapes();
      for (final marker in widget.markers!) {
        await _mapController.addMarker(
          marker.position,
          markerIcon: marker.icon ?? const MarkerIcon(
            icon: Icon(
              Icons.location_on,
              color: Colors.red,
              size: 48,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding marker: $e');
    }
  }

  Future<void> _updateSelectedLocation() async {
    if (!widget.allowPicking) return;

    try {
      final centerPosition = await _mapController.centerMap;
      setState(() {
        _selectedLocation = centerPosition;
        _addressText = 'Lat: ${centerPosition.latitude.toStringAsFixed(6)}, Lon: ${centerPosition.longitude.toStringAsFixed(6)}';
      });

      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(centerPosition);
      }
    } catch (e) {
      debugPrint('Error updating selected location: $e');
    }
  }

  Future<void> _getAddressFromPosition(GeoPoint position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TuAppFlutter/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String direccion = data['display_name'] ?? '';

        if (direccion.isNotEmpty) {
          setState(() {
            _addressText = direccion;
          });
          if (widget.onLocationSelected != null) {
            widget.onLocationSelected!(position);
          }
        }
      } else {
        debugPrint('Error de Nominatim: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error obteniendo dirección: $e');
    }
  }

  @override
  void didUpdateWidget(OSMMapComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.markers != oldWidget.markers && _isMapReady) {
      _addMarkers();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: OSMFlutter(
              controller: _mapController,
              onMapIsReady: (isReady) {
                setState(() {
                  _isMapReady = isReady;
                });
                if (isReady) {
                  // UBICACIÓN MÁS RÁPIDA AL INICIALIZAR
                  if (widget.trackMyLocation) {
                    // Usar un delay más corto para mejorar la experiencia
                    Future.delayed(const Duration(milliseconds: 500), () {
                      _enableUserLocation();
                    });
                  }
                  if (widget.markers != null && widget.markers!.isNotEmpty) {
                    _addMarkers();
                  }
                  if (widget.allowPicking) {
                    _updateSelectedLocation();
                    _mapController.centerMap.then((position) {
                      _getAddressFromPosition(position);
                    });
                  }
                }
              },
              osmOption: OSMOption(
                userLocationMarker: UserLocationMaker(
                  personMarker: const MarkerIcon(
                    icon: Icon(
                      Icons.location_history,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  directionArrowMarker: const MarkerIcon(
                    icon: Icon(
                      Icons.double_arrow,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                ),
                zoomOption: const ZoomOption(
                  initZoom: 16,
                  minZoomLevel: 3,
                  maxZoomLevel: 19,
                  stepZoom: 1.0,
                ),
                userTrackingOption: UserTrackingOption(
                  enableTracking: widget.trackMyLocation,
                  unFollowUser: !widget.trackMyLocation,
                ),
                roadConfiguration: const RoadOption(
                  roadColor: Colors.blueAccent,
                ),
              ),
              onGeoPointClicked: (geoPoint) {
                if (widget.allowPicking) {
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    _updateSelectedLocation();
                    _getAddressFromPosition(geoPoint);
                  });
                }
              },
              onLocationChanged: (position) {
                // Callback para cambios de ubicación - más responsive
                if (widget.trackMyLocation) {
                  debugPrint('Ubicación actualizada: ${position.latitude}, ${position.longitude}');
                }
              },
            ),
          ),
          if (widget.allowPicking)
            Center(
              child: Icon(
                Icons.location_pin,
                color: Colors.red.shade800,
                size: 36,
              ),
            ),
          if (widget.showLocationButton && _isMapReady)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                heroTag: "location_button_${widget.key.toString()}",
                backgroundColor: Colors.white,
                onPressed: _isLocatingUser ? null : goToMyLocation,
                child: _isLocatingUser
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
                    : const Icon(Icons.my_location, color: Colors.blue),
              ),
            ),
          if (widget.allowPicking && _isMapReady)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton(
                mini: true,
                heroTag: "refresh_button_${widget.key.toString()}",
                backgroundColor: Colors.white,
                onPressed: () {
                  _updateSelectedLocation();
                  _mapController.centerMap.then((position) {
                    _getAddressFromPosition(position);
                  });
                },
                child: const Icon(Icons.refresh, color: Colors.green),
              ),
            ),
          if (widget.allowPicking && _addressText.isNotEmpty)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _addressText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          // Indicador de carga de ubicación
          if (_isLocatingUser)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Obteniendo ubicación...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MarkerData {
  final GeoPoint position;
  final MarkerIcon? icon;
  final String? title;

  MarkerData({
    required this.position,
    this.icon,
    this.title,
  });
}