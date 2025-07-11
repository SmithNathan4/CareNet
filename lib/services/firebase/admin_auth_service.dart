import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Désactiver un utilisateur dans Firebase Auth
  Future<bool> disableUser(String uid) async {
    try {
      final callable = _functions.httpsCallable('disableUser');
      final result = await callable.call({'uid': uid});
      
      if (result.data['success']) {
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la désactivation: $e');
      return false;
    }
  }

  // Activer un utilisateur dans Firebase Auth
  Future<bool> enableUser(String uid) async {
    try {
      final callable = _functions.httpsCallable('enableUser');
      final result = await callable.call({'uid': uid});
      
      if (result.data['success']) {
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de l\'activation: $e');
      return false;
    }
  }

  // Supprimer un utilisateur de Firebase Auth
  Future<bool> deleteUser(String uid) async {
    try {
      final callable = _functions.httpsCallable('deleteUser');
      final result = await callable.call({'uid': uid});
      
      if (result.data['success']) {
        return true;
      }
      return false;
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      return false;
    }
  }

  // Obtenir l'UID d'un utilisateur par email
  Future<String?> getUserUidByEmail(String email) async {
    try {
      final callable = _functions.httpsCallable('getUserByEmail');
      final result = await callable.call({'email': email});
      
      if (result.data['success']) {
        return result.data['uid'];
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de l\'UID: $e');
      return null;
    }
  }

  // Vérifier si l'utilisateur actuel est admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Vérifier dans Firestore si l'utilisateur est admin
      final adminDoc = await FirebaseFirestore.instance
          .collection('UserAdmin')
          .doc(user.uid)
          .get();

      return adminDoc.exists;
    } catch (e) {
      print('Erreur lors de la vérification admin: $e');
      return false;
    }
  }
} 