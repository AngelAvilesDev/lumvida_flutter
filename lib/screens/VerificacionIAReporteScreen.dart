import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../viewmodels/VerificacionIAViewModel.dart';

class VerificacionIAReporteScreen extends StatefulWidget {
  final String categoria;
  final String opcionSeleccionada;
  final String comentario;
  final osm.GeoPoint ubicacion;
  final String direccion;
  final List<File> imagenes;
  final Function onConfirm;
  final Function onEdit;

  const VerificacionIAReporteScreen({
    Key? key,
    required this.categoria,
    required this.opcionSeleccionada,
    required this.comentario,
    required this.ubicacion,
    required this.direccion,
    required this.imagenes,
    required this.onConfirm,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<VerificacionIAReporteScreen> createState() => _VerificacionIAReporteScreenState();
}

class _VerificacionIAReporteScreenState extends State<VerificacionIAReporteScreen>
    with TickerProviderStateMixin {
  late VerificacionIAViewModel _verificacionViewModel;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _verificacionViewModel = VerificacionIAViewModel();

    // Configurar animaciones
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Inicializar datos del reporte
    _verificacionViewModel.inicializarDatos(
      categoria: widget.categoria,
      opcionSeleccionada: widget.opcionSeleccionada,
      comentario: widget.comentario,
      ubicacion: widget.ubicacion,
      direccion: widget.direccion,
      imagenes: widget.imagenes,
    );

    // Iniciar análisis automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificacionViewModel.analizarImagenes();
    });

