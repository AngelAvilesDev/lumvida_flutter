import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ReporteModel.dart';
import '../services/BrigadaService.dart';
import '../../cliente/services/ReporteService.dart';
import '../../shared/utils/constants.dart';
import 'BrigadistaUIComponents.dart';

class DetalleReporteSheet extends StatefulWidget {
  final ReporteModel reporte;
  final VoidCallback onActualizar;

  const DetalleReporteSheet({
    Key? key,
    required this.reporte,
    required this.onActualizar,
  }) : super(key: key);

  @override
  State<DetalleReporteSheet> createState() => _DetalleReporteSheetState();
}

class _DetalleReporteSheetState extends State<DetalleReporteSheet> {
  final ImagePicker _picker = ImagePicker();
  final BrigadaService _brigadaService = BrigadaService();
  List<File> _imagenesEvidencia = [];
  bool _subiendoImagenes = false;
  double _progresoSubida = 0.0;

  Future<void> _seleccionarImagenes() async {
    final List<XFile>? images = await _picker.pickMultiImage(imageQuality: 50, maxWidth: 1024);
    if (images != null && images.isNotEmpty) {
      setState(() {
        _imagenesEvidencia.addAll(images.map((img) => File(img.path)));
        if (_imagenesEvidencia.length > 2) _imagenesEvidencia = _imagenesEvidencia.sublist(0, 2);
      });
    }
  }

  Future<void> _resolverReporte() async {
    if (_imagenesEvidencia.isEmpty) return;
    
    setState(() {
      _subiendoImagenes = true;
      _progresoSubida = 0.0;
    });

    try {
      // 1. Subir imágenes a Firebase Storage (Más seguro que Base64 para Firestore)
      final List<String> urlsEvidencias = await _brigadaService.subirImagenesEvidencia(
        widget.reporte.id, 
        _imagenesEvidencia,
        onProgress: (progreso) {
          if (mounted) setState(() => _progresoSubida = progreso);
        }
      );

      // 2. Resolver el reporte con las URLs obtenidas
      final exito = await _brigadaService.resolverReporte(widget.reporte.id, urlsEvidencias);
      
      if (exito && mounted) {
        Navigator.pop(context);
        widget.onActualizar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Reporte resuelto con éxito'), 
          backgroundColor: Colors.green
        ));
      } else if (mounted) {
        throw Exception('No se pudo actualizar el estado en la base de datos');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _subiendoImagenes = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error al resolver reporte: $e'), 
          backgroundColor: Colors.red
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF5F5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: const [
                    Text(
                      'DETALLE DE ACTIVIDAD',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              if (_subiendoImagenes)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kPrimaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Subiendo evidencias... ${(_progresoSubida * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progresoSubida,
                        backgroundColor: Colors.grey[300],
                        color: kPrimaryColor,
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '#${widget.reporte.folio ?? 'SIN-FOLIO'}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC62828),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.reporte.id,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade200,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              BrigadistaUIComponents.buildSectionHeader(Icons.category_outlined, 'Categoría'),
              const SizedBox(height: 12),
              BrigadistaUIComponents.buildInfoCard(widget.reporte.categoria),
              const SizedBox(height: 24),
              BrigadistaUIComponents.buildSectionHeader(Icons.person_outline, 'Reportado por'),
              const SizedBox(height: 12),
              BrigadistaUIComponents.buildInfoCard(widget.reporte.nombreUsuario ?? 'Usuario desconocido'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: BrigadistaUIComponents.buildSectionHeader(Icons.location_on_outlined, 'Ubicación')),
                  TextButton.icon(
                    onPressed: () => BrigadistaUIComponents.abrirMapa(context, widget.reporte),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Ver en Mapa'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BrigadistaUIComponents.buildInfoCard(widget.reporte.direccion),
              const SizedBox(height: 24),
              BrigadistaUIComponents.buildSectionHeader(Icons.description_outlined, 'Descripción'),
              const SizedBox(height: 12),
              BrigadistaUIComponents.buildInfoCard(widget.reporte.descripcion),
              const SizedBox(height: 24),
              if (widget.reporte.imagenes != null && widget.reporte.imagenes!.isNotEmpty) ...[
                BrigadistaUIComponents.buildSectionHeader(Icons.image_outlined, 'Fotos del reporte (Ciudadano)'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.reporte.imagenes!.length,
                    itemBuilder: (context, index) {
                      final bytes = ReporteService.base64ToBytes(widget.reporte.imagenes![index]);
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: bytes.isEmpty 
                              ? const Icon(Icons.image_not_supported, color: Colors.grey)
                              : Image.memory(
                                  Uint8List.fromList(bytes as List<int>), 
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                      const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Divider(height: 40),
              BrigadistaUIComponents.buildSectionHeader(Icons.camera_alt_outlined, 'Evidencias de resolución'),
              const SizedBox(height: 16),
              if (_imagenesEvidencia.length < 2)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _seleccionarImagenes,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      _imagenesEvidencia.isEmpty 
                        ? 'SUBIR EVIDENCIA' 
                        : 'SUBIR OTRA EVIDENCIA (${_imagenesEvidencia.length}/2)',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Límite de evidencias alcanzado (2/2)',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_imagenesEvidencia.isNotEmpty) ...[
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagenesEvidencia.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(_imagenesEvidencia[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 16,
                            child: GestureDetector(
                              onTap: () => setState(() => _imagenesEvidencia.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _imagenesEvidencia.isEmpty || _subiendoImagenes
                      ? null
                      : _resolverReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _subiendoImagenes
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'MARCAR COMO RESUELTO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
