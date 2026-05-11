import 'package:flutter/material.dart';
import '../../shared/utils/constants.dart';
import '../services/BrigadaService.dart';
import '../tabs/BrigadistaHomeTab.dart';
import '../tabs/BrigadistaReportesTab.dart';
import '../tabs/BrigadistaResueltosTab.dart';
import '../tabs/BrigadistaPerfilTab.dart';

// ================================================
// 🏠 PANTALLA PRINCIPAL DE BRIGADISTA (Shell)
// ================================================
class BrigadistaInicioScreen extends StatefulWidget {
  const BrigadistaInicioScreen({Key? key}) : super(key: key);

  @override
  State<BrigadistaInicioScreen> createState() => _BrigadistaInicioScreenState();
}

class _BrigadistaInicioScreenState extends State<BrigadistaInicioScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _lastBrigadaData;
  final BrigadaService _brigadaService = BrigadaService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _brigadaService.obtenerBrigadaDelUsuarioStream(),
      builder: (context, snapshot) {
        // Si está cargando y no tenemos datos previos, mostrar spinner
        if (snapshot.connectionState == ConnectionState.waiting && _lastBrigadaData == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        // Si hay un error, mostrarlo
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final brigadaData = snapshot.data;

        // Si no hay brigada asignada
        if (brigadaData == null) {
          return _buildNoBrigadaScreen();
        }

        // Cachear datos para evitar saltos visuales en la reconstrucción del IndexedStack
        _lastBrigadaData = brigadaData;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.95),
                  kPrimaryColor.withValues(alpha: 0.03),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildModernHeader(brigadaData),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        BrigadistaHomeTab(brigadaData: brigadaData),
                        BrigadistaReportesTab(brigadaData: brigadaData),
                        BrigadistaResueltosTab(brigadaData: brigadaData),
                        const BrigadistaPerfilTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildNoBrigadaScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LumVida - Brigadista'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange.shade300),
              const SizedBox(height: 24),
              const Text(
                'No perteneces a ninguna brigada',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Contacta al administrador para ser asignado a un equipo de trabajo.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.6),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Reportes'),
            BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Resueltos'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(Map<String, dynamic> brigadaData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Brigadista',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF880E4F),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              brigadaData['nombre'] ?? 'Brigadista',
              style: const TextStyle(
                color: Color(0xFF880E4F),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
