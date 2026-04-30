import 'dart:async';
import 'package:flutter/material.dart';
import '../services/BrigadaService.dart';
import '../models/ReporteModel.dart';
import '../../shared/utils/constants.dart';
import '../widgets/ReporteCard.dart';
import '../widgets/DetalleReporteResueltosSheet.dart';

class BrigadistaResueltosTab extends StatefulWidget {
  final Map<String, dynamic> brigadaData;

  const BrigadistaResueltosTab({Key? key, required this.brigadaData}) : super(key: key);

  @override
  State<BrigadistaResueltosTab> createState() => _BrigadistaResueltosTabState();
}

class _BrigadistaResueltosTabState extends State<BrigadistaResueltosTab> {
  final BrigadaService _brigadaService = BrigadaService();
  StreamSubscription<List<ReporteModel>>? _reportesSubscription;
  List<ReporteModel> _reportes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _escucharReportes();
  }

  @override
  void dispose() {
    _reportesSubscription?.cancel();
    super.dispose();
  }

  void _escucharReportes() {
    final reportesIds = widget.brigadaData['reportesAsignados'] as List<dynamic>?;

    if (reportesIds == null || reportesIds.isEmpty) {
      setState(() {
        _reportes = [];
        _loading = false;
      });
      return;
    }

    _reportesSubscription = _brigadaService
        .obtenerReportesStream(reportesIds, soloResueltos: true)
        .listen((reportes) {
      if (mounted) {
        setState(() {
          _reportes = reportes;
          _loading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    });
  }

  Future<void> _refrescarReportes() async {
    setState(() {
      _loading = true;
    });
    _escucharReportes();
  }

  void _mostrarDetalleReporte(ReporteModel reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DetalleReporteResueltosSheet(reporte: reporte),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            )
          : _reportes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay reportes resueltos',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refrescarReportes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reportes.length,
                    itemBuilder: (context, index) {
                      final reporte = _reportes[index];
                      return ReporteCard(
                        reporte: reporte,
                        index: index,
                        onTap: () => _mostrarDetalleReporte(reporte),
                        isResuelto: true,
                      );
                    },
                  ),
                ),
    );
  }
}
