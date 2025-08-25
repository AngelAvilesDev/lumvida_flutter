import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../utils/api_config.dart';

class GoogleMapComponent extends StatefulWidget {
  final double height;
  final bool trackMyLocation;
  final bool allowPicking;
  final Function(LatLng)? onLocationSelected;
  final LatLng? initialPosition;
  final List<MarkerData>? markers;
  final bool showLocationButton;
  final Function(Map<String, dynamic>)? onMarkerTap; // NUEVO CALLBACK

  const GoogleMapComponent({
    Key? key,
    this.height = 300.0,
    this.trackMyLocation = true,
    this.allowPicking = false,
    this.onLocationSelected,
    this.initialPosition,
    this.markers,
    this.showLocationButton = true,
    this.onMarkerTap, // NUEVO PARÁMETRO
  }) : super(key: key);

  @override
  State<GoogleMapComponent> createState() => GoogleMapComponentState();
}

class GoogleMapComponentState extends State<GoogleMapComponent> {
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  LatLng? _selectedLocation;
  String _addressText = '';
  bool _isLocatingUser = false;
  Set<Marker> _currentMarkers = {};

  // Ubicación inicial en Chetumal, México
  static const LatLng _defaultLocation = LatLng(18.5074, -88.2958);

  @override
  void initState() {
    super.initState();

    // VERIFICAR QUE LA API KEY ESTÉ CONFIGURADA
    if (ApiConfig.googleMapsApiKey.isEmpty) {
      debugPrint('⚠️ Google Maps API Key no encontrada. Revisa tu archivo .env');
    } else {
      debugPrint('✅ Google Maps API Key cargada correctamente');
    }

    _initializeMarkers();
  }

  void _initializeMarkers() {
    if (widget.markers != null) {
      _updateMarkersFromData(widget.markers!);
    }
  }

  @override
  void didUpdateWidget(GoogleMapComponent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // SOLUCIÓN AL PROBLEMA: Actualizar marcadores automáticamente cuando cambian
    if (widget.markers != oldWidget.markers && _isMapReady) {
      _updateMarkersFromData(widget.markers ?? []);
    }
  }

  // MÉTODO PARA ACTUALIZAR MARCADORES SIN RECARGAR EL MAPA
  Future<void> _updateMarkersFromData(List<MarkerData> markersData) async {
    final Set<Marker> newMarkers = {};

    for (int i = 0; i < markersData.length; i++) {
      final markerData = markersData[i];

      // Crear marcador de Google Maps a partir de MarkerData
      final marker = Marker(
        markerId: MarkerId('marker_$i'),
        position: LatLng(
          markerData.position.latitude,
          markerData.position.longitude,
        ),
        icon: await _createCustomMarkerIcon(markerData.icon),
        onTap: () {
          // MANEJAR TAP EN MARCADOR
          if (widget.onMarkerTap != null && markerData.reportData != null) {
            widget.onMarkerTap!(markerData.reportData!);
          }
        },
      );

      newMarkers.add(marker);
    }

    setState(() {
      _currentMarkers = newMarkers;
    });
  }

