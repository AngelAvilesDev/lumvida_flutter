import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/utils/constants.dart';
import '../../shared/viewmodels/AuthViewModel.dart';
import '../viewmodels/NotificacionesViewModel.dart';
import '../utils/report_categories.dart';
import '../components/BottomNavigationWidget.dart';
import '../components/WelcomeHeader.dart';
import '../components/HistorialButton.dart';
import '../components/SectionTitle.dart';
import '../components/CategoriesGrid.dart';
import '../components/InfoSection.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({Key? key}) : super(key: key);

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Iniciar animaciones
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _slideController.forward();
      }
    });

    // Check auth state just in case, but usually handled by AuthGate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      authVM.checkAuthState();
      if (authVM.isAuthenticated && authVM.user != null) {
        Provider.of<NotificacionesViewModel>(context, listen: false)
            .iniciarEscuchaReportes(authVM.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use select to listen only when user changes, avoiding unnecessary rebuilds of the whole scaffold
    // if only a small property changed. However, for now, normal Provider.of is fine as ViewModel notifies on major changes.
    // Optimizing rebuilds:
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    // Memoizing calculation inputs is not strictly necessary here unless categories change often,
    // but extracting logic to top level or initState is better. 
    // Since ReportCategories are static, we calculate active categories once.
    
    final activeCategories = ReportCategories.getActiveCategories();
    // Optimization: Calculate these once or in a builder if they depended on screen size (LayoutBuilder)
    // For now keeping simple but cleaner.
    final optimalColumns = ReportCategories.getOptimalColumns(activeCategories.length);
    final aspectRatio = ReportCategories.getChildAspectRatio(activeCategories.length);

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.8),
                Colors.white.withOpacity(0.95),
                kPrimaryColor.withOpacity(0.03),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con saludo
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: WelcomeHeader(authViewModel: authViewModel),
                  ),

                  const SizedBox(height: 32),

                  // Botón de historial de reportes
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: HistorialButton(authViewModel: authViewModel),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Título de categorías
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const SectionTitle('Reportar problema'),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Grid de categorías (flexible y automático)
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: CategoriesGrid(
                        categories: activeCategories,
                        columns: optimalColumns,
                        aspectRatio: aspectRatio,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Información adicional o estadísticas (opcional)
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const InfoSection(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigationWidget(currentScreen: 'inicio'),
    );
  }
}