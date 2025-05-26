import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../services/OpenAIService.dart';

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
  bool _isAnalyzing = true;
  bool _isLocationVerified = false;
  bool _isCategoryMatch = false;
  String _detectedCategory = '';
  String _analysisMessage = '';
  String _locationVerificationMessage = '';
  bool _analysisFailed = false;
  bool _canSubmitReport = false; // Nueva variable para controlar si se puede enviar

  @override
  void initState() {
    super.initState();
    _analizarImagenes();
  }

  // Análisis real con la API de OpenAI
  Future<void> _analizarImagenes() async {
    setState(() {
      _isAnalyzing = true;
      _analysisFailed = false;
      _canSubmitReport = false; // Resetear al iniciar análisis
    });

    try {
      // Si no hay imágenes, no podemos hacer análisis
      if (widget.imagenes.isEmpty) {
        setState(() {
          _isAnalyzing = false;
          _analysisFailed = true;
          _analysisMessage = 'No se encontraron imágenes para analizar. Por favor adjunta imágenes del problema para poder verificar la categoría.';
          _detectedCategory = widget.categoria;
          _isCategoryMatch = false;
          _canSubmitReport = false; // No se puede enviar sin imágenes
        });
        return;
      }

      // Analizamos la primera imagen con OpenAI
      final Map<String, dynamic> imageAnalysis = await OpenAIService.analyzeImage(
          widget.imagenes[0],  // Analizamos la primera imagen
          widget.categoria,
          "Analiza esta imagen y determina si muestra un problema de '${widget.categoria}' como se ha reportado. "
              "Responde ÚNICAMENTE si la imagen coincide EXACTAMENTE con la categoría reportada. "
              "Si coincide, confirma que sí. Si NO coincide, indica qué tipo de problema se muestra realmente en la imagen, "
              "eligiendo ÚNICAMENTE entre: 'Bacheo', 'Alumbrado Público', 'Basura Acumulada' o 'Drenajes Obstruidos'. "
              "Si la imagen no muestra ninguno de estos problemas urbanos, indica que no es un problema válido para reportar."
      );

      // Verificamos los metadatos de ubicación
      final Map<String, dynamic> locationVerification = await OpenAIService.verifyLocationMetadata(
        widget.imagenes[0],
        widget.ubicacion.latitude,
        widget.ubicacion.longitude,
      );

      // Actualizamos el estado con los resultados
      setState(() {
        _isAnalyzing = false;
        _isCategoryMatch = imageAnalysis['isMatch'];
        _detectedCategory = imageAnalysis['detectedCategory'];
        _analysisMessage = imageAnalysis['message'];
        _isLocationVerified = locationVerification['isLocationVerified'];
        _locationVerificationMessage = locationVerification['message'];

        // LÓGICA CRÍTICA: Solo permitir envío si la categoría coincide EXACTAMENTE
        _canSubmitReport = _isCategoryMatch;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisFailed = true;
        _analysisMessage = 'Error al analizar las imágenes: $e';
        _detectedCategory = widget.categoria;
        _isCategoryMatch = false;
        _isLocationVerified = false;
        _locationVerificationMessage = 'No se pudieron verificar los metadatos de ubicación.';
        _canSubmitReport = false; // No se puede enviar si hay error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación con IA', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryColor),
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                const Text(
                  'Verificación automática',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Nuestro sistema está analizando tu reporte para garantizar su precisión.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 24),

                // Contenido principal
                Expanded(
                  child: _isAnalyzing
                      ? _buildLoadingScreen()
                      : _analysisFailed
                      ? _buildErrorScreen()
                      : _buildAnalysisResults(),
                ),

                // Botones de acción
                const SizedBox(height: 20),
                if (!_isAnalyzing)
                  _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Mostrar mensaje de advertencia si no se puede enviar
        if (!_canSubmitReport && !_analysisFailed)
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

        // Botones
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
                child: Text(_canSubmitReport ? 'Editar reporte' : 'Corregir reporte'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _canSubmitReport ? () => widget.onConfirm() : null, // Disabled si no se puede enviar
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmitReport ? kPrimaryColor : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(_canSubmitReport ? 'Confirmar y enviar' : 'No se puede enviar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: kPrimaryColor),
          const SizedBox(height: 24),
          const Text(
            'Analizando imágenes con IA...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Verificando que la categoría reportada coincida exactamente con el contenido de las imágenes.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
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
              _analysisMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _analizarImagenes,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Intentar nuevamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resultado de análisis de categoría - CRÍTICO
          _buildResultCard(
            icon: Icons.image_search,
            title: 'Análisis de imágenes',
            message: _isCategoryMatch
                ? '✅ La IA ha confirmado que la imagen muestra un problema de ${widget.categoria}.'
                : '❌ La IA ha detectado un problema de $_detectedCategory en la imagen, pero reportaste ${widget.categoria}. No coinciden.',
            isSuccess: _isCategoryMatch,
            isRequired: true, // Marcamos como requerido
          ),

          // Detalles adicionales del análisis (opinión de ChatGPT)
          if (_analysisMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
              child: Card(
                elevation: 0,
                color: _isCategoryMatch ? Colors.green.shade50 : Colors.red.shade50,
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
                        color: _isCategoryMatch ? Colors.green.shade600 : Colors.red.shade600,
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
                                color: _isCategoryMatch ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _analysisMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isCategoryMatch ? Colors.green.shade700 : Colors.red.shade700,
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
            ),

          const SizedBox(height: 16),

          // Resultado de verificación de ubicación - INFORMATIVO
          _buildResultCard(
            icon: Icons.location_on,
            title: 'Verificación de ubicación',
            message: _locationVerificationMessage,
            isSuccess: _isLocationVerified,
            isRequired: false, // No es requerido para enviar
          ),

          const SizedBox(height: 24),

          // Información del reporte
          _buildSummaryCard(),

          const SizedBox(height: 16),

          // Muestra de imágenes analizadas
          _buildImageGallery(),
        ],
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
      // Para validaciones críticas, usar colores más fuertes
      cardColor = isSuccess ? Colors.green.shade100 : Colors.red.shade100;
      iconColor = isSuccess ? Colors.green.shade600 : Colors.red.shade600;
    } else {
      // Para validaciones informativas, usar colores más suaves
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

  Widget _buildSummaryCard() {
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
            _buildInfoRow('Categoría:', widget.categoria),
            _buildInfoRow('Tipo de problema:', widget.opcionSeleccionada),
            if (widget.comentario.isNotEmpty)
              _buildInfoRow('Comentario:', widget.comentario),
            _buildInfoRow('Ubicación:', widget.direccion),
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

  Widget _buildImageGallery() {
    if (widget.imagenes.isEmpty) {
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
            itemCount: widget.imagenes.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: FileImage(widget.imagenes[index]),
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
                          color: _isCategoryMatch ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isCategoryMatch ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 16,
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
}