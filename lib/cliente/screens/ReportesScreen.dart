import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // CAMBIADO DE OSM
import 'package:image_picker/image_picker.dart';
import '../../shared/screens/LoginScreen.dart';
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../components/GoogleMapComponent.dart'; // CAMBIADO DE OSMMapComponent
import '../components/BottomNavigationWidget.dart';
import '../utils/report_categories.dart';
import '../viewmodels/ReportesViewModel.dart';
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

class _ReportesScreenState extends State<ReportesScreen> with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  late ReportesViewModel _reportesViewModel;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Variables para manejar sugerencias de IA
  bool _showAISuggestion = false;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categoria;
    _reportesViewModel = ReportesViewModel();

    // Configurar animaciones
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    // Si hay una categoría detectada por IA diferente, mostrar sugerencia
    if (widget.categoriaDetectadaPorIA != null &&
        widget.categoriaDetectadaPorIA != widget.categoria) {
      _showAISuggestion = true;
    }

    // Escuchar cambios del ViewModel
    _reportesViewModel.addListener(_onViewModelChanged);

    // Iniciar animaciones
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _reportesViewModel.removeListener(_onViewModelChanged);
    _reportesViewModel.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = ReportCategories.getCategoryByName(_selectedCategory);

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: .8),
                Colors.white.withValues(alpha: .95),
                kPrimaryColor.withValues(alpha: .03),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header moderno
                _buildModernHeader(),

                // Contenido principal
                Expanded(
                  child: Stack(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20.0),
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sugerencia de IA (si aplicable)
                                if (_showAISuggestion) _buildAISuggestionCard(),

                                // Header de categoría
                                _buildCategoryHeader(category),

                                const SizedBox(height: 24),

                                // Ubicación - ACTUALIZADO PARA GOOGLE MAPS
                                _buildLocationSection(),

                                const SizedBox(height: 24),

                                // Descripción del problema
                                _buildDescriptionSection(category),

                                const SizedBox(height: 24),

                                // Sección de fotos
                                _buildPhotosSection(),

                                const SizedBox(height: 32),

                                // Botón de continuar
                                _buildContinueButton(),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Overlay de carga
                      if (_reportesViewModel.isSubmitting)
                        Container(
                          color: Colors.black.withValues(alpha: .3),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: kPrimaryColor),
                                SizedBox(height: 16),
                                Text(
                                  'Procesando reporte...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'inicio'),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón de regreso
          Container(
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: kPrimaryColor),
            ),
          ),

          const SizedBox(width: 16),

          // Título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crear Reporte',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                Text(
                  _selectedCategory,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: .1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.smart_toy, color: Colors.blue.shade600, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sugerencia de IA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Basándome en el análisis de tu imagen anterior, parece que el problema es de "${widget.categoriaDetectadaPorIA}" en lugar de "${widget.categoria}". ¿Te gustaría cambiar la categoría?',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _dismissAISuggestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Mantener categoría'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _acceptAISuggestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _buildCategoryHeader(ReportCategory category) {
    final backgroundColor = category.backgroundColor ?? kPrimaryColor;
    final iconColor = category.color ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, backgroundColor.withValues(alpha: .8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: .3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              category.icon,
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reportar ${category.name}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.description ?? 'Describe el problema que encontraste',
                  style: TextStyle(
                    fontSize: 14,
                    color: iconColor.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SECCIÓN DE UBICACIÓN ACTUALIZADA PARA GOOGLE MAPS
  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          '¿Dónde se ubica el problema?',
          Icons.location_on,
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMapComponent( // CAMBIADO DE OSMMapComponent
              height: 250,
              trackMyLocation: true,
              allowPicking: true,
              onLocationSelected: (LatLng location) { // CAMBIADO DE osm.GeoPoint
                _reportesViewModel.setSelectedLocation(location);
              },
            ),
          ),
        ),

        if (_reportesViewModel.selectedLocation != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ubicación: ${_reportesViewModel.addressText}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionSection(ReportCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Describe el problema',
          Icons.description,
        ),
        const SizedBox(height: 16),

        // Opciones de reporte
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: category.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isLast = index == category.options.length - 1;

              return _buildCheckOption(
                option.description,
                option.description == _reportesViewModel.selectedOption,
                    () {
                  _reportesViewModel.setSelectedOption(option.description);
                },
                isLast: isLast,
              );
            }).toList(),
          ),
        ),

        // Campo para comentarios adicionales
        if (_reportesViewModel.selectedOption == 'Otro (especificar)') ...[
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Describe el problema específico...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(20),
                prefixIcon: const Icon(Icons.edit, color: kPrimaryColor),
              ),
              maxLines: 3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Adjunta fotos del problema',
          Icons.camera_alt,
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Las fotos son necesarias para que la IA verifique tu reporte.',
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

        const SizedBox(height: 16),

        Row(
          children: [
            _buildPhotoContainer(0, _reportesViewModel.selectedPhotos),
            const SizedBox(width: 12),
            _buildPhotoContainer(1, _reportesViewModel.selectedPhotos),
            const SizedBox(width: 12),
            _buildPhotoContainer(2, _reportesViewModel.selectedPhotos),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kPrimaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckOption(String text, bool isSelected, VoidCallback onTap, {bool isLast = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isLast ? 0 : 0),
          bottom: Radius.circular(isLast ? 16 : 0),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            border: isLast ? null : Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? kPrimaryColor : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? kPrimaryColor : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
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
              color: hasPhoto ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasPhoto ? Colors.green.shade300 : Colors.grey.shade300,
                width: hasPhoto ? 2 : 1,
              ),
              image: hasPhoto
                  ? DecorationImage(
                image: FileImage(photos[index]),
                fit: BoxFit.cover,
              )
                  : null,
              boxShadow: hasPhoto ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: .2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: hasPhoto
                ? Stack(
              children: [
                // Indicador de éxito
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
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
                // Botón para eliminar
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _reportesViewModel.removePhoto(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 12,
                      ),
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
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  index == 0 ? 'REQUERIDO' : 'Opcional',
                  style: TextStyle(
                    fontSize: 10,
                    color: index == 0 ? Colors.red : Colors.grey.shade600,
                    fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _reportesViewModel.isSubmitting
            ? null
            : const LinearGradient(
          colors: [kPrimaryColor, Color(0xFFD32F2F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        color: _reportesViewModel.isSubmitting ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: !_reportesViewModel.isSubmitting ? [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: .3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ] : null,
      ),
      child: ElevatedButton.icon(
        onPressed: _reportesViewModel.isSubmitting ? null : _proceedToVerification,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _reportesViewModel.isSubmitting
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.grey,
            strokeWidth: 2.0,
          ),
        )
            : const Icon(Icons.arrow_forward, color: Colors.white),
        label: Text(
          _reportesViewModel.isSubmitting ? 'Procesando...' : 'Continuar con verificación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _reportesViewModel.isSubmitting ? Colors.grey : Colors.white,
          ),
        ),
      ),
    );
  }

  // Métodos de funcionalidad

  void _acceptAISuggestion() {
    if (!mounted) return;

    setState(() {
      _selectedCategory = widget.categoriaDetectadaPorIA!;
      _showAISuggestion = false;
    });

    _reportesViewModel.setSelectedOption(null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Categoría cambiada a: $_selectedCategory'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 1024,
        maxHeight: 1024,
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

  Future<void> _takePhoto(int index) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1024,
        maxHeight: 1024,
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

  void _showImageOptions(int index) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Seleccionar imagen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildImageOptionButton(
                              icon: Icons.photo_library,
                              title: 'Galería',
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(index);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildImageOptionButton(
                              icon: Icons.camera_alt,
                              title: 'Cámara',
                              onTap: () {
                                Navigator.pop(context);
                                _takePhoto(index);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageOptionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(icon, color: kPrimaryColor, size: 32),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            ubicacion: _reportesViewModel.selectedLocation!, // YA ES LatLng
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarDialogoInicioSesionRequerido() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.login, color: kPrimaryColor),
              ),
              const SizedBox(width: 12),
              const Text(
                'Iniciar sesión requerido',
                style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoReporteExitoso(String folio) {
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Folio copiado al portapapeles'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
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
                    Navigator.of(dialogContext).pop();
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