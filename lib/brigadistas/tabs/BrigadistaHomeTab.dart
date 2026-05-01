import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/BrigadaService.dart';
import '../models/ReporteModel.dart'; // Aunque se use EstadisticasModel, suele estar cerca
import '../../shared/utils/constants.dart';

class BrigadistaHomeTab extends StatefulWidget {
  final Map<String, dynamic> brigadaData;

  const BrigadistaHomeTab({Key? key, required this.brigadaData}) : super(key: key);

  @override
  State<BrigadistaHomeTab> createState() => _BrigadistaHomeTabState();
}

class _BrigadistaHomeTabState extends State<BrigadistaHomeTab> {
  final BrigadaService _brigadaService = BrigadaService();
  StreamSubscription<EstadisticasModel>? _estadisticasSubscription;
  EstadisticasModel _estadisticas = EstadisticasModel.vacio();

  @override
  void initState() {
    super.initState();
    _escucharEstadisticas();
  }

  @override
  void didUpdateWidget(covariant BrigadistaHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la lista de reportes asignados cambió, actualizar estadísticas
    if (widget.brigadaData['reportesAsignados'] != oldWidget.brigadaData['reportesAsignados']) {
      _escucharEstadisticas();
    }
  }

  @override
  void dispose() {
    _estadisticasSubscription?.cancel();
    super.dispose();
  }

  void _escucharEstadisticas() {
    _estadisticasSubscription?.cancel(); // Cancelar previa si existe
    final reportesIds = widget.brigadaData['reportesAsignados'] as List<dynamic>?;
    if (reportesIds == null || reportesIds.isEmpty) {
      setState(() {
        _estadisticas = EstadisticasModel.vacio();
      });
      return;
    }

    _estadisticasSubscription = _brigadaService
        .obtenerEstadisticasStream(reportesIds)
        .listen((estadisticas) {
      if (mounted) {
        setState(() {
          _estadisticas = estadisticas;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de bienvenida
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [kPrimaryColor, Color(0xFFD32F2F)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Bienvenido Brigadista!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.brigadaData['nombre'] ?? 'Brigada',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Usuario',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Título de estadísticas
            const Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),

            // Tarjetas de estadísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.assignment,
                    title: 'Total',
                    value: _estadisticas.total.toString(),
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pending_actions,
                    title: 'Asignados',
                    value: _estadisticas.asignados.toString(),
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.loop,
                    title: 'En Proceso',
                    value: _estadisticas.enProceso.toString(),
                    color: Colors.yellow.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    title: 'Resueltos',
                    value: _estadisticas.resueltos.toString(),
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