    // Iniciar animaciones
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _verificacionViewModel.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _verificacionViewModel,
      child: Scaffold(
        body: Container(
          decoration: backgroundDecoration,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.95),
                  kPrimaryColor.withOpacity(0.03),
                ],
              ),
            ),
            child: SafeArea(
              child: Consumer<VerificacionIAViewModel>(
                builder: (context, verificacionVM, child) {
                  return Column(
                    children: [
                      // Header moderno
                      _buildModernHeader(verificacionVM),

                      // Contenido principal
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildMainContent(verificacionVM),
                        ),
                      ),

                      // Botones de acción
                      if (!verificacionVM.isAnalyzing)
                        _buildActionButtons(verificacionVM),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(VerificacionIAViewModel verificacionVM) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icono de estado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(verificacionVM).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: verificacionVM.isAnalyzing ? _pulseAnimation.value : 1.0,
                      child: Icon(
                        _getStatusIcon(verificacionVM),
                        color: _getStatusColor(verificacionVM),
                        size: 24,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 16),

              // Título y estado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verificación automática',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      verificacionVM.obtenerMensajeEstado(),
                      style: TextStyle(
                        fontSize: 14,
                        color: _getStatusColor(verificacionVM),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Barra de progreso
          if (verificacionVM.isAnalyzing) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent(VerificacionIAViewModel verificacionVM) {
    if (verificacionVM.isAnalyzing) {
      return _buildLoadingContent();
    } else if (verificacionVM.analysisFailed) {
      return _buildErrorContent(verificacionVM);
    } else {
      return _buildAnalysisResults(verificacionVM);
    }
  }

  Widget _buildLoadingContent() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación de carga
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.6)],
                      ),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Analizando con IA...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Verificando que la categoría reportada coincida exactamente con el contenido de las imágenes.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Lista de pasos
            Column(
              children: [
                _buildAnalysisStep('Procesando imágenes', true),
                _buildAnalysisStep('Analizando contenido con IA', true),
                _buildAnalysisStep('Verificando coincidencia de categoría', false),
                _buildAnalysisStep('Validando ubicación', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisStep(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isActive ? kPrimaryColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isActive ? kPrimaryColor : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(VerificacionIAViewModel verificacionVM) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 48,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Error en el análisis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              verificacionVM.analysisMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () => verificacionVM.reintentarAnalisis(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar nuevamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResults(VerificacionIAViewModel verificacionVM) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resultado principal
          _buildMainResultCard(verificacionVM),

          const SizedBox(height: 20),

          // Detalles del análisis
          if (verificacionVM.analysisMessage.isNotEmpty)

          const SizedBox(height: 20),

          // Verificación de ubicación
          _buildLocationVerificationCard(verificacionVM),

          const SizedBox(height: 20),

          // Resumen del reporte
          _buildReportSummaryCard(verificacionVM),

          const SizedBox(height: 20),

          // Galería de imágenes
          _buildImageGallery(verificacionVM),

          const SizedBox(height: 20),

          // Recomendaciones
          if (!verificacionVM.canSubmitReport)
            _buildRecommendationCard(verificacionVM),
        ],
      ),
    );
  }

  Widget _buildMainResultCard(VerificacionIAViewModel verificacionVM) {
    final isSuccess = verificacionVM.isCategoryMatch;
    final color = isSuccess ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSuccess ? Icons.verified : Icons.warning,
                  color: color.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess ? 'Verificación exitosa' : 'Problema detectado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSuccess
                          ? '✅ La IA confirma que la imagen muestra un problema de ${verificacionVM.categoria}.'
                          : '❌ La IA detectó un problema de ${verificacionVM.detectedCategory}, pero reportaste ${verificacionVM.categoria}.',
                      style: TextStyle(
                        fontSize: 14,
                        color: color.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationVerificationCard(VerificacionIAViewModel verificacionVM) {
    final isVerified = verificacionVM.isLocationVerified;
    final color = isVerified ? Colors.green : Colors.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.location_on,
              color: color.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verificación de ubicación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verificacionVM.locationVerificationMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSummaryCard(VerificacionIAViewModel verificacionVM) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del reporte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Categoría:', verificacionVM.categoria),
          _buildInfoRow('Tipo de problema:', verificacionVM.opcionSeleccionada),
          if (verificacionVM.comentario.isNotEmpty)
            _buildInfoRow('Comentario:', verificacionVM.comentario),
          _buildInfoRow('Ubicación:', verificacionVM.direccion),
          _buildInfoRow('Imágenes adjuntas:', '${verificacionVM.imagenes.length}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(VerificacionIAViewModel verificacionVM) {
    if (verificacionVM.imagenes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imágenes analizadas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: verificacionVM.imagenes.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.file(
                        verificacionVM.imagenes[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                      // Indicador de verificación
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: verificacionVM.isCategoryMatch
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            verificacionVM.isCategoryMatch
                                ? Icons.check
                                : Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      // Número de imagen
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(VerificacionIAViewModel verificacionVM) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recomendaciones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            verificacionVM.isCategoryMatch
                ? 'Tu reporte ha sido verificado correctamente. Puedes proceder a enviarlo.'
                : 'Para mejorar la precisión de tu reporte:\n'
                '• Verifica que la imagen muestre claramente el problema reportado\n'
                '• Considera cambiar la categoría a "${verificacionVM.detectedCategory}"\n'
                '• Toma una nueva foto que muestre específicamente el problema de "${verificacionVM.categoria}"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(VerificacionIAViewModel verificacionVM) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Mensaje de advertencia si no se puede enviar
          if (!verificacionVM.canSubmitReport && !verificacionVM.analysisFailed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'No se puede enviar el reporte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La imagen no coincide con la categoría reportada. Por favor, revisa tu reporte y selecciona la categoría correcta o toma una nueva foto que corresponda al problema.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onEdit(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    verificacionVM.canSubmitReport
                        ? 'Editar reporte'
                        : 'Corregir reporte',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: verificacionVM.canSubmitReport
                      ? () => widget.onConfirm()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verificacionVM.canSubmitReport
                        ? kPrimaryColor
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: verificacionVM.canSubmitReport ? 2 : 0,
                  ),
                  child: Text(
                    verificacionVM.canSubmitReport
                        ? 'Confirmar y enviar'
                        : 'No se puede enviar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares para obtener estado
  Color _getStatusColor(VerificacionIAViewModel verificacionVM) {
    if (verificacionVM.isAnalyzing) {
      return kPrimaryColor;
    } else if (verificacionVM.analysisFailed) {
      return Colors.red;
    } else if (verificacionVM.canSubmitReport) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  IconData _getStatusIcon(VerificacionIAViewModel verificacionVM) {
    if (verificacionVM.isAnalyzing) {
      return Icons.smart_toy;
    } else if (verificacionVM.analysisFailed) {
      return Icons.error;
    } else if (verificacionVM.canSubmitReport) {
      return Icons.check_circle;
    } else {
      return Icons.warning;
    }
  }
}