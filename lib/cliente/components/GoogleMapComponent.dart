import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui' as ui;

import '../../shared/utils/api_config.dart';

class GoogleMapComponent extends StatefulWidget {
  final double height;
  final bool trackMyLocation;
  final bool allowPicking;
  final Function(LatLng)? onLocationSelected;
  final LatLng? initialPosition;
  final List<MarkerData>? markers;
  final bool showLocationButton;
  final Function(Map<String, dynamic>)? onMarkerTap;
  final bool enableScroll; // Nuevo parámetro para controlar gestos
  final bool compactLocationButton; // Nuevo parámetro para mostrar solo FAB

  const GoogleMapComponent({
    Key? key,
    this.height = 300.0,
    this.trackMyLocation = true,
    this.allowPicking = false,
    this.onLocationSelected,
    this.initialPosition,
    this.markers,
    this.showLocationButton = true,
    this.onMarkerTap,
    this.enableScroll = true, // Por defecto habilitado
    this.compactLocationButton = false, // Por defecto ancho completo
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

    // NUEVO: Si la posición inicial cambia (ej. al volver de "Ajustar Ubicación"), mover la cámara
    if (widget.initialPosition != oldWidget.initialPosition) {
       if (widget.initialPosition != null && _isMapReady) {
          goToLocation(widget.initialPosition!);
          // También actualizar el marcador de selección si aplica
          if (widget.allowPicking) {
             setState(() {
               _selectedLocation = widget.initialPosition;
             });
          }
       }
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

  // CACHE DE ICONOS ESTÁTICO PARA MEJORAR RENDIMIENTO
  static final Map<String, BitmapDescriptor> _markerIconCache = {};

  // CONVERTIR ICONO PERSONALIZADO A BITMAP CON CACHÉ
  Future<BitmapDescriptor> _createCustomMarkerIcon(Icon? customIcon) async {
    if (customIcon == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    try {
      // DEFINIR TAMAÑO: Usar el definido en el icono o un default más pequeño (35.0)
      final double iconSize = customIcon.size ?? 35.0;

      // Generar una clave única para el caché INCLUYENDO EL TAMAÑO
      final String cacheKey = '${customIcon.icon?.codePoint}_${customIcon.color?.value ?? 0}_${customIcon.icon?.fontFamily}_$iconSize';

      // Verificar si ya existe en caché
      if (_markerIconCache.containsKey(cacheKey)) {
        return _markerIconCache[cacheKey]!;
      }

      // Crear un widget de icono personalizado con el tamaño correcto
      final icon = Icon(
        customIcon.icon,
        color: customIcon.color ?? Colors.red,
        size: iconSize,
      );

      // Convertir el widget a bitmap
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(customIcon.icon?.codePoint ?? Icons.location_on.codePoint),
          style: TextStyle(
            fontSize: iconSize,
            fontFamily: customIcon.icon?.fontFamily ?? 'MaterialIcons',
            color: customIcon.color ?? Colors.red,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, const Offset(0, 0));

      final picture = pictureRecorder.endRecording();
      // Usar el tamaño exacto para la imagen
      final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      final bitmapDescriptor = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
      
      // Guardar en caché
      _markerIconCache[cacheKey] = bitmapDescriptor;

      return bitmapDescriptor;
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

  // MÉTODO PÚBLICO PARA AJUSTAR LA CÁMARA A UNOS LÍMITES (AUTO-ENFOQUE)
  Future<void> fitBounds(LatLngBounds bounds, {double padding = 50.0}) async {
    if (_mapController == null || !_isMapReady) return;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (e) {
      debugPrint('Error al ajustar límites del mapa: $e');
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
      width: double.infinity,
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
              scrollGesturesEnabled: widget.enableScroll, // Controlado por parámetro
              rotateGesturesEnabled: widget.enableScroll, // También bloqueamos rotación si no hay scroll
              tiltGesturesEnabled: widget.enableScroll,   // Y tilt
              zoomGesturesEnabled: widget.enableScroll, // Zoom también bloqueado si enableScroll es false (mapa estático)


              // Callbacks
              onTap: null, // DESHABILITADO: Evitar cambios accidentales por toque
              onCameraMove: widget.allowPicking ? _onCameraMove : null,
              onCameraIdle: widget.allowPicking ? _onCameraIdle : null, // Detectar fin del movimiento (Drag)
            ),
          ),

          // Marcador central para selección de ubicación
          if (widget.allowPicking)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36), // Ajuste visual para que la punta del pin esté en el centro
                child: Icon(
                  Icons.location_pin,
                  color: Colors.red.shade800,
                  size: 40,
                ),
              ),
            ),

          // Botón de mi ubicación personalizado (Tipo 'Obtener Ubicación')
          if (widget.showLocationButton && _isMapReady)
            Positioned(
              bottom: 16,
              right: 16,
              left: widget.compactLocationButton ? null : 16, // Si es compacto, no ocupa todo el ancho
              child: widget.compactLocationButton
                  ? FloatingActionButton(
                      heroTag: 'my_location_fab_${widget.hashCode}',
                      mini: false,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      onPressed: _isLocatingUser ? null : goToMyLocation,
                      child: _isLocatingUser
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    )
                  : SizedBox(
                      height: 50,
                      width: double.infinity, // Asegurar ancho completo
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12), // Reducir padding si es necesario
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _isLocatingUser ? null : goToMyLocation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isLocatingUser
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.my_location, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible( // Usar Flexible para que el texto se adapte
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isLocatingUser ? 'Localizando...' : 'Obtener mi ubicación',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

          // Información de dirección eliminada para limpiar la UI

        ],
      ),
    );
  }

  // Métodos para picking de ubicación - MEJORADO
  
  void _onCameraMove(CameraPosition position) {
    if (widget.allowPicking) {
      // Solo actualizamos visualmente para feedback inmediato
      // No llamamos al callback aquí para evitar spam de peticiones
      setState(() {
        _selectedLocation = position.target;
        // _addressText = 'Soltá para seleccionar...'; 
      });
    }
  }

  // NUEVO: Se llama cuando el mapa deja de moverse (por drag o animación)
  void _onCameraIdle() {
    if (widget.allowPicking && _selectedLocation != null) {
      // Aquí es donde realmente confirmamos la selección
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(_selectedLocation!);
      }
      
      setState(() {
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