import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Importação das telas
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/coleta_screen.dart';
import 'screens/embarcacao_screen.dart';
import 'screens/perfil_screen.dart';

// Cores personalizadas
class MarinautaColors {
  static const azulMarinho = Color(0xFF001F3D);
  static const azulOceano = Color(0xFF003D66);
  static const azulProfundo = Color(0xFF00294D);
  static const azulCiano = Color(0xFF00B4D8);
  static const brancoEspuma = Color(0xFFFFFFFF);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MarinautaApp());
}

class MarinautaApp extends StatelessWidget {
  const MarinautaApp({super.key});

  @override
  Widget build(BuildContext context) {
    const azul = MarinautaColors.azulProfundo;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monitor da Pesca – Marinauta',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: azul,
          secondary: azul,
        ),

        // 🔹 Tema padrão de todos os campos de texto e dropdowns
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(
            color: azul,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(color: azul),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: azul, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: azul, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: azul),
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // 🔹 Tema de botões
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azul,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
        ),

        // 🔹 Textos gerais
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: azul),
          bodyLarge: TextStyle(color: azul),
          titleMedium: TextStyle(color: azul),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: azul,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: azul),
        ),

        useMaterial3: true,
      ),

      // 🔹 Rotas
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/coleta': (_) => const ColetaScreen(
              coletorEmail: '',
              municipio: '',
              entreposto: '',
            ),
        '/embarcacao': (_) => const EmbarcacaoScreen(),
        '/perfil': (_) => const PerfilScreen(),
      },
    );
  }
}
