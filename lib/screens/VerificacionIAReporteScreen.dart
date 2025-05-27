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

class _VerificacionIAReporteScreenState extends State<VerificacionIAReporteScreen> {
  late VerificacionIAViewModel _verificacionViewModel;

  @override
  void initState() {
    super.initState();
    _verificacionViewModel = VerificacionIAViewModel();

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
  }

  @override
  void dispose() {
    _verificacionViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _verificacionViewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verificación con IA', style: TextStyle(color: kPrimaryColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: kPrimaryColor),
        ),
        body: Container(
          decoration: backgroundDecoration,
          child: SafeArea(
            child: Consumer<VerificacionIAViewModel>(
              builder: (context, verificacionVM, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con título y estado
                      _buildHeader(verificacionVM),

                      const SizedBox(height: 24),

                      // Contenido principal
                      Expanded(
                        child: _buildMainContent(verificacionVM),
                      ),

                      // Botones de acción
                      const SizedBox(height: 20),
                      if (!verificacionVM.isAnalyzing)
                        _buildActionButtons(verificacionVM),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VerificacionIAViewModel verificacionVM) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Verificación automática',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const Spacer(),
            if (verificacionVM.isAnalyzing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: kPrimaryColor,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                verificacionVM.canSubmitReport
                    ? Icons.check_circle
                    : verificacionVM.analysisFailed
                    ? Icons.error
                    : Icons.warning,
                color: verificacionVM.canSubmitReport
                    ? Colors.green
                    : verificacionVM.analysisFailed
                    ? Colors.red
                    : Colors.orange,
                size: 24,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          verificacionVM.obtenerMensajeEstado(),
          style: TextStyle(
            fontSize: 14,
            color: verificacionVM.isAnalyzing
                ? Colors.black54
                : verificacionVM.canSubmitReport
                ? Colors.green.shade700
                : Colors.red.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(VerificacionIAViewModel verificacionVM) {
    if (verificacionVM.isAnalyzing) {
      return _buildLoadingScreen();
    } else if (verificacionVM.analysisFailed) {
      return _buildErrorScreen(verificacionVM);
    } else {
      return _buildAnalysisResults(verificacionVM);
    }
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kPrimaryColor, strokeWidth: 3),
          SizedBox(height: 32),
          Text(
            'Analizando imágenes con IA...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'Verificando que la categoría reportada coincida exactamente con el contenido de las imágenes.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          LinearProgressIndicator(
            color: kPrimaryColor,
            backgroundColor: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(VerificacionIAViewModel verificacionVM) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error en el análisis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              verificacionVM.analysisMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => verificacionVM.reintentarAnalisis(),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar nuevamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults(VerificacionIAViewModel verificacionVM) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resultado de análisis de categoría - CRÍTICO
          _buildResultCard(
            icon: Icons.image_search,
            title: 'Análisis de imágenes',
            message: verificacionVM.isCategoryMatch
                ? '✅ La IA ha confirmado que la imagen muestra un problema de ${verificacionVM.categoria}.'
                : '❌ La IA ha detectado un problema de ${verificacionVM.detectedCategory} en la imagen, pero reportaste ${verificacionVM.categoria}. No coinciden.',
            isSuccess: verificacionVM.isCategoryMatch,
            isRequired: true,
          ),

          // Detalles adicionales del análisis
          if (verificacionVM.analysisMessage.isNotEmpty)
            _buildAnalysisDetailCard(verificacionVM),

          const SizedBox(height: 16),

          // Resultado de verificación de ubicación - INFORMATIVO
          _buildResultCard(
            icon: Icons.location_on,
            title: 'Verificación de ubicación',
            message: verificacionVM.locationVerificationMessage,
            isSuccess: verificacionVM.isLocationVerified,
            isRequired: false,
          ),

          const SizedBox(height: 24),

          // Información del reporte
          _buildSummaryCard(verificacionVM),

          const SizedBox(height: 16),

          // Muestra de imágenes analizadas
          _buildImageGallery(verificacionVM),

          const SizedBox(height: 24),

          // Resumen del análisis (para debugging o información adicional)
          if (!verificacionVM.canSubmitReport)
            _buildRecommendationCard(verificacionVM),
        ],
      ),
    );
  }

  Widget _buildAnalysisDetailCard(VerificacionIAViewModel verificacionVM) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
      child: Card(
        elevation: 0,
        color: verificacionVM.isCategoryMatch ? Colors.green.shade50 : Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.smart_toy,
                color: verificacionVM.isCategoryMatch ? Colors.green.shade600 : Colors.red.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis detallado de IA:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verificacionVM.isCategoryMatch ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      verificacionVM.analysisMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: verificacionVM.isCategoryMatch ? Colors.green.shade700 : Colors.red.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required String title,
    required String message,
    required bool isSuccess,
    bool isRequired = false,
  }) {
    Color cardColor;
    Color iconColor;

    if (isRequired) {
      cardColor = isSuccess ? Colors.green.shade100 : Colors.red.shade100;
      iconColor = isSuccess ? Colors.green.shade600 : Colors.red.shade600;
    } else {
      cardColor = isSuccess ? Colors.green.shade50 : Colors.amber.shade50;
      iconColor = isSuccess ? Colors.green.shade400 : Colors.amber.shade600;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRequired && !isSuccess ? BorderSide(color: Colors.red.shade300, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isRequired)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'REQUERIDO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
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

  Widget _buildSummaryCard(VerificacionIAViewModel verificacionVM) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle del reporte',
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
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black54,
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
          'Imágenes analizadas:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: kPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: verificacionVM.imagenes.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: FileImage(verificacionVM.imagenes[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: verificacionVM.isCategoryMatch ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          verificacionVM.isCategoryMatch ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(VerificacionIAViewModel verificacionVM) {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Recomendaciones',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              verificacionVM.isCategoryMatch
                  ? 'Tu reporte ha sido verificado correctamente. Puedes proceder a enviarlo.'
                  : 'Para mejorar la precisión de tu reporte:\n'
                  '• Verifica que la imagen muestre claramente el problema reportado\n'
                  '• Considera cambiar la categoría a "${verificacionVM.detectedCategory}"\n'
                  '• Toma una nueva foto que muestre específicamente el problema de "${verificacionVM.categoria}"',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(VerificacionIAViewModel verificacionVM) {
    return Column(
      children: [
        // Mostrar mensaje de advertencia si no se puede enviar
        if (!verificacionVM.canSubmitReport && !verificacionVM.analysisFailed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'No se puede enviar el reporte',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'La imagen no coincide con la categoría reportada. Por favor, revisa tu reporte y selecciona la categoría correcta o toma una nueva foto que corresponda al problema.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
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
                  side: const BorderSide(color: kPrimaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(verificacionVM.canSubmitReport ? 'Editar reporte' : 'Corregir reporte'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: verificacionVM.canSubmitReport ? () => widget.onConfirm() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: verificacionVM.canSubmitReport ? kPrimaryColor : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(verificacionVM.canSubmitReport ? 'Confirmar y enviar' : 'No se puede enviar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}