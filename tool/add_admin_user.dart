import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lib/services/firebase/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  const email = 'admin@gmail.com';
  const password = 'Administrateur';

  try {
    // Connexion ou création du compte admin
    UserCredential userCredential;
    try {
      userCredential = await auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      userCredential = await auth.createUserWithEmailAndPassword(email: email, password: password);
    }
    final uid = userCredential.user!.uid;

    // Ajout dans UserAdmin
    await firestore.collection('UserAdmin').doc(uid).set({
      'name': 'Administrateur',
      'email': email,
    });
    print('Compte admin ajouté à UserAdmin avec succès.');
  } catch (e) {
    print('Erreur : $e');
  }
} 