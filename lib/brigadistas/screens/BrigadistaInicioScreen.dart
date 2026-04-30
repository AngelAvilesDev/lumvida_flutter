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
    if (mounted) {
      setState(() {
        _brigadaData = brigada;
        _loadingBrigada = false;
      });
    }
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

    final List<Widget> screens = [
      BrigadistaHomeTab(brigadaData: _brigadaData!),
      BrigadistaReportesTab(brigadaData: _brigadaData!),
      BrigadistaResueltosTab(brigadaData: _brigadaData!),
      const BrigadistaPerfilTab(),
    ];

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
              _buildModernHeader(),
              Expanded(child: screens[_selectedIndex]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.6),
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

  Widget _buildModernHeader() {
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
              _brigadaData!['nombre'] ?? 'Brigadista',
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
