import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart';
import '../../services/firebase/firestore.dart';
import '../../services/firebase/auth.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _emailError = '';
  String _passwordError = '';

  // Couleurs professionnelles
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF2196F3);
  static const Color textColor = Color(0xFF333333);
  static const Color subtitleColor = Color(0xFF666666);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF66BB6A);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
    
    // Vérifier si l'utilisateur est déjà connecté
    _checkAuthState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    final authService = AuthService();
    final userData = await authService.checkAuthState();
    
    if (userData != null) {
      // L'utilisateur est déjà connecté, rediriger vers la page appropriée
      if (!mounted) return;
      
      if (userData['userType'] == 'doctor') {
        AppRoutes.navigateToHomeDoctor(
          context,
          doctorName: userData['name'],
          doctorEmail: userData['email'],
          phone: '',
          firestoreService: FirestoreService(),
        );
      } else {
        AppRoutes.navigateToHome(
          context,
          userName: userData['name'],
          userPhoto: userData['photoUrl'],
          userId: userData['uid'],
          firestoreService: FirestoreService(),
        );
      }
    }
  }

  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _emailError = '';
      _passwordError = '';
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Vérifier le rôle de l'utilisateur
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('UserAdmin')
          .doc(userCredential.user?.uid)
          .get();
      if (adminDoc.exists) {
        Navigator.pushReplacementNamed(context, '/admin');
        setState(() => _isLoading = false);
        return;
      }

      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(userCredential.user?.uid)
          .get();

      if (doctorDoc.exists) {
        if (!mounted) return;
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        if (doctorData['active'] == false) {
          setState(() {
            _emailError = 'Votre compte a été bloqué par l\'administrateur.';
            _isLoading = false;
          });
          await _auth.signOut();
          return;
        }
        AppRoutes.navigateToHomeDoctor(
          context,
          doctorName: doctorData['name'] ?? '',
          doctorEmail: doctorData['email'] ?? '',
          phone: doctorData['phone'] ?? '',
          firestoreService: FirestoreService(),
        );
        return;
      }

      DocumentSnapshot patientDoc = await FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(userCredential.user?.uid)
          .get();

      if (patientDoc.exists) {
        if (!mounted) return;
        final patientData = patientDoc.data() as Map<String, dynamic>;
        if (patientData['active'] == false) {
          setState(() {
            _emailError = 'Votre compte a été bloqué par l\'administrateur.';
            _isLoading = false;
          });
          await _auth.signOut();
          return;
        }
        AppRoutes.navigateToHome(
          context,
          userName: patientData['name'] ?? '',
          userPhoto: patientData['photoUrl'] ?? '',
          userId: userCredential.user?.uid ?? '',
          firestoreService: FirestoreService(),
        );
        return;
      }

      // Si aucun rôle n'est trouvé
      setState(() {
        _emailError = 'Compte non trouvé';
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _emailError = 'Aucun utilisateur trouvé avec cet email';
            break;
          case 'wrong-password':
            _passwordError = 'Mot de passe incorrect';
            break;
          case 'invalid-email':
            _emailError = 'Email invalide';
            break;
          default:
            _emailError = 'Une erreur est survenue';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _emailError = 'Une erreur est survenue';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (!mounted) return;

      // Vérifier le rôle de l'utilisateur
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('UserAdmin')
          .doc(userCredential.user?.uid)
          .get();
      if (adminDoc.exists) {
        Navigator.pushReplacementNamed(context, '/admin');
        return;
      }

      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(userCredential.user?.uid)
          .get();

      if (doctorDoc.exists) {
        if (!mounted) return;
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        if (doctorData['active'] == false) {
          setState(() {
            _emailError = 'Votre compte a été bloqué par l\'administrateur.';
            _isLoading = false;
          });
          await _auth.signOut();
          return;
        }
        AppRoutes.navigateToHomeDoctor(
          context,
          doctorName: doctorData['name'] ?? '',
          doctorEmail: doctorData['email'] ?? '',
          phone: doctorData['phone'] ?? '',
          firestoreService: FirestoreService(),
        );
        return;
      }

      DocumentSnapshot patientDoc = await FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(userCredential.user?.uid)
          .get();

      if (patientDoc.exists) {
        if (!mounted) return;
        final patientData = patientDoc.data() as Map<String, dynamic>;
        if (patientData['active'] == false) {
          setState(() {
            _emailError = 'Votre compte a été bloqué par l\'administrateur.';
            _isLoading = false;
          });
          await _auth.signOut();
          return;
        }
        AppRoutes.navigateToHome(
          context,
          userName: patientData['name'] ?? '',
          userPhoto: patientData['photoUrl'] ?? '',
          userId: userCredential.user?.uid ?? '',
          firestoreService: FirestoreService(),
        );
        return;
      }

      // Si c'est un nouvel utilisateur, créer un compte patient par défaut
      await FirestoreService().createOrUpdatePatient(
        uid: userCredential.user!.uid,
        name: userCredential.user?.displayName ?? '',
        email: userCredential.user?.email ?? '',
        profileImageUrl: userCredential.user?.photoURL ?? '',
        birthDate: '',
        gender: '',
        height: 0,
        weight: 0,
        bloodGroup: '',
        medicalHistoryDescription: '',
        phoneNumber: userCredential.user?.phoneNumber ?? '',
        favorites: [],
      );

      if (!mounted) return;
      AppRoutes.navigateToHome(
        context,
        userName: userCredential.user?.displayName ?? '',
        userPhoto: userCredential.user?.photoURL ?? '',
        userId: userCredential.user?.uid ?? '',
        firestoreService: FirestoreService(),
      );
    } catch (e) {
      setState(() {
        _emailError = 'Erreur de connexion avec Google';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark ? const Color(0xFF121212) : Colors.white;
    final Color fieldColor = isDark ? const Color(0xFF232323) : Colors.white;
    final Color border = isDark ? Colors.grey[700]! : borderColor;
    final Color label = isDark ? Colors.grey[300]! : subtitleColor;
    final Color mainText = isDark ? Colors.white : textColor;
    final Color subText = isDark ? Colors.grey[400]! : subtitleColor;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Bienvenue',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: mainText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connectez-vous pour continuer',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: subText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _emailController,
                      style: TextStyle(color: mainText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldColor,
                        labelText: 'Email',
                        errorText: _emailError.isNotEmpty ? _emailError : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor),
                        ),
                        prefixIcon: Icon(Icons.email, color: isDark ? Colors.blue[300] : primaryColor),
                        labelStyle: TextStyle(color: label),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      style: TextStyle(color: mainText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldColor,
                        labelText: 'Mot de passe',
                        errorText: _passwordError.isNotEmpty ? _passwordError : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor),
                        ),
                        prefixIcon: Icon(Icons.lock, color: isDark ? Colors.blue[300] : primaryColor),
                        labelStyle: TextStyle(color: label),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: label,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OU',
                            style: TextStyle(color: subText),
                          ),
                        ),
                        Expanded(child: Divider(color: border)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: fieldColor,
                      ),
                      icon: Image.asset(
                        'assets/Google.png',
                        height: 24,
                      ),
                      label: Text(
                        'Continuer avec Google',
                        style: TextStyle(
                          fontSize: 16,
                          color: mainText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Vous n'avez pas de compte ?",
                          style: TextStyle(color: subText),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.signup);
                          },
                          child: Text(
                            'S\'inscrire',
                            style: TextStyle(
                              color: isDark ? Colors.blue[300] : primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}