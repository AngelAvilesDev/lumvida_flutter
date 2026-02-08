import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../components/GoogleMapComponent.dart';

class LocationSelectionScreen extends StatefulWidget {
  final LatLng initialLocation;

  const LocationSelectionScreen({
    Key? key,
    required this.initialLocation,
  }) : super(key: key);

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  late LatLng _selectedLocation;
  final GlobalKey<GoogleMapComponentState> _mapComponentKey = GlobalKey(); // KEY PARA CONTROLAR EL MAPA

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  void _onLocationSelected(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  void _confirmLocation() {
    Navigator.of(context).pop(_selectedLocation);
  }

  void _goToMyLocation() {
    _mapComponentKey.currentState?.goToMyLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustar Ubicación'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          GoogleMapComponent(
            key: _mapComponentKey, // ASIGNAR KEY
            height: double.infinity,
            initialPosition: widget.initialLocation,
            trackMyLocation: true,
            allowPicking: true,
            enableScroll: true,
            onLocationSelected: _onLocationSelected,
            showLocationButton: false, // OCULTAR BOTÓN INTERNO (usamos el custom)
            compactLocationButton: true, 
          ),
          
          // BOTÓN FLOTANTE "CENTRAR EN MÍ" (Manual para evitar overlap)
          Positioned(
            bottom: 100, // Altura suficiente para no chocar con el botón de confirmar
            right: 16,
            child: FloatingActionButton(
              heroTag: 'adjust_location_fab',
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              elevation: 4,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Botón flotante de confirmación
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _confirmLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Confirmar Ubicación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          
          // Instrucción flotante (opcional)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Arrastra el mapa para ubicar el problema en la calle exacta.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
