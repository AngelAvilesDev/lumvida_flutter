import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:image_picker/image_picker.dart';
import '../components/OSMMapComponent.dart';
import '../components/BottomNavigationWidget.dart';
import '../utils/constants.dart';
import '../utils/report_categories.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/ReportesViewModel.dart';
import 'LoginScreen.dart';
import 'VerificacionIAReporteScreen.dart';

class ReportesScreen extends StatefulWidget {
  final String categoria;
  final String? categoriaDetectadaPorIA;

  const ReportesScreen({
    Key? key,
    required this.categoria,
    this.categoriaDetectadaPorIA,
  }) : super(key: key);

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // ViewModel manejado directamente sin Provider interno
  late ReportesViewModel _reportesViewModel;

  // Variables para manejar sugerencias de IA
  bool _showAISuggestion = false;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categoria;
    _reportesViewModel = ReportesViewModel();

    // Si hay una categoría detectada por IA diferente, mostrar sugerencia
    if (widget.categoriaDetectadaPorIA != null &&
        widget.categoriaDetectadaPorIA != widget.categoria) {
      _showAISuggestion = true;
    }

    // Escuchar cambios del ViewModel
    _reportesViewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {}); // Rebuilds when ViewModel changes
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _reportesViewModel.removeListener(_onViewModelChanged);
    _reportesViewModel.dispose();
    super.dispose();
  }

  // Función para cambiar la categoría según sugerencia de IA
  void _acceptAISuggestion() {
    if (!mounted) return;

    setState(() {
      _selectedCategory = widget.categoriaDetectadaPorIA!;
      _showAISuggestion = false;
    });

    // Limpiar selección en el ViewModel
    _reportesViewModel.setSelectedOption(null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categoría cambiada a: $_selectedCategory'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _dismissAISuggestion() {
    if (!mounted) return;
    setState(() {
      _showAISuggestion = false;
    });
  }

  // Función para seleccionar fotos
  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null && mounted) {
        _reportesViewModel.updatePhoto(index, File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al seleccionar imagen: $e');
      }
    }
  }

  // Función para tomar foto con la cámara
  Future<void> _takePhoto(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (pickedFile != null && mounted) {
        _reportesViewModel.updatePhoto(index, File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al tomar foto: $e');
      }
    }
  }

  // Función para mostrar opciones de imagen
  void _showImageOptions(int index) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar imagen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: kPrimaryColor),
                title: const Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: kPrimaryColor),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto(index);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Función para proceder con la verificación IA
  Future<void> _proceedToVerification() async {
    if (!mounted) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    // Validar usando el ViewModel
    if (!_reportesViewModel.validateForm(_commentController.text)) {
      if (mounted) {
        _showErrorSnackBar(_reportesViewModel.errorMessage ?? 'Error de validación');
      }
      return;
    }

    // Si no está autenticado, mostrar diálogo
    if (!authViewModel.isAuthenticated) {
      if (mounted) {
        _mostrarDialogoInicioSesionRequerido();
      }
      return;
    }

    // Obtener dirección real si es necesario
    await _reportesViewModel.obtenerDireccionDeUbicacion();

    // Preparar descripción
    String descripcion = _reportesViewModel.selectedOption == 'Otro (especificar)'
        ? _commentController.text.trim()
        : _reportesViewModel.selectedOption!;

    if (descripcion.isEmpty) {
      descripcion = 'Sin descripción';
    }

    // Navegar a la pantalla de verificación con IA
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificacionIAReporteScreen(
            categoria: _selectedCategory,
            opcionSeleccionada: _reportesViewModel.selectedOption!,
            comentario: descripcion,
            ubicacion: _reportesViewModel.selectedLocation!,
            direccion: _reportesViewModel.addressText,
            imagenes: _reportesViewModel.selectedPhotos,
            onConfirm: () => _submitReport(descripcion),
            onEdit: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      );
    }
  }

  // Función para enviar el reporte (después de verificación IA)
  Future<void> _submitReport(String descripcion) async {
    if (!mounted) return;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    // Cerrar la pantalla de verificación IA
    Navigator.pop(context);

    try {
      final resultado = await _reportesViewModel.crearReporte(
        userId: authViewModel.user?.uid ?? 'anonymous',
        categoria: _selectedCategory,
        descripcion: descripcion,
        nombreCompleto: authViewModel.nombreUsuario ?? 'Anónimo',
        telefono: authViewModel.telefono ?? '',
        isAnonymous: !authViewModel.isAuthenticated,
      );

      if (mounted) {
        if (resultado['success']) {
          // SOLO mostrar el diálogo, la navegación se hace cuando el usuario presiona "Entendido"
          _mostrarDialogoReporteExitoso(resultado['folio']);
        } else {
          _showErrorSnackBar(resultado['message'] ?? 'Error al enviar el reporte');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = ReportCategories.getCategoryByName(_selectedCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reportar $_selectedCategory', style: const TextStyle(color: kPrimaryColor)),
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
                    // Sugerencia de IA (si aplicable)
                    if (_showAISuggestion) _buildAISuggestionCard(),

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
                      'Reportar $_selectedCategory',
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
                        _reportesViewModel.setSelectedLocation(location);
                      },
                    ),

                    if (_reportesViewModel.selectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ubicación: ${_reportesViewModel.addressText}',
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
                      option.description == _reportesViewModel.selectedOption,
                          () {
                        _reportesViewModel.setSelectedOption(option.description);
                      },
                    )).toList(),

                    // Campo para comentarios adicionales
                    if (_reportesViewModel.selectedOption == 'Otro (especificar)') ...[
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
                    _buildPhotosSection(),

                    const SizedBox(height: 40),

                    // Botón de continuar
                    ElevatedButton.icon(
                      onPressed: _reportesViewModel.isSubmitting
                          ? null
                          : _proceedToVerification,
                      style: kPrimaryButtonStyle,
                      label: _reportesViewModel.isSubmitting
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
              if (_reportesViewModel.isSubmitting)
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
      bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'inicio'),
    );
  }

  Widget _buildAISuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Sugerencia de IA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Basándome en el análisis de tu imagen anterior, parece que el problema es de "${widget.categoriaDetectadaPorIA}" en lugar de "${widget.categoria}". ¿Te gustaría cambiar la categoría?',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _dismissAISuggestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: const Text('Mantener categoría'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _acceptAISuggestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cambiar categoría'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADJUNTA FOTOS (REQUERIDO PARA VERIFICACIÓN)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Las fotos son necesarias para que la IA verifique que tu reporte coincide con la categoría seleccionada.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildPhotoContainer(0, _reportesViewModel.selectedPhotos),
            const SizedBox(width: 10),
            _buildPhotoContainer(1, _reportesViewModel.selectedPhotos),
            const SizedBox(width: 10),
            _buildPhotoContainer(2, _reportesViewModel.selectedPhotos),
          ],
        ),
      ],
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

  Widget _buildPhotoContainer(int index, List<File> photos) {
    final bool hasPhoto = index < photos.length;

    return Expanded(
      child: InkWell(
        onTap: () => _showImageOptions(index),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasPhoto ? Colors.green.shade300 : Colors.grey.shade400,
                width: hasPhoto ? 2 : 1,
              ),
              image: hasPhoto
                  ? DecorationImage(
                image: FileImage(photos[index]),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: hasPhoto
                ? Stack(
              alignment: Alignment.topRight,
              children: [
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _reportesViewModel.removePhoto(index),
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
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo,
                  color: Colors.grey.shade600,
                  size: 30,
                ),
                const SizedBox(height: 4),
                Text(
                  index == 0 ? 'REQUERIDO' : 'Opcional',
                  style: TextStyle(
                    fontSize: 10,
                    color: index == 0 ? Colors.red : Colors.grey.shade600,
                    fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoInicioSesionRequerido() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Iniciar sesión requerido', style: TextStyle(color: kPrimaryColor)),
          content: const Text('Para crear un reporte necesitas iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () {
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Iniciar sesión'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoReporteExitoso(String folio) {
    if (!mounted) return;

    // Usar un Future.delayed para asegurar que el contexto esté estable
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) { // Usar un contexto específico del diálogo
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '¡Reporte Enviado!',
                    style: TextStyle(
                        color: kPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Tu reporte ha sido enviado exitosamente y será revisado por nuestro equipo.',
                    style: TextStyle(fontSize: 16)
                ),
                const SizedBox(height: 16),
                const Text(
                    'Número de folio:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            folio,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kPrimaryColor
                            )
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: folio));
                          // Usar el contexto del widget principal para el SnackBar
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Folio copiado al portapapeles'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, color: kPrimaryColor),
                        tooltip: 'Copiar folio',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Puedes consultar el estado de tu reporte en la sección "Historial de reportes".',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // PRIMERO: Cerrar el diálogo
                    Navigator.of(dialogContext).pop();

                    // SEGUNDO: Navegar de regreso al inicio después de cerrar el diálogo
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) {
                        Navigator.of(context).popUntil((route) {
                          return route.settings.name == '/' ||
                              route.isFirst ||
                              route.settings.arguments?.toString().contains('InicioScreen') == true;
                        });
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text(
                      'Entendido',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }
}