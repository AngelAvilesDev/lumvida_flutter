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

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    _mapController = MapController(
      initPosition: widget.initialPosition ?? GeoPoint(latitude: 25.6714, longitude: -100.3099),
    );
  }

  Future<void> _enableUserLocation() async {
    final permStatus = await Permission.location.request();
    if (permStatus.isGranted) {
      await _mapController.currentLocation();
      await _mapController.enableTracking();
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
                  if (widget.trackMyLocation) {
                    _enableUserLocation();
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
              onLocationChanged: (position) {},
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
                onPressed: () {
                  _enableUserLocation();
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    _mapController.centerMap.then((position) {
                      _updateSelectedLocation();
                      _getAddressFromPosition(position);
                    });
                  });
                },
                child: const Icon(Icons.my_location, color: Colors.blue),
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
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _addressText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
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