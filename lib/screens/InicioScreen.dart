import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import 'LoginScreen.dart';
import 'MisReportesScreen.dart';
import 'ReportesScreen.dart';
import 'MapScreen.dart'; // Importamos la pantalla del mapa

class InicioScreen extends StatelessWidget {
  const InicioScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título de bienvenida
                if (authViewModel.isAuthenticated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Text(
                      'Bienvenido ${authViewModel.user?.displayName ?? authViewModel.nombreUsuario ?? 'Usuario'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                // Reporte ciudadano
                const Text(
                  'Reporte ciudadano:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),

                const SizedBox(height: 12),

                // Historial de reportes (botón rojo)
                InkWell(
                  onTap: () {
                    if (authViewModel.isAuthenticated) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MisReportesScreen(),
                        ),
                      );
                    } else {
                      _mostrarDialogoInicioSesionRequerido(context);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Historial de reportes',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Realizar un reporte
                const Text(
                  'Realizar un reporte\nrelacionado con:',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),

                const SizedBox(height: 20),

                // Grid de categorías 2x2
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildCategoryButton(
                        context: context,
                        icon: Icons.car_repair,
                        title: 'Bacheo',
                        categoria: 'Bacheo',
                      ),
                      _buildCategoryButton(
                        context: context,
                        icon: Icons.lightbulb_outline,
                        title: 'Alumbrado\nPúblico',
                        categoria: 'Alumbrado Público',
                      ),
                      _buildCategoryButton(
                        context: context,
                        icon: Icons.delete_outline,
                        title: 'Basura\nAcumulada',
                        categoria: 'Basura Acumulada',
                      ),
                      _buildCategoryButton(
                        context: context,
                        icon: Icons.water_drop,
                        title: 'Drenajes\nObstruidos',
                        categoria: 'Drenajes Obstruidos',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildCategoryButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String categoria,
  }) {
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportesScreen(categoria: categoria),
          )
      ),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) => Container(
        height: 60,
        decoration: const BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            // Dashboard
            const Expanded(
              child: Center(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Separador vertical
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),

            // Iconos de ubicación y perfil
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.location_on, color: Colors.white, size: 24),
                    onPressed: () {
                      // Navegación a la pantalla del mapa
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapScreen())
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.white, size: 24),
                    onPressed: () {
                      if (authViewModel.isAuthenticated) {
                        _mostrarDialogoCerrarSesion(context);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoInicioSesionRequerido(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Iniciar sesión requerido'),
          content: const Text('Para ver tus reportes necesitas iniciar sesión.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar', style: TextStyle(color: kPrimaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final authViewModel = Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                );
                await authViewModel.signOut();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}