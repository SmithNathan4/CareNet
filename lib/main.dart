import 'package:carenet/services/firebase/firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Pages/Authentification/login.dart';
import 'Pages/Page_Doctor/HomeDoctor.dart';
import 'Pages/Page_Patient/home.dart';
import 'services/firebase/firebase_options.dart';
import 'services/firebase/auth.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Erreur lors de l'initialisation de Firebase: $e");
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'CareNet',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const AuthWrapper(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  String? _initialRoute;
  Map<String, dynamic>? _userData;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final userData = await _authService.checkAuthState();
      
      if (userData != null) {
        setState(() {
          _userData = userData;
          _initialRoute = userData['userType'] == 'doctor' ? AppRoutes.homeDoctor : AppRoutes.home;
          _isLoading = false;
        });
      } else {
        setState(() {
          _initialRoute = AppRoutes.login;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors de la vérification de l\'état d\'authentification: $e');
      setState(() {
        _initialRoute = AppRoutes.login;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CareNet',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4285F4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Rediriger vers la page appropriée
    if (_initialRoute == AppRoutes.home && _userData != null) {
      return Home(
        userName: _userData!['name'],
        userPhoto: _userData!['photoUrl'],
        userId: _userData!['uid'],
        firestoreService: FirestoreService(),
      );
    } else if (_initialRoute == AppRoutes.homeDoctor && _userData != null) {
      return HomeDoctor(
        firestoreService: FirestoreService(),
      );
    } else {
      return const Login();
    }
  }
}