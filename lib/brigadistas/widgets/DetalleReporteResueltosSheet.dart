import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/ReporteModel.dart';
import '../../cliente/services/ReporteService.dart';
import 'BrigadistaUIComponents.dart';

class DetalleReporteResueltosSheet extends StatelessWidget {
  final ReporteModel reporte;

  const DetalleReporteResueltosSheet({
    Key? key,
    required this.reporte,
  }) : super(key: key);

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
                      'REPORTE RESUELTO',
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '#${reporte.folio ?? 'SIN-FOLIO'}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC62828),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'RESUELTO',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BrigadistaUIComponents.buildSectionHeader(Icons.category_outlined, 'Categoría'),
              const SizedBox(height: 12),
              BrigadistaUIComponents.buildInfoCard(reporte.categoria),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: BrigadistaUIComponents.buildSectionHeader(Icons.location_on_outlined, 'Ubicación')),
                  TextButton.icon(
                    onPressed: () => BrigadistaUIComponents.abrirGoogleMaps(context, reporte),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Ver en Google Maps'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BrigadistaUIComponents.buildInfoCard(reporte.direccion),
              const SizedBox(height: 24),
              BrigadistaUIComponents.buildSectionHeader(Icons.description_outlined, 'Descripción'),
              const SizedBox(height: 12),
              BrigadistaUIComponents.buildInfoCard(reporte.descripcion),
              const SizedBox(height: 24),

              if (reporte.imagenes != null && reporte.imagenes!.isNotEmpty) ...[
                BrigadistaUIComponents.buildSectionHeader(Icons.image_outlined, 'Fotos del reporte (Ciudadano)'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: reporte.imagenes!.length,
                    itemBuilder: (context, index) {
                      final bytes = ReporteService.base64ToBytes(reporte.imagenes![index]);
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
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

              if (reporte.evidencias != null && reporte.evidencias!.isNotEmpty) ...[
                BrigadistaUIComponents.buildSectionHeader(Icons.camera_alt_outlined, 'Evidencias de resolución (Brigadista)'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: reporte.evidencias!.length,
                    itemBuilder: (context, index) {
                      final bytes = ReporteService.base64ToBytes(reporte.evidencias![index]);
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
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
              ],
            ],
          ),
        );
      },
    );
  }
}
