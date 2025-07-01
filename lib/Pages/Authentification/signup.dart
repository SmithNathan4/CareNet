import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase/firestore.dart';
import '../../routes/app_routes.dart';
import '../../services/firebase/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Couleurs professionnelles
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF2196F3);
  static const Color textColor = Color(0xFF333333);
  static const Color subtitleColor = Color(0xFF666666);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF66BB6A);

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

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validation de l'email
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  // Validation du mot de passe
  bool _isValidPassword(String password) {
    // Au moins 8 caractères, une majuscule, une minuscule, un chiffre, un caractère spécial
    final passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
    return passwordRegex.hasMatch(password);
  }

  // Validation du nom
  bool _isValidName(String name) {
    return name.trim().length >= 2 && name.trim().length <= 50;
  }

  Future<void> _registerWithEmailAndPassword() async {
    try {
      setState(() => _isLoading = true);
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final userId = userCredential.user!.uid;

      // Création du patient uniquement
      await FirestoreService().createOrUpdatePatient(
        uid: userId,
        name: _nameController.text,
        email: _emailController.text,
        profileImageUrl: '',
        birthDate: '',
        gender: '',
        height: 0,
        weight: 0,
        bloodGroup: '',
        medicalHistoryDescription: '',
        favorites: [],
      );

      if (!mounted) return;
      _navigateAfterSignup();
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateAfterSignup() {
    final FirestoreService firestoreService = FirestoreService();
    String userName = _nameController.text;

    AppRoutes.navigateToHome(
      context,
      userName: userName,
      userPhoto: '',
      userId: _auth.currentUser?.uid ?? '',
      firestoreService: firestoreService,
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Cet email est déjà utilisé';
        case 'invalid-email':
          return 'Email invalide';
        case 'weak-password':
          return 'Le mot de passe doit contenir au moins 6 caractères';
        default:
          return 'Erreur lors de l\'inscription';
      }
    }
    return 'Une erreur inattendue est survenue';
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
                      'Créer un compte',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: mainText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rejoignez CareNet pour une meilleure santé',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: subText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    _buildFormFields(
                      isDark: isDark,
                      fieldColor: fieldColor,
                      border: border,
                      label: label,
                      mainText: mainText,
                      subText: subText,
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildErrorMessage(),
                    ],
                    const SizedBox(height: 32),
                    _buildSignupButton(),
                    const SizedBox(height: 24),
                    _buildDivider(subText, border),
                    const SizedBox(height: 24),
                    _buildLoginPrompt(isDark, subText),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields({
    required bool isDark,
    required Color fieldColor,
    required Color border,
    required Color label,
    required Color mainText,
    required Color subText,
  }) {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          style: TextStyle(color: mainText),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldColor,
            labelText: 'Nom complet',
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
            prefixIcon: Icon(Icons.person, color: isDark ? Colors.blue[300] : primaryColor),
            labelStyle: TextStyle(color: label),
            helperText: 'Entre 2 et 50 caractères',
            helperStyle: TextStyle(fontSize: 12, color: subText),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              setState(() {
                if (!_isValidName(value)) {
                  _errorMessage = 'Le nom doit contenir entre 2 et 50 caractères';
                } else {
                  _errorMessage = '';
                }
              });
            }
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          style: TextStyle(color: mainText),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldColor,
            labelText: 'Email',
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
            helperText: 'exemple@domaine.com',
            helperStyle: TextStyle(fontSize: 12, color: subText),
            suffixIcon: _emailController.text.isNotEmpty
                ? Icon(
                    _isValidEmail(_emailController.text) ? Icons.check_circle : Icons.error,
                    color: _isValidEmail(_emailController.text) ? successColor : errorColor,
                  )
                : null,
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (value) {
            setState(() {
              if (value.isNotEmpty && !_isValidEmail(value)) {
                _errorMessage = 'Veuillez entrer une adresse email valide';
              } else {
                _errorMessage = '';
              }
            });
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          style: TextStyle(color: mainText),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldColor,
            labelText: 'Mot de passe',
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
            helperText: 'Min. 8 caractères, majuscule, minuscule, chiffre, caractère spécial',
            helperStyle: TextStyle(fontSize: 12, color: subText),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_passwordController.text.isNotEmpty)
                  Icon(
                    _isValidPassword(_passwordController.text) ? Icons.check_circle : Icons.error,
                    color: _isValidPassword(_passwordController.text) ? successColor : errorColor,
                  ),
                IconButton(
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
              ],
            ),
          ),
          obscureText: _obscurePassword,
          onChanged: (value) {
            setState(() {
              if (value.isNotEmpty && !_isValidPassword(value)) {
                _errorMessage = 'Le mot de passe ne respecte pas les critères de sécurité';
              } else {
                _errorMessage = '';
              }
            });
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPasswordController,
          style: TextStyle(color: mainText),
          decoration: InputDecoration(
            filled: true,
            fillColor: fieldColor,
            labelText: 'Confirmer le mot de passe',
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
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_confirmPasswordController.text.isNotEmpty && _passwordController.text.isNotEmpty)
                  Icon(
                    _confirmPasswordController.text == _passwordController.text ? Icons.check_circle : Icons.error,
                    color: _confirmPasswordController.text == _passwordController.text ? successColor : errorColor,
                  ),
                IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: label,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ],
            ),
          ),
          obscureText: _obscureConfirmPassword,
          onChanged: (value) {
            setState(() {
              if (value.isNotEmpty && _passwordController.text.isNotEmpty && value != _passwordController.text) {
                _errorMessage = 'Les mots de passe ne correspondent pas';
              } else {
                _errorMessage = '';
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: errorColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(color: errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _registerWithEmailAndPassword,
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
              'S\'inscrire',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildDivider(Color subText, Color border) {
    return Row(
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
    );
  }

  Widget _buildLoginPrompt(bool isDark, Color subText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Vous avez déjà un compte ?',
          style: TextStyle(color: subText),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.login);
          },
          child: Text(
            'Se connecter',
            style: TextStyle(
              color: isDark ? Colors.blue[300] : primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}