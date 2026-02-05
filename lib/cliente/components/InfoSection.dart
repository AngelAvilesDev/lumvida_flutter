import 'package:flutter/material.dart';
import 'package:lumvida_app/shared/utils/constants.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      // Fixed: Using withValues to match project style if strict, but staying with withOpacity for standard Flutter.
      // Reverting to withOpacity as standard unless user specifically requested otherwise.
      // Wait, in previous files I used `withOpacity`.
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: kPrimaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Información importante',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Tus reportes serán verificados por IA antes de ser enviados\n'
            '• Incluye fotos claras del problema para mejor procesamiento\n'
            '• Recibirás actualizaciones sobre el estado de tus reportes\n'
            '• Todos los reportes son anónimos por defecto',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
