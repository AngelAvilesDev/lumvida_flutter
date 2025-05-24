import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:image_picker/image_picker.dart';
import '../components/OSMMapComponent.dart';
import '../utils/constants.dart';
import '../utils/report_categories.dart';
import '../viewmodels/AuthViewModel.dart';
import '../services/ReporteService.dart';
import 'LoginScreen.dart';
import 'VerificacionIAReporteScreen.dart';

class ReportesScreen extends StatefulWidget {
  final String categoria;

  const ReportesScreen({Key? key, required this.categoria}) : super(key: key);

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  String? _selectedOption;
  final TextEditingController _commentController = TextEditingController();
  osm.GeoPoint? _selectedLocation;
  String _addressText = "Selecciona una ubicación en el mapa";
  final ReporteService _reporteService = ReporteService();
  bool _isSubmitting = false;

  // Lista de fotos
  final List<File> _selectedPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Función para seleccionar fotos
  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          // Si el índice ya existe, reemplazamos la imagen
          if (index < _selectedPhotos.length) {
            _selectedPhotos[index] = File(pickedFile.path);
          } else {
            // Si no, la añadimos
            _selectedPhotos.add(File(pickedFile.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Función para tomar foto con la cámara
  Future<void> _takePhoto(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          if (index < _selectedPhotos.length) {
            _selectedPhotos[index] = File(pickedFile.path);
          } else {
            _selectedPhotos.add(File(pickedFile.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al tomar foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Función para mostrar opciones de imagen
  void _showImageOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Función para proceder con la verificación IA
  Future<void> _proceedToVerification(BuildContext context, AuthViewModel authViewModel) async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una opción'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación en el mapa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Si no está autenticado, mostrar diálogo
    if (!authViewModel.isAuthenticated) {
      _mostrarDialogoInicioSesionRequerido(context);
      return;
    }

    // Obtener dirección real
    String direccion = _addressText;
    if (direccion.contains('Lat:') || direccion.contains('Lon:')) {
      direccion = await _reporteService.obtenerDireccion(_selectedLocation!);
    }

    // Preparar descripción
    String descripcion = _selectedOption == 'Otro (especificar)'
        ? _commentController.text.trim()
        : _selectedOption!;

    if (descripcion.isEmpty) {
      descripcion = 'Sin descripción';
    }

    // Navegar a la pantalla de verificación con IA
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificacionIAReporteScreen(
            categoria: widget.categoria,
            opcionSeleccionada: _selectedOption!,
            comentario: descripcion,
            ubicacion: _selectedLocation!,
            direccion: direccion,
            imagenes: _selectedPhotos,
            onConfirm: () => _submitReport(context, authViewModel, direccion, descripcion),
            onEdit: () {
              Navigator.pop(context); // Volver a editar
            },
          ),
        ),
      );
    }
  }

  // Función para enviar el reporte (después de verificación IA)
  Future<void> _submitReport(
      BuildContext context,
      AuthViewModel authViewModel,
      String direccion,
      String descripcion,
      ) async {
    // Cerrar la pantalla de verificación IA primero
    Navigator.pop(context);

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Enviar reporte
      final reporteId = await _reporteService.crearReporte(
        userId: authViewModel.user?.uid ?? 'anonymous',
        categoria: widget.categoria,
        descripcion: descripcion,
        direccion: direccion,
        ubicacion: _selectedLocation!,
        nombreCompleto: authViewModel.nombreUsuario ?? 'Anónimo',
        telefono: authViewModel.telefono ?? '',
        isAnonymous: !authViewModel.isAuthenticated,
        imagenes: _selectedPhotos,
      );

      if (reporteId != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte enviado con éxito'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Volver a la pantalla anterior
          Navigator.pop(context);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al enviar el reporte'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final category = ReportCategories.getCategoryByName(widget.categoria);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reportar ${category.name}', style: const TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono del tipo de problema
                    Center(
                      child: Icon(
                        category.icon,
                        color: kPrimaryColor,
                        size: 60,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Título principal
                    Text(
                      'Reportar ${category.name}',
                      style: kTitleStyle,
                    ),

                    const SizedBox(height: 30),

                    // Ubicación
                    const Text(
                      '¿DÓNDE SE UBICA EL PROBLEMA?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // OSM Map Component
                    OSMMapComponent(
                      height: 250,
                      trackMyLocation: true,
                      allowPicking: true,
                      onLocationSelected: (osm.GeoPoint location) {
                        setState(() {
                          _selectedLocation = location;
                          _addressText = 'Lat: ${location.latitude.toStringAsFixed(6)}, Lon: ${location.longitude.toStringAsFixed(6)}';
                        });
                      },
                    ),

                    if (_selectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ubicación: $_addressText',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Descripción
                    const Text(
                      'DESCRIBE EL PROBLEMA:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Opciones de reporte
                    ...category.options.map((option) => _buildCheckOption(
                      option.description,
                      option.description == _selectedOption,
                          () {
                        setState(() {
                          _selectedOption = option.description;
                        });
                      },
                    )).toList(),

                    // Campo para comentarios adicionales
                    if (_selectedOption == 'Otro (especificar)') ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Describe el problema...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 3,
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Sección de fotos
                    const Text(
                      'ADJUNTA FOTOS (OPCIONAL)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Las fotos ayudan a verificar y resolver el problema más rápido',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Contenedores para fotos
                    Row(
                      children: [
                        _buildPhotoContainer(0),
                        const SizedBox(width: 10),
                        _buildPhotoContainer(1),
                        const SizedBox(width: 10),
                        _buildPhotoContainer(2),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Botón de continuar (ahora lleva a verificación IA)
                    ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _proceedToVerification(context, authViewModel),
                      style: kPrimaryButtonStyle,
                      child: _isSubmitting
                          ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Procesando...', style: kButtonTextStyle),
                        ],
                      )
                          : const Text('Continuar', style: kButtonTextStyle),
                    ),
                  ],
                ),
              ),

              // Overlay de carga
              if (_isSubmitting)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  ),
                ),
            ],
          ),
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
                    onPressed: () {},
                    key: const ValueKey('location_icon'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.white, size: 28),
                    onPressed: () {
                      if (!authViewModel.isAuthenticated) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      }
                    },
                    key: const ValueKey('user_icon'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckOption(String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? kPrimaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoContainer(int index) {
    // Verificar si ya hay una foto en este índice
    final bool hasPhoto = index < _selectedPhotos.length;

    return Expanded(
      child: InkWell(
        onTap: () => _showImageOptions(index),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
              image: hasPhoto
                  ? DecorationImage(
                image: FileImage(_selectedPhotos[index]),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: hasPhoto
                ? Stack(
              alignment: Alignment.topRight,
              children: [
                // Botón para eliminar la foto
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPhotos.removeAt(index);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            )
                : const Icon(
              Icons.add_a_photo,
              color: Colors.grey,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoInicioSesionRequerido(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Iniciar sesión requerido', style: TextStyle(color: kPrimaryColor)),
          content: const Text('Para crear un reporte necesitas iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        );
      },
    );
  }
}