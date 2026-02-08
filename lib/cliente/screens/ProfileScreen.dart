import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/components/CustomDialogs.dart';
import '../../shared/screens/LoginScreen.dart';
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../viewmodels/ProfileViewModel.dart';
import '../components/BottomNavigationWidget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  late ProfileViewModel _profileViewModel;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _profileViewModel = ProfileViewModel();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);

    // Cargar datos inmediatamente después del primer frame para tener acceso al context/provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _profileViewModel.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // 1. Obtener datos cacheados de AuthViewModel para mostrarlos YA
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    if (authVM.user != null) {
      _profileViewModel.setInitialData(
        nombre: authVM.nombreUsuario ?? authVM.user!.displayName ?? '',
        telefono: authVM.telefono ?? '',
        email: authVM.user!.email ?? '',
        photoUrl: authVM.photoUrl ?? authVM.user!.photoURL,
      );
      
      // Actualizar controladores UI
      _updateControllers();
      
      // Mostrar contenido inmediatamente
      _fadeController.forward();
    }

    // 2. Iniciar carga en segundo plano para actualizar estadísticas y validar datos
    await _profileViewModel.loadUserData();
    
    // 3. Actualizar UI nuevamente si hubo cambios (como estadísticas)
    if (mounted) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    _nameController.text = _profileViewModel.nombre;
    _phoneController.text = _profileViewModel.telefono;
    _emailController.text = _profileViewModel.email;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _profileViewModel,
      child: Scaffold(
        body: Container(
          decoration: backgroundDecoration,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: .95),
                  kPrimaryColor.withValues(alpha: .03),
                ],
              ),
            ),
            child: SafeArea(
              child: Consumer<ProfileViewModel>(
                builder: (context, profileVM, child) {
                  final authViewModel = Provider.of<AuthViewModel>(context);

                  if (!authViewModel.isAuthenticated) {
                    return _buildNotLoggedInView();
                  }

                  return Column(
                    children: [
                      // Header
                      _buildModernHeader(profileVM),

                      // Contenido principal
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildMainContent(profileVM, authViewModel),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'perfil'),
      ),
    );
  }

  Widget _buildNotLoggedInView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 80,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(ProfileViewModel profileVM) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Perfil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
          ),

          // Botón de editar/guardar
          Container(
            decoration: BoxDecoration(
              color: profileVM.isEditing ? Colors.green.withValues(alpha: .1) : kPrimaryColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: profileVM.isUpdating
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(
                profileVM.isEditing ? Icons.save : Icons.edit,
                color: profileVM.isEditing ? Colors.green : kPrimaryColor,
              ),
              onPressed: profileVM.isUpdating ? null : () {
                if (profileVM.isEditing) {
                  _saveProfile();
                } else {
                  profileVM.toggleEditMode();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ProfileViewModel profileVM, AuthViewModel authViewModel) {
    if (profileVM.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar y información básica
            _buildProfileHeader(profileVM, authViewModel),

            const SizedBox(height: 32),

            // Mensajes de estado
            if (profileVM.errorMessage != null) _buildErrorMessage(profileVM.errorMessage!),
            if (profileVM.successMessage != null) _buildSuccessMessage(profileVM.successMessage!),

            // Información personal
            _buildSectionTitle('Información Personal'),
            const SizedBox(height: 16),
            _buildPersonalInfoSection(profileVM),

            const SizedBox(height: 32),

            // Estadísticas - ACTUALIZADAS
            _buildSectionTitle('Estadísticas'),
            const SizedBox(height: 16),
            _buildStatsSection(profileVM),

            const SizedBox(height: 32),

            // Acciones de cuenta
            _buildSectionTitle('Configuración de Cuenta'),
            const SizedBox(height: 16),
            _buildAccountActionsSection(authViewModel, profileVM),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ProfileViewModel profileVM, AuthViewModel authViewModel) {
    return Center(
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kPrimaryColor, Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: .3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: profileVM.selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.file(
                    profileVM.selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
                    : profileVM.localPhotoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.file(
                              File(profileVM.localPhotoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback a foto de red si falla el archivo local
                                if (profileVM.photoUrl != null) {
                                  return CachedNetworkImage(
                                    imageUrl: profileVM.photoUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Icon(Icons.person, size: 60, color: Colors.white),
                                    errorWidget: (context, url, error) => const Icon(Icons.person, size: 60, color: Colors.white),
                                  );
                                }
                                return const Icon(Icons.person, size: 60, color: Colors.white);
                              },
                            ),
                          )
                    : profileVM.photoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: CachedNetworkImage(
                          imageUrl: profileVM.photoUrl!,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 500),
                          fadeOutDuration: const Duration(milliseconds: 300),
                          placeholder: (context, url) => Container(
                            color: Colors.transparent, // Transparent to show gradient behind if needed, or grey to show loading area
                            // Actually, parent has gradient. If we use transparent, we see gradient.
                            // But usually we want to show 'loading'.
                            // User complained about "sudden pop". 
                            // Best approach: Show the generic "User Icon" while loading, so it looks like "Default -> Image".
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white54,
                                ),
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white,
                ),
              ),

              // Botón de editar foto
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: kPrimaryColor, size: 20),
                    onPressed: () => _showImageOptions(profileVM),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Nombre
          Text(
            profileVM.nombre.isNotEmpty ? profileVM.nombre : 'Usuario',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(ProfileViewModel profileVM) {
    return Column(
      children: [
        // Campo de nombre
        _buildModernTextField(
          controller: _nameController,
          label: 'Nombre completo',
          icon: Icons.person_outlined,
          enabled: profileVM.isEditing,
          validator: profileVM.validateName,
          textCapitalization: TextCapitalization.words,
        ),

        const SizedBox(height: 16),

        // Campo de teléfono
        _buildModernTextField(
          controller: _phoneController,
          label: 'Teléfono (10 dígitos)',
          icon: Icons.phone_outlined,
          enabled: profileVM.isEditing,
          validator: profileVM.validatePhone,
          keyboardType: TextInputType.phone,
          onChanged: (value) {
            final formatted = profileVM.formatPhone(value);
            if (formatted != value) {
              _phoneController.text = formatted;
              _phoneController.selection = TextSelection.fromPosition(
                TextPosition(offset: formatted.length),
              );
            }
          },
        ),

        const SizedBox(height: 16),

        // Campo de email (no editable)
        _buildModernTextField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
          enabled: false,
        ),
      ],
    );
  }

  // ESTADÍSTICAS ACTUALIZADAS - NUEVO DISEÑO CON 4 MÉTRICAS
  Widget _buildStatsSection(ProfileViewModel profileVM) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Primera fila - Total y Resueltos
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.report_outlined,
                  title: 'Reportes',
                  value: profileVM.totalReportes.toString(),
                  color: kPrimaryColor,
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
                  value: profileVM.reportesResueltos.toString(),
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),

          const SizedBox(height: 16),

          // Segunda fila - En Proceso y Pendientes
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.sync,
                  title: 'En Proceso',
                  value: profileVM.reportesEnProceso.toString(),
                  color: Colors.orange.shade600,
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
                  value: profileVM.reportesPendientes.toString(),
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActionsSection(AuthViewModel authViewModel, ProfileViewModel profileVM) {
    return Column(
      children: [
        // Ver mis reportes
        _buildActionButton(
          icon: Icons.list_alt,
          title: 'Ver mis reportes',
          subtitle: 'Historial completo de reportes',
          onTap: () {
            Navigator.pushNamed(context, '/mis_reportes');
          },
        ),

        const SizedBox(height: 12),

        // Cerrar sesión
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

  Widget _buildModernTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    required bool enabled,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        validator: validator,
        onChanged: onChanged,
        maxLines: 1,
        style: TextStyle(
          fontSize: (controller?.text.length ?? initialValue?.length ?? 0) > 25 ? 13 : 16,
          fontWeight: FontWeight.w500,
          color: enabled ? Colors.black87 : Colors.grey.shade600,
          overflow: TextOverflow.ellipsis,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: enabled ? kPrimaryColor.withValues(alpha: .7) : Colors.grey.shade400,
          ),
          labelStyle: TextStyle(
            color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
            fontSize: 16,
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.red.withValues(alpha: .1)
                        : kPrimaryColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
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
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Métodos de acción

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _profileViewModel.updateUserData(
      nombre: _nameController.text.trim(),
      telefono: _phoneController.text.trim(),
    );

    if (success) {
      // Actualizar también en AuthViewModel para consistencia
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      await authViewModel.checkAuthState();
    }
  }

  void _showImageOptions(ProfileViewModel profileVM) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Cambiar foto de perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildImageOptionButton(
                              icon: Icons.photo_library,
                              title: 'Galería',
                              onTap: () {
                                Navigator.pop(context);
                                profileVM.selectProfileImage(source: ImageSource.gallery);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildImageOptionButton(
                              icon: Icons.camera_alt,
                              title: 'Cámara',
                              onTap: () {
                                Navigator.pop(context);
                                profileVM.selectProfileImage(source: ImageSource.camera);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageOptionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(icon, color: kPrimaryColor, size: 32),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(AuthViewModel authViewModel) {
    CustomDialogs.showLogoutDialog(
      context: context,
      onConfirm: () async {
        try {
          await authViewModel.signOut();
          // No mostrar SnackBar aquí para evitar problemas de widget lifecycle
          // El AuthViewModel ya maneja el cambio de estado
        } catch (e) {
          // Solo mostrar error si el widget aún está montado
          if (mounted) {
            CustomDialogs.showErrorDialog(
              context: context,
              title: 'Error al cerrar sesión',
              content: 'No se pudo cerrar la sesión. Por favor, inténtalo de nuevo.',
            );
          }
        }
      },
    );
  }
}