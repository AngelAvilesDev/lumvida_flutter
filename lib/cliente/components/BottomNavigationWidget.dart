import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../screens/InicioScreen.dart';
import '../screens/MapScreen.dart';
import '../screens/ProfileScreen.dart';

class BottomNavigationWidget extends StatelessWidget {
  final String currentScreen; // Para saber qué pantalla está activa

  const BottomNavigationWidget({
    Key? key,
    required this.currentScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) => Container(
        decoration: const BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón de Inicio (Casa)
                _buildNavigationButton(
                  context: context,
                  icon: Icons.home,
                  isActive: currentScreen == 'inicio',
                  onPressed: () => _navigateToScreen(context, 'inicio'),
                ),

                // Separador visual
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),

                // Botón de Mapa
                _buildNavigationButton(
                  context: context,
                  icon: Icons.map,
                  isActive: currentScreen == 'mapa',
                  onPressed: () => _navigateToScreen(context, 'mapa'),
                ),

                // Separador visual
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),

                // Botón de Perfil
                _buildNavigationButton(
                  context: context,
                  icon: Icons.person,
                  isActive: currentScreen == 'perfil',
                  onPressed: () => _handleProfileNavigation(context, authViewModel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required BuildContext context,
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                  size: isActive ? 28 : 24,
                ),
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 3,
                    width: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, String screenName) {
    // Permitir recargar o ir a inicio siempre
    //if (currentScreen == screenName) return;

    switch (screenName) {
      case 'inicio':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const InicioScreen()),
              (route) => false,
        );
        break;
      case 'mapa':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
              (route) => false,
        );
        break;
    }
  }

  void _handleProfileNavigation(BuildContext context, AuthViewModel authViewModel) {
    if (currentScreen == 'perfil') return; // Ya estamos en perfil

    if (authViewModel.isAuthenticated) {
      // Usuario autenticado - ir a perfil
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
            (route) => false,
      );
    } else {
      // Usuario no autenticado - mostrar opciones
      _showGuestUserDialog(context);
    }
  }

  void _showGuestUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          actionsPadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: kPrimaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para acceder a tu perfil y ver tus reportes necesitas iniciar sesión.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '¿Te gustaría iniciar sesión ahora?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              width: double.infinity,
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.pushNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}