import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lumvida_app/screens/RegisterScreen.dart';
import 'package:lumvida_app/screens/ProfileScreen.dart';
import 'package:lumvida_app/screens/MapScreen.dart';
import 'package:lumvida_app/screens/MisReportesScreen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'viewmodels/AuthViewModel.dart';
import 'screens/InicioScreen.dart';
import 'screens/LoginScreen.dart';
import 'utils/constants.dart';
import 'utils/api_config.dart'; // IMPORTAR LA CONFIGURACIÓN DE API
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
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              return snapshot.hasData ? const InicioScreen() : const LoginScreen();
            }
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: kPrimaryColor,
                ),
              ),
            );
          },
        ),
        routes: {
          '/register': (context) => const RegisterScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const InicioScreen(),
          '/inicio': (context) => const InicioScreen(),
          '/mapa': (context) => const MapScreen(),
          '/perfil': (context) => const ProfileScreen(),
          '/mis_reportes': (context) => const MisReportesScreen(),
        },
      ),
    );
  }
}