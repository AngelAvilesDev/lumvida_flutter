import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lumvida_app/shared/utils/constants.dart';
import 'package:lumvida_app/shared/viewmodels/AuthViewModel.dart';
import 'package:provider/provider.dart';
import '../viewmodels/NotificacionesViewModel.dart';
import '../screens/NotificacionesScreen.dart';

class WelcomeHeader extends StatelessWidget {
  final AuthViewModel authViewModel;

  const WelcomeHeader({Key? key, required this.authViewModel}) : super(key: key);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9), // Changed withValues to withOpacity for compatibility if needed, or keeping withValues if strict API is preferred. Assuming withValues is valid for the user's Flutter version based on previous code.
        // Actually, let's stick to the user's established pattern if possible, but standard is withOpacity usually.
        // The user code used `withValues(alpha: .9)`. I will use that to match their SDK version style.
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar o icono de usuario
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimaryColor, Color(0xFFD32F2F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: kPrimaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: authViewModel.user?.photoURL != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: CachedNetworkImage(
                      imageUrl: authViewModel.user!.photoURL!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Padding(
                        padding: EdgeInsets.all(15.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 30),
          ),

          const SizedBox(width: 16),

          // Información del usuario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authViewModel.isAuthenticated
                      ? (authViewModel.nombreUsuario ?? authViewModel.user?.displayName ?? 'Usuario')
                      : 'Invitado',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                if (!authViewModel.isAuthenticated)
                  Text(
                    'Inicia sesión para mejor experiencia',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),

          // Icono de notificaciones
          Consumer<NotificacionesViewModel>(
            builder: (context, notifViewModel, child) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificacionesScreen(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: kPrimaryColor,
                        size: 24,
                      ),
                    ),
                    if (notifViewModel.noLeidasCount > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${notifViewModel.noLeidasCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
