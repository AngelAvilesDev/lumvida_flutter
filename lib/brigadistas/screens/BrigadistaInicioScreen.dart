import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

// IMPORTS ACTUALIZADOS
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../services/BrigadaService.dart';
import '../models/ReporteModel.dart';

// ================================================
// 🏠 PANTALLA PRINCIPAL DE BRIGADISTA
// ================================================
class BrigadistaInicioScreen extends StatefulWidget {
  const BrigadistaInicioScreen({Key? key}) : super(key: key);

  @override
  State<BrigadistaInicioScreen> createState() => _BrigadistaInicioScreenState();
}

class _BrigadistaInicioScreenState extends State<BrigadistaInicioScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _brigadaData;
  bool _loadingBrigada = true;
  final BrigadaService _brigadaService = BrigadaService();

  @override
  void initState() {
    super.initState();
    _cargarBrigadaDelUsuario();
  }

  Future<void> _cargarBrigadaDelUsuario() async {
    final brigada = await _brigadaService.obtenerBrigadaDelUsuario();
    setState(() {
      _brigadaData = brigada;
      _loadingBrigada = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBrigada) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kPrimaryColor),
        ),
      );
    }

    if (_brigadaData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('LumVida - Brigadista'),
          backgroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'No perteneces a ninguna brigada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Contacta al administrador para ser asignado.'),
            ],
          ),
        ),
      );
    }

    final List<Widget> _screens = [
      BrigadistaHomeTab(brigadaData: _brigadaData!),
      BrigadistaReportesTab(brigadaData: _brigadaData!),
      BrigadistaResueltosTab(brigadaData: _brigadaData!),
      const BrigadistaPerfilTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LumVida - Brigadista',
          style: TextStyle(
            color: kPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                _brigadaData!['nombre'] ?? 'Brigadista',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: kPrimaryColor,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Reportes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              label: 'Resueltos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================
// 📊 TAB DE INICIO (ESTADÍSTICAS)
// ================================================
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
  void dispose() {
    _estadisticasSubscription?.cancel();
    super.dispose();
  }

  void _escucharEstadisticas() {
    final reportesIds = widget.brigadaData['reportesAsignados'] as List<dynamic>?;
    if (reportesIds == null || reportesIds.isEmpty) return;

    _estadisticasSubscription = _brigadaService
        .obtenerEstadisticasStream(reportesIds)
        .listen((estadisticas) {
      setState(() {
        _estadisticas = estadisticas;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: backgroundDecoration,
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
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pending_actions,
                    title: 'Asignados',
                    value: _estadisticas.asignados.toString(),
                    color: Colors.orange,
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
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    title: 'Resueltos',
                    value: _estadisticas.resueltos.toString(),
                    color: Colors.green,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
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
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================
// 📋 TAB DE REPORTES ACTIVOS
// ================================================
class BrigadistaReportesTab extends StatefulWidget {
  final Map<String, dynamic> brigadaData;

  const BrigadistaReportesTab({Key? key, required this.brigadaData}) : super(key: key);

  @override
  State<BrigadistaReportesTab> createState() => _BrigadistaReportesTabState();
}

class _BrigadistaReportesTabState extends State<BrigadistaReportesTab> {
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
        .obtenerReportesStream(reportesIds, soloActivos: true)
        .listen((reportes) {
      setState(() {
        _reportes = reportes;
        _loading = false;
      });
    }, onError: (error) {
      print('Error escuchando reportes: $error');
      setState(() {
        _loading = false;
      });
    });
  }

  Future<void> _refrescarReportes() async {
    setState(() {
      _loading = true;
    });
    _escucharReportes();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: backgroundDecoration,
      child: _loading
          ? const Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      )
          : _reportes.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay reportes activos',
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
            return _buildReporteCard(reporte);
          },
        ),
      ),
    );
  }

  Widget _buildReporteCard(ReporteModel reporte) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _mostrarDetalleReporte(reporte);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reporte.categoria,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildEstadoBadge(reporte.estado),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reporte.direccion,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Folio: ${reporte.folio ?? reporte.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _mostrarDetalleReporte(reporte),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver detalles'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color color;
    String texto;

    switch (estado.toLowerCase()) {
      case 'asignado':
        color = Colors.orange;
        texto = 'Asignado';
        break;
      case 'en_proceso':
      case 'en proceso':
        color = Colors.purple;
        texto = 'En Proceso';
        break;
      default:
        color = Colors.grey;
        texto = 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _mostrarDetalleReporte(ReporteModel reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DetalleReporteSheet(
        reporte: reporte,
        onActualizar: _refrescarReportes,
      ),
    );
  }
}

// ================================================
// ✅ TAB DE REPORTES RESUELTOS
// ================================================
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
      setState(() {
        _reportes = reportes;
        _loading = false;
      });
    }, onError: (error) {
      print('Error escuchando reportes: $error');
      setState(() {
        _loading = false;
      });
    });
  }

  Future<void> _refrescarReportes() async {
    setState(() {
      _loading = true;
    });
    _escucharReportes();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: backgroundDecoration,
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
            return _buildReporteCard(reporte);
          },
        ),
      ),
    );
  }

  Widget _buildReporteCard(ReporteModel reporte) {
    String fechaTexto = 'Sin fecha';
    if (reporte.fechaResolucion != null) {
      try {
        final fecha = reporte.fechaResolucion!.toDate();
        fechaTexto = '${fecha.day}/${fecha.month}/${fecha.year}';
      } catch (e) {
        fechaTexto = 'Fecha inválida';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _mostrarDetalleReporte(reporte);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reporte.categoria,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Resuelto',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reporte.direccion,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Resuelto: $fechaTexto',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Folio: ${reporte.folio ?? reporte.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _mostrarDetalleReporte(reporte),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Ver detalles'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleReporte(ReporteModel reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DetalleReporteResueltosSheet(reporte: reporte),
    );
  }
}

// ================================================
// 📄 SHEET DE DETALLE (Solo lectura para resueltos)
// ================================================
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reporte.categoria,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Folio: ${reporte.folio ?? reporte.id}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildInfoItem(
                      Icons.location_on,
                      'Dirección',
                      reporte.direccion,
                    ),
                    _buildInfoItem(
                      Icons.description,
                      'Descripción',
                      reporte.descripcion,
                    ),
                    _buildInfoItem(
                      Icons.person,
                      'Reportado por',
                      reporte.nombreUsuario ?? 'Usuario desconocido',
                    ),

                    // Mostrar evidencias
                    if (reporte.evidencias != null && reporte.evidencias!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Evidencias fotográficas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: reporte.evidencias!.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(reporte.evidencias![index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Botón para Google Maps
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (reporte.ubicacion != null) {
                      _abrirGoogleMaps(context, reporte.ubicacion!.latitude, reporte.ubicacion!.longitude);
                    } else {
                      _abrirGoogleMapsPorDireccion(context, reporte.direccion);
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Ver ubicación en Google Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirGoogleMaps(BuildContext context, double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/@$lat,$lng,17z');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  Future<void> _abrirGoogleMapsPorDireccion(BuildContext context, String direccion) async {
    if (direccion.isEmpty || direccion == 'Sin dirección') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este reporte no tiene ubicación disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final encodedAddress = Uri.encodeComponent(direccion);
    final url = Uri.parse('https://www.google.com/maps/search/$encodedAddress/@0,0,15z');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }
}

// ================================================
// 📝 SHEET DE DETALLE CON ACCIONES
// ================================================
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                widget.reporte.categoria,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Folio: ${widget.reporte.folio ?? widget.reporte.id}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              // Progreso de subida
              if (_subiendoImagenes)
                Container(
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
                              'Subiendo imágenes... ${(_progresoSubida * 100).toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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

              if (_subiendoImagenes) const SizedBox(height: 16),

              // Contenido
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildInfoItem(
                      Icons.location_on,
                      'Dirección',
                      widget.reporte.direccion,
                    ),
                    _buildInfoItem(
                      Icons.description,
                      'Descripción',
                      widget.reporte.descripcion,
                    ),
                    _buildInfoItem(
                      Icons.person,
                      'Reportado por',
                      widget.reporte.nombreUsuario ?? 'Usuario desconocido',
                    ),

                    // Imágenes seleccionadas
                    if (_imagenesEvidencia.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Evidencia fotográfica',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _imagenesEvidencia.length < 2
                                ? () => _seleccionarImagenes()
                                : null,
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: Text('${_imagenesEvidencia.length}/2'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagenesEvidencia.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_imagenesEvidencia[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _imagenesEvidencia.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Acciones
              const SizedBox(height: 16),

              // Botón Google Maps
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (widget.reporte.ubicacion != null) {
                      _abrirGoogleMaps(widget.reporte.ubicacion!.latitude, widget.reporte.ubicacion!.longitude);
                    } else {
                      _abrirGoogleMapsPorDireccion(widget.reporte.direccion);
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Ver ubicación en Google Maps'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Botón actualizar estado
              if (!widget.reporte.esResuelto)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _subiendoImagenes ? null : () async {
                      await _manejarActualizacionEstado(context, widget.reporte);
                    },
                    icon: _subiendoImagenes
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.check_circle),
                    label: Text(_subiendoImagenes ? 'Procesando...' : _getTextoBoton(widget.reporte.estado)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTextoBoton(String estado) {
    switch (estado.toLowerCase()) {
      case 'asignado':
        return 'Iniciar Trabajo';
      case 'en_proceso':
      case 'en proceso':
        return 'Marcar como Resuelto';
      default:
        return 'Actualizar Estado';
    }
  }

  Future<void> _abrirGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/@$lat,$lng,17z');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  Future<void> _abrirGoogleMapsPorDireccion(String direccion) async {
    if (direccion.isEmpty || direccion == 'Sin dirección') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este reporte no tiene ubicación disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final encodedAddress = Uri.encodeComponent(direccion);
    final url = Uri.parse('https://www.google.com/maps/search/$encodedAddress/@0,0,15z');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  Future<void> _seleccionarImagenes() async {
    try {
      final List<XFile> imagenes = await _picker.pickMultiImage(
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 40,
      );

      if (imagenes.isEmpty) return;

      final espacioDisponible = 2 - _imagenesEvidencia.length;
      if (espacioDisponible <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya tienes 2 imágenes seleccionadas'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final imagenesParaAgregar = imagenes.take(espacioDisponible).toList();

      for (var xfile in imagenesParaAgregar) {
        setState(() {
          _imagenesEvidencia.add(File(xfile.path));
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seleccionadas ${_imagenesEvidencia.length}/2 imágenes'),
            backgroundColor: _imagenesEvidencia.length < 2 ? Colors.blue : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imágenes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _manejarActualizacionEstado(BuildContext context, ReporteModel reporte) async {
    if (reporte.esAsignado) {
      // Cambiar a en_proceso
      final exito = await _brigadaService.actualizarEstadoReporte(reporte.id, 'en_proceso');

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Trabajo iniciado'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        widget.onActualizar();
      }
    } else if (reporte.esEnProceso) {
      // Marcar como resuelto (requiere evidencias)
      if (_imagenesEvidencia.length < 2) {
        final confirmado = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Evidencia Requerida'),
            content: const Text(
              'Para marcar este reporte como resuelto, debes agregar al menos 2 fotografías de evidencia.\n\n'
                  '¿Deseas seleccionar las fotos ahora?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                ),
                child: const Text('Seleccionar fotos'),
              ),
            ],
          ),
        );

        if (confirmado != true) return;

        await _seleccionarImagenes();

        if (_imagenesEvidencia.length < 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se requieren al menos 2 imágenes para continuar'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      try {
        setState(() {
          _subiendoImagenes = true;
          _progresoSubida = 0.0;
        });

        // Subir imágenes usando el service
        final urlsImagenes = await _brigadaService.subirImagenesEvidencia(
          reporte.id,
          _imagenesEvidencia,
          onProgress: (progreso) {
            setState(() {
              _progresoSubida = progreso;
            });
          },
        );

        // Actualizar estado
        final exito = await _brigadaService.actualizarEstadoReporte(
          reporte.id,
          'resuelto',
          urlsEvidencias: urlsImagenes,
        );

        if (exito && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Reporte resuelto correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
          widget.onActualizar();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _subiendoImagenes = false;
            _progresoSubida = 0.0;
          });
        }
      }
    }
  }
}

// ================================================
// 👤 TAB DE PERFIL
// ================================================
class BrigadistaPerfilTab extends StatelessWidget {
  const BrigadistaPerfilTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: backgroundDecoration,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: kPrimaryColor,
                      child: Text(
                        user?.email?.substring(0, 1).toUpperCase() ?? 'B',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.email ?? 'Usuario',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Chip(
                      label: Text(
                        'Brigadista',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: kPrimaryColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await authViewModel.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}