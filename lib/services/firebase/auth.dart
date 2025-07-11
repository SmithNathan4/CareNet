import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChange => _firebaseAuth.authStateChanges();

  // Inscription avec email et mot de passe
  Future<void> registerWithEmailAndPassword(String email, String password) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // Gérer les erreurs ici (par exemple, afficher un message)
      throw Exception('Erreur lors de l\'inscription: $e');
    }
  }

  // Se connecter avec email et mot de passe
  Future<void> loginWithEmailAndPassword(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // Gérer les erreurs ici (par exemple, afficher un message)
      throw Exception('Erreur lors de la connexion: $e');
    }
  }

  // Se déconnecter
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  // Connexion avec un compte Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // L'utilisateur a annulé la connexion
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      // Gérer les erreurs ici (par exemple, afficher un message)
      throw Exception('Erreur lors de la connexion avec Google: $e');
    }
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Stream pour écouter les changements d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Vérifier si l'utilisateur est connecté
  bool get isLoggedIn => _auth.currentUser != null;

  // Obtenir les données utilisateur (patient ou docteur)
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      // Vérifier d'abord dans la collection des patients
      final patientDoc = await _firestore
          .collection('UserPatient')
          .doc(uid)
          .get();
      
      if (patientDoc.exists) {
        final data = patientDoc.data() as Map<String, dynamic>;
        return {
          'userType': 'patient',
          'name': data['name'] ?? 'Patient',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'uid': uid,
        };
      }
      
      // Vérifier dans la collection des médecins
      final doctorDoc = await _firestore
          .collection('UserDoctor')
          .doc(uid)
          .get();
      
      if (doctorDoc.exists) {
        final data = doctorDoc.data() as Map<String, dynamic>;
        return {
          'userType': 'doctor',
          'name': data['name'] ?? 'Docteur',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'uid': uid,
        };
      }
      
      return null;
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
      return null;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      // Nettoyer les préférences locales si nécessaire
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }

  // Vérifier l'état d'authentification complet
  Future<Map<String, dynamic>?> checkAuthState() async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        // L'utilisateur est connecté, récupérer ses données
        return await getUserData(user.uid);
      }
      
      return null;
    } catch (e) {
      print('Erreur lors de la vérification de l\'état d\'authentification: $e');
      return null;
    }
  }

  // Sauvegarder les préférences d'authentification
  Future<void> saveAuthPreferences(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userType', userData['userType']);
      await prefs.setString('userName', userData['name']);
      await prefs.setString('userEmail', userData['email']);
      await prefs.setString('userPhoto', userData['photoUrl']);
      await prefs.setString('userUid', userData['uid']);
    } catch (e) {
      print('Erreur lors de la sauvegarde des préférences: $e');
    }
  }

  // Charger les préférences d'authentification
  Future<Map<String, dynamic>?> loadAuthPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');
      final userName = prefs.getString('userName');
      final userEmail = prefs.getString('userEmail');
      final userPhoto = prefs.getString('userPhoto');
      final userUid = prefs.getString('userUid');

      if (userType != null && userName != null && userEmail != null && userUid != null) {
        return {
          'userType': userType,
          'name': userName,
          'email': userEmail,
          'photoUrl': userPhoto ?? '',
          'uid': userUid,
        };
      }
      
      return null;
    } catch (e) {
      print('Erreur lors du chargement des préférences: $e');
      return null;
    }
  }

  // Nettoyer les préférences d'authentification
  Future<void> clearAuthPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userType');
      await prefs.remove('userName');
      await prefs.remove('userEmail');
      await prefs.remove('userPhoto');
      await prefs.remove('userUid');
    } catch (e) {
      print('Erreur lors du nettoyage des préférences: $e');
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Vérifier si l'utilisateur est actif dans Firestore
      final user = userCredential.user;
      if (user != null) {
        bool isActive = await _checkUserActiveStatus(user.uid);
        if (!isActive) {
          // Déconnecter l'utilisateur s'il est bloqué
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-disabled',
            message: 'Votre compte a été désactivé par l\'administrateur.',
          );
        }
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Vérifier si l'utilisateur est actif dans Firestore
  Future<bool> _checkUserActiveStatus(String uid) async {
    try {
      // Vérifier dans toutes les collections d'utilisateurs
      final collections = ['UserPatient', 'UserDoctor', 'UserAdmin'];
      
      for (String collection in collections) {
        final doc = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          return data['active'] != false; // Retourne true si active n'est pas false
        }
      }
      
      // Si l'utilisateur n'est trouvé dans aucune collection, considérer comme inactif
      return false;
    } catch (e) {
      print('Erreur lors de la vérification du statut: $e');
      return false;
    }
  }
}