  // CONVERTIR ICONO PERSONALIZADO A BITMAP
  Future<BitmapDescriptor> _createCustomMarkerIcon(Icon? customIcon) async {
    if (customIcon == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    try {
      // Crear un widget de icono personalizado
      final icon = Icon(
        customIcon.icon,
        color: customIcon.color ?? Colors.red,
        size: 48.0, // Tamaño fijo para marcadores
      );

      // Convertir el widget a bitmap
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(customIcon.icon?.codePoint ?? Icons.location_on.codePoint),
          style: TextStyle(
            fontSize: 48.0,
            fontFamily: customIcon.icon?.fontFamily ?? 'MaterialIcons',
            color: customIcon.color ?? Colors.red,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, const Offset(0, 0));

      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(48, 48);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error creando icono personalizado: $e');
      // Fallback a marcador por defecto con color
      return BitmapDescriptor.defaultMarkerWithHue(
        _getHueFromColor(customIcon.color ?? Colors.red),
      );
    }
  }

  // OBTENER HUE DE COLOR PARA MARCADOR POR DEFECTO
  double _getHueFromColor(Color color) {
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.blue) return BitmapDescriptor.hueBlue;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.yellow) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueRed; // Por defecto
  }

  // MÉTODO PÚBLICO PARA IR A UNA UBICACIÓN ESPECÍFICA
  Future<void> goToLocation(LatLng location) async {
    if (_mapController == null || !_isMapReady) return;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 16.0, // Zoom apropiado para ver detalles urbanos
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error al ir a ubicación: $e');
    }
  }

  // SOLUCIÓN AL PROBLEMA: ZOOM AUTOMÁTICO PERFECTO A MI UBICACIÓN
  Future<void> goToMyLocation() async {
    if (_isLocatingUser || _mapController == null || !_isMapReady) return;

    setState(() {
      _isLocatingUser = true;
    });

    try {
      // Verificar permisos
      final permission = await _checkLocationPermission();
      if (!permission) {
        _showLocationError('Permisos de ubicación denegados');
        return;
      }

      // Obtener ubicación actual con alta precisión
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLocation = LatLng(position.latitude, position.longitude);

      // ZOOM AUTOMÁTICO SUAVE Y PRECISO
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLocation,
            zoom: 18.0, // Zoom cercano para ver la ubicación exacta
            tilt: 0, // Vista desde arriba
          ),
        ),
      );

      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(userLocation);
      }

      _showLocationSuccess();

    } catch (e) {
      _showLocationError('Error al obtener ubicación: $e');
    } finally {
      setState(() {
        _isLocatingUser = false;
      });
    }
  }

  // VERIFICAR PERMISOS DE UBICACIÓN
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationError('Los servicios de ubicación están deshabilitados');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationError('Permisos de ubicación denegados permanentemente');
      return false;
    }

    return true;
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

  // MÉTODO PÚBLICO PARA ACTUALIZAR MARCADORES
  Future<void> updateMarkers(List<MarkerData> newMarkers) async {
    await _updateMarkersFromData(newMarkers);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });

    // Auto-ubicación mejorada al inicializar
    if (widget.trackMyLocation) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _enableAutoLocation();
      });
    }
  }

  Future<void> _enableAutoLocation() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (hasPermission) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 16.0,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error en auto-ubicación: $e');
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
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
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: widget.initialPosition ?? _defaultLocation,
                zoom: 14.0,
              ),

              // MARCADORES REACTIVOS - SOLUCIÓN AL PROBLEMA DE FILTROS
              markers: _currentMarkers,

              // Configuraciones de ubicación
              myLocationEnabled: widget.trackMyLocation,
              myLocationButtonEnabled: false, // Usamos nuestro botón custom

              // Configuraciones de mapa
              mapType: MapType.normal,
              compassEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,

              // Callbacks
              onTap: widget.allowPicking ? _onMapTapped : null,
              onCameraMove: widget.allowPicking ? _onCameraMove : null,
            ),
          ),

          // Marcador central para selección de ubicación
          if (widget.allowPicking)
            Center(
              child: Icon(
                Icons.location_pin,
                color: Colors.red.shade800,
                size: 36,
              ),
            ),

          // Botón de mi ubicación personalizado
          if (widget.showLocationButton && _isMapReady)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                heroTag: "google_location_button_${widget.key.toString()}",
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

          // Información de dirección para picking
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
        ],
      ),
    );
  }

  // Métodos para picking de ubicación - MEJORADO
  void _onMapTapped(LatLng location) {
    if (widget.allowPicking) {
      setState(() {
        _selectedLocation = location;
        _addressText = 'Obteniendo dirección...';
      });

      // Llamar al callback inmediatamente
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(location);
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    if (widget.allowPicking) {
      setState(() {
        _selectedLocation = position.target;
        _addressText = 'Obteniendo dirección...';
      });
    }
  }
}

// CLASE DE DATOS ACTUALIZADA CON reportData
class MarkerData {
  final LatLng position;
  final Icon? icon;
  final String? title;
  final Map<String, dynamic>? reportData; // NUEVO CAMPO

  MarkerData({
    required this.position,
    this.icon,
    this.title,
    this.reportData, // NUEVO PARÁMETRO
  });

  // Constructor para compatibilidad con GeoPoint de OSM
  MarkerData.fromGeoPoint({
    required double latitude,
    required double longitude,
    this.icon,
    this.title,
    this.reportData, // NUEVO PARÁMETRO
  }) : position = LatLng(latitude, longitude);
}