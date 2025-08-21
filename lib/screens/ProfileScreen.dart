import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/CustomDialogs.dart';
import '../utils/constants.dart';
import '../viewmodels/AuthViewModel.dart';
import '../components/BottomNavigationWidget.dart';
import 'LoginScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    _nameController.text = authViewModel.nombreUsuario ?? '';
    _phoneController.text = authViewModel.telefono ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil', style: TextStyle(color: kPrimaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Quitar botón de regreso
        actions: [
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, _) {
              if (!authViewModel.isAuthenticated) return const SizedBox();

              return IconButton(
                icon: Icon(
                  _isEditing ? Icons.save : Icons.edit,
                  color: kPrimaryColor,
                ),
                onPressed: _isEditing ? _saveProfile : _enableEditing,
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: backgroundDecoration,
        child: Consumer<AuthViewModel>(
          builder: (context, authViewModel, _) {
            if (!authViewModel.isAuthenticated) {
              return _buildNotLoggedInView();
            }
            return _buildProfileView(authViewModel);
          },
        ),
      ),
      bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'perfil'),
    );
  }

  Widget _buildNotLoggedInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Inicia sesión para ver tu perfil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Accede a tu cuenta para ver y editar tu información personal',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: kPrimaryButtonStyle,
              icon: const Icon(Icons.login),
              label: const Text('Iniciar Sesión', style: kButtonTextStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView(AuthViewModel authViewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar y nombre principal
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                  child: authViewModel.user?.photoURL != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      authViewModel.user!.photoURL!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 60,
                          color: kPrimaryColor,
                        );
                      },
                    ),
                  )
                      : const Icon(
                    Icons.person,
                    size: 60,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  authViewModel.nombreUsuario ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authViewModel.user?.email ?? 'Sin email',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Información del perfil
          _buildSectionTitle('Información Personal'),
          const SizedBox(height: 16),

          // Campo de nombre
          _buildInfoField(
            label: 'Nombre completo',
            controller: _nameController,
            icon: Icons.person_outline,
            enabled: _isEditing,
          ),

          const SizedBox(height: 16),

          // Campo de teléfono
          _buildInfoField(
            label: 'Teléfono',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          // Email (no editable)
          _buildInfoField(
            label: 'Correo electrónico',
            initialValue: authViewModel.user?.email ?? '',
            icon: Icons.email_outlined,
            enabled: false,
          ),

          const SizedBox(height: 40),

          // Estadísticas
          _buildSectionTitle('Estadísticas'),
          const SizedBox(height: 16),
          _buildStatsSection(),

          const SizedBox(height: 40),

          // Acciones
          _buildSectionTitle('Acciones'),
          const SizedBox(height: 16),
          _buildActionsSection(authViewModel),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: kPrimaryColor,
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: enabled ? kPrimaryColor : Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.report_outlined,
              title: 'Reportes',
              value: '0', // TODO: Implementar contador real
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.check_circle_outline,
              title: 'Resueltos',
              value: '0', // TODO: Implementar contador real
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.pending_outlined,
              title: 'Pendientes',
              value: '0', // TODO: Implementar contador real
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(AuthViewModel authViewModel) {
    return Column(
      children: [
        // Botón Ver mis reportes
        _buildActionButton(
          icon: Icons.list_alt,
          title: 'Ver mis reportes',
          subtitle: 'Historial completo de reportes',
          onTap: () {
            Navigator.pushNamed(context, '/mis_reportes');
          },
        ),

        const SizedBox(height: 12),

        // Botón Cerrar sesión
        _buildActionButton(
          icon: Icons.logout,
          title: 'Cerrar sesión',
          subtitle: 'Salir de tu cuenta',
          onTap: () => _showLogoutDialog(authViewModel),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : kPrimaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _enableEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _saveProfile() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    setState(() {
      _isEditing = false;
    });

    // TODO: Implementar guardado de perfil
    // Por ahora solo actualizar el teléfono si es diferente
    if (_phoneController.text != authViewModel.telefono) {
      final success = await authViewModel.updateUserPhone(_phoneController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Perfil actualizado correctamente'
                  : 'Error al actualizar el perfil',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(AuthViewModel authViewModel) {
    CustomDialogs.showLogoutDialog(
      context: context,
      onConfirm: () async {
        // Mostrar loading
        CustomDialogs.showLoadingDialog(
          context: context,
          message: 'Cerrando sesión...',
        );

        try {
          await authViewModel.signOut();

          // Cerrar loading
          if (mounted) {
            CustomDialogs.hideLoadingDialog(context);

            // Mostrar confirmación con SnackBar elegante
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Sesión cerrada correctamente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          // Cerrar loading en caso de error
          if (mounted) {
            CustomDialogs.hideLoadingDialog(context);

            // Mostrar error
            CustomDialogs.showErrorDialog(
              context: context,
              title: 'Error al cerrar sesión',
              content: 'No se pudo cerrar la sesión. Por favor, inténtalo de nuevo.\n\nError: $e',
            );
          }
        }
      },
    );
  }

// Ejemplo de otros usos:

// Para confirmar eliminación:
  void _showDeleteConfirmation() {
    CustomDialogs.showDeleteDialog(
      context: context,
      title: 'Eliminar reporte',
      content: '¿Estás seguro de que quieres eliminar este reporte?',
      onConfirm: () {
        // Lógica para eliminar
      },
    );
  }

// Para mostrar éxito:
  void _showSuccess() {
    CustomDialogs.showSuccessDialog(
      context: context,
      title: '¡Perfil actualizado!',
      content: 'Tu información se ha guardado correctamente.',
      onPressed: () {
        // Acción opcional después del éxito
      },
    );
  }

// Para mostrar error:
  void _showError(String error) {
    CustomDialogs.showErrorDialog(
      context: context,
      title: 'Error de validación',
      content: 'No se pudo procesar la solicitud:\n\n$error',
    );
  }
}