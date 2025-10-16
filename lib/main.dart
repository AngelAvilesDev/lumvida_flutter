import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lumvida_app/shared/screens/LoginScreen.dart';
import 'package:lumvida_app/shared/screens/RegisterScreen.dart';
import 'package:lumvida_app/shared/utils/api_config.dart';
import 'package:lumvida_app/shared/utils/constants.dart';
import 'package:lumvida_app/shared/viewmodels/AuthViewModel.dart';
import 'package:provider/provider.dart';
import 'cliente/screens/InicioScreen.dart';
import 'cliente/screens/MapScreen.dart';
import 'cliente/screens/MisReportesScreen.dart';
import 'cliente/screens/ProfileScreen.dart';
import 'brigadistas/screens/BrigadistaInicioScreen.dart'; // ← AÑADIDO
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // CARGAR VARIABLES DE ENTORNO PRIMERO
    await dotenv.load(fileName: ".env");
    if (kDebugMode) {
      print('✅ Variables de entorno cargadas correctamente');
    }

    // VERIFICAR QUE LAS API KEYS ESTÉN DISPONIBLES
    ApiConfig.debugApiKeys(); // Mostrar status de las API keys

    if (!ApiConfig.areKeysConfigured) {
      if (kDebugMode) {
        print('⚠️  ADVERTENCIA: Algunas API keys no están configuradas correctamente');
      }
    }

    // INICIALIZAR FIREBASE
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('✅ Firebase inicializado correctamente');
    }

    // CONFIGURAR ORIENTACIÓN PREFERIDA
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

  } catch (e) {
    if (kDebugMode) {
      print('❌ Error al inicializar la aplicación: $e');
    }
    // La app continuará pero mostrará errores donde sea necesario
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthViewModel(),
      child: MaterialApp(
        title: 'LumVida',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: kPrimaryColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimaryColor,
            primary: kPrimaryColor,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: kPrimaryColor),
            titleTextStyle: TextStyle(
              color: kPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: kPrimaryButtonStyle,
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: kOutlinedButtonStyle,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          fontFamily: 'Roboto',
        ),
        // ← CAMBIADO: Usar AuthGate en lugar de StreamBuilder
        home: const AuthGate(),
        routes: {
          '/register': (context) => const RegisterScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const InicioScreen(),
          '/inicio': (context) => const InicioScreen(),
          '/mapa': (context) => const MapScreen(),
          '/perfil': (context) => const ProfileScreen(),
          '/mis_reportes': (context) => const MisReportesScreen(),
          '/brigadista': (context) => const BrigadistaInicioScreen(), // ← AÑADIDO
        },
      ),
    );
  }
}

// ========================================
// 🚪 AUTH GATE - Verifica autenticación y rol
// ========================================
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Mientras se carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: kPrimaryColor,
              ),
            ),
          );
        }

        // No hay usuario - ir al login
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // Hay usuario - verificar su rol
        return FutureBuilder<Widget>(
          future: _getHomeScreen(snapshot.data!),
          builder: (context, homeSnapshot) {
            if (homeSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 80,
                        color: kPrimaryColor,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'LumVida',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const CircularProgressIndicator(
                        color: kPrimaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verificando sesión...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Retornar la pantalla correspondiente
            return homeSnapshot.data ?? const InicioScreen();
          },
        );
      },
    );
  }

  Future<Widget> _getHomeScreen(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final role = userData?['role']?.toString().trim().toLowerCase() ?? '';
        final rol = userData?['rol']?.toString().trim().toLowerCase() ?? '';

        final esBrigadista = role == 'brigadista' || rol == 'brigadista';

        if (kDebugMode) {
          print('🔍 Usuario: ${user.email}');
          print('🎯 Role: $role');
          print('🎯 Es brigadista: $esBrigadista');
        }

        if (esBrigadista) {
          return const BrigadistaInicioScreen();
        } else {
          return const InicioScreen();
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No se encontró documento para el usuario: ${user.uid}');
        }
        // Si no hay documento, ir a cliente por defecto
        return const InicioScreen();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al verificar rol: $e');
      }
      // En caso de error, ir a cliente por defecto
      return const InicioScreen();
    }
  }
}