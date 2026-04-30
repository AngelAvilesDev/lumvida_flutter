import 'package:flutter/material.dart';
import '../models/ReporteModel.dart';
import 'BrigadistaUIComponents.dart';

class ReporteCard extends StatelessWidget {
  final ReporteModel reporte;
  final int index;
  final VoidCallback onTap;
  final bool isResuelto;

  const ReporteCard({
    Key? key,
    required this.reporte,
    required this.index,
    required this.onTap,
    this.isResuelto = false,
  }) : super(key: key);

  IconData _getIconForType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('basura') || lowerType.contains('recolección')) {
      return Icons.delete_outline;
    } else if (lowerType.contains('alumbrado')) {
      return Icons.lightbulb_outline;
    } else if (lowerType.contains('baches') || lowerType.contains('bacheo')) {
      return Icons.directions_car;
    } else if (lowerType.contains('alcantarillado') || lowerType.contains('drenaje')) {
      return Icons.water_drop;
    }
    return Icons.report_problem_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                _getIconForType(reporte.categoria),
                                color: const Color(0xFF880E4F),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reporte.categoria,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF880E4F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Folio: ${reporte.folio ?? reporte.id}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            BrigadistaUIComponents.buildEstadoBadge(reporte.estado),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          reporte.descripcion.isNotEmpty ? reporte.descripcion : 'Sin descripción',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Color(0xFFFF80AB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reporte.direccion,
                                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFFF80AB)),
                            const SizedBox(width: 8),
                            Text(
                              isResuelto 
                                ? 'Resuelto el ${BrigadistaUIComponents.formatearFecha(reporte.fechaResolucion)}'
                                : 'Reportado el ${BrigadistaUIComponents.formatearFecha(reporte.fechaCreacion)}',
                              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.image_outlined, size: 18, color: Color(0xFFFF80AB)),
                            const SizedBox(width: 8),
                            Text(
                              '${reporte.imagenes?.length ?? 0} imagen(es)',
                              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                            ),
                          ],
                        ),
                        if (reporte.imagenes != null && reporte.imagenes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey.shade100,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  BrigadistaUIComponents.buildImagenPreview(reporte.imagenes![0]),
                                  if (reporte.imagenes!.length > 1)
                                    Container(
                                      color: Colors.black.withOpacity(0.4),
                                      alignment: Alignment.bottomRight,
                                      padding: const EdgeInsets.all(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          '+${reporte.imagenes!.length - 1}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
