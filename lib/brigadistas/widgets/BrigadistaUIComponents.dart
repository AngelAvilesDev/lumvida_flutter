import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../cliente/services/ReporteService.dart';
import '../models/ReporteModel.dart';

class BrigadistaUIComponents {
  static Widget buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey.shade700),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static Widget buildInfoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text.isEmpty ? 'No disponible' : text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.blueGrey.shade700,
          height: 1.5,
        ),
      ),
    );
  }

  static Widget buildImagenPreview(String base64Str) {
    if (base64Str.isEmpty) return const Icon(Icons.image_not_supported, color: Colors.grey);
    
    final bytes = ReporteService.base64ToBytes(base64Str);
    if (bytes.isEmpty) return const Icon(Icons.image_not_supported, color: Colors.grey);

    return Image.memory(
      Uint8List.fromList(bytes),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  static String formatearFecha(dynamic fecha) {
    if (fecha == null) return 'Fecha desconocida';
    if (fecha is DateTime) {
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    }
    try {
      final dt = fecha.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  static Widget buildEstadoBadge(String estado) {
    Color color;
    String texto;

    switch (estado.toLowerCase().trim()) {
      case 'asignado':
        color = Colors.blue.shade600;
        texto = 'Asignado';
        break;
      case 'en_proceso':
      case 'en proceso':
      case 'proceso':
        color = Colors.yellow.shade700;
        texto = 'En Proceso';
        break;
      case 'resuelto':
        color = Colors.green.shade600;
        texto = 'Resuelto';
        break;
      case 'en revisión':
      case 'en revision':
        color = Colors.orange.shade600;
        texto = 'En Revisión';
        break;
      default:
        color = Colors.grey.shade600;
        texto = 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Future<void> abrirGoogleMaps(BuildContext context, ReporteModel reporte) async {
    double? lat = reporte.latitud;
    double? lon = reporte.longitud;
    Uri url;
    if (lat != null && lon != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    } else {
      final encodedAddress = Uri.encodeComponent(reporte.direccion);
      url = Uri.parse('https://www.google.com/maps/search/$encodedAddress/@0,0,15z');
    }
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps'))
        );
      }
    }
  }
}
