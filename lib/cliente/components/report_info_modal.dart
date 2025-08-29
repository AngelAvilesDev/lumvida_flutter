import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/constants.dart';

class ReportInfoModal extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const ReportInfoModal({
    Key? key,
    required this.reportData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle del modal
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header con ícono y título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getEstadoColor(reportData['estado'] ?? '').withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(reportData['categoria'] ?? ''),
                  color: _getEstadoColor(reportData['estado'] ?? ''),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportData['categoria'] ?? 'Sin categoría',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                    Text(
                      'Folio: ${reportData['folio'] ?? 'Sin folio'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Estado prominente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _getEstadoColor(reportData['estado'] ?? ''),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getEstadoDisplayText(reportData['estado'] ?? 'pendiente').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Información del reporte
          _buildInfoSection('Descripción', reportData['comentario'] ?? 'Sin descripción'),
          _buildInfoSection('Ubicación', reportData['direccion'] ?? 'Sin ubicación'),
          _buildInfoSection('Fecha', _formatearFecha(reportData['fecha'])),

          const SizedBox(height: 20),

          // Botón de cerrar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Cerrar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Espacio adicional para el safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Obtener color basado en el estado
  Color _getEstadoColor(String estado) {
    final estadoNormalizado = _normalizeEstado(estado);
    switch (estadoNormalizado) {
      case 'pendiente':
        return Colors.grey.shade600;
      case 'en revisión':
        return Colors.orange.shade600;
      case 'asignado':
        return Colors.blue.shade600;
      case 'en proceso':
        return Colors.yellow.shade700;
      case 'resuelto':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // Normalizar estado para comparación
  String _normalizeEstado(String estado) {
    switch (estado.toLowerCase().trim()) {
      case 'pendiente':
      case 'nuevo':
        return 'pendiente';
      case 'en revision':
      case 'en revisión':
      case 'revision':
        return 'en revisión';
      case 'asignado':
        return 'asignado';
      case 'en proceso':
      case 'proceso':
        return 'en proceso';
      case 'resuelto':
      case 'completado':
      case 'terminado':
        return 'resuelto';
      default:
        return 'pendiente';
    }
  }

  // Obtener texto de display para el estado
  String _getEstadoDisplayText(String estado) {
    switch (_normalizeEstado(estado)) {
      case 'pendiente':
        return 'Pendiente';
      case 'en revisión':
        return 'En Revisión';
      case 'asignado':
        return 'Asignado';
      case 'en proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      default:
        return 'Pendiente';
    }
  }

  // Obtener ícono para la categoría
  IconData _getCategoryIcon(String categoria) {
    final categoriaLower = categoria.toLowerCase();
    if (categoriaLower.contains('basura') || categoriaLower.contains('recolección')) {
      return Icons.delete_outline;
    } else if (categoriaLower.contains('alumbrado')) {
      return Icons.lightbulb_outline;
    } else if (categoriaLower.contains('baches') || categoriaLower.contains('bacheo')) {
      return Icons.directions_car;
    } else if (categoriaLower.contains('alcantarillado') || categoriaLower.contains('drenaje')) {
      return Icons.water_drop_outlined;
    } else if (categoriaLower.contains('área verde') || categoriaLower.contains('parque')) {
      return Icons.park_outlined;
    } else if (categoriaLower.contains('grafiti') || categoriaLower.contains('vandalismo')) {
      return Icons.format_paint_outlined;
    }
    return Icons.report_problem_outlined;
  }

  // Formatear fecha
  String _formatearFecha(dynamic timestamp) {
    if (timestamp == null) return 'Fecha desconocida';

    try {
      DateTime fecha;
      if (timestamp is Timestamp) {
        fecha = timestamp.toDate();
      } else if (timestamp is DateTime) {
        fecha = timestamp;
      } else if (timestamp is String) {
        fecha = DateTime.parse(timestamp);
      } else {
        return 'Fecha desconocida';
      }

      final now = DateTime.now();
      final difference = now.difference(fecha).inDays;

      if (difference == 0) {
        return 'Hoy';
      } else if (difference == 1) {
        return 'Ayer';
      } else if (difference < 7) {
        return 'Hace $difference días';
      } else {
        return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      }
    } catch (e) {
      return 'Fecha desconocida';
    }
  }

  // Método estático para mostrar el modal
  static void show(BuildContext context, Map<String, dynamic> reportData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ReportInfoModal(reportData: reportData),
    );
  }
}