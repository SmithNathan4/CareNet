import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection des patients (inchangé)
  Future<void> createOrUpdatePatient({
    required String uid,
    required String name,
    required String email,
    required String birthDate,
    required String gender,
    required double height,
    required double weight,
    required String bloodGroup,
    required String medicalHistoryDescription,
    String phoneNumber = '',
    List<String>? favorites,
    String role = 'patient',
    String profileImageUrl = '',
  }) async {
    final patientDocRef = _firestore.collection('UserPatient').doc(uid);
    await patientDocRef.set({
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'birthDate': birthDate,
      'gender': gender,
      'height': height,
      'weight': weight,
      'bloodGroup': bloodGroup,
      'medicalHistoryDescription': medicalHistoryDescription,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'favorites': favorites ?? [],
      'role': role, // Ajout du rôle ici
    }, SetOptions(merge: true));
  }

  // Collection des médecins (mise à jour avec statut)
  Future<void> createOrUpdateDoctor({
    required String uid,
    required String name,
    required String email,
    String photoUrl = '',
    String phone = '',
    String speciality = '',
    String address = '',
    int experience = 0,
    double rating = 0,
    List<dynamic> reviews = const [],
    String? description,
    Map<String, dynamic>? availability,
    String? location,
    String role = 'doctor',
    String status = 'disponible',
    String? education,
    List<String>? languages,
    List<String>? services,
  }) async {
    final doctorDocRef = _firestore.collection('UserDoctor').doc(uid);
    await doctorDocRef.set({
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'phone': phone,
      'speciality': speciality,
      'address': address,
      'experience': experience,
      'rating': rating,
      'reviews': reviews,
      'description': description ?? '',
      'availability': availability ?? {},
      'location': location ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'role': role,
      'status': status,
      'education': education ?? '',
      'languages': languages ?? [],
      'services': services ?? [],
    }, SetOptions(merge: true));
  }

  // Nouvelle méthode pour mettre à jour le statut du docteur
  Future<void> updateDoctorStatus({
    required String uid,
    required String status,
  }) async {
    try {
      await _firestore.collection('UserDoctor').doc(uid).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Nouvelle méthode pour obtenir le statut actuel du docteur
  Future<String> getDoctorStatus(String uid) async {
    try {
      final doc = await _firestore.collection('UserDoctor').doc(uid).get();
      return doc.data()?['status'] ?? 'hors_ligne';
    } catch (e) {
      return 'hors_ligne';
    }
  }

  // Stream pour observer les changements de statut du docteur
  Stream<String> getDoctorStatusStream(String uid) {
    return _firestore
        .collection('UserDoctor')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['status'] ?? 'hors_ligne');
  }

  // Méthodes existantes pour les patients (inchangées)
  Future<DocumentSnapshot> getPatient(String uid) async {
    return await _firestore.collection('UserPatient').doc(uid).get();
  }

  Stream<DocumentSnapshot> getPatientStream(String uid) {
    return _firestore.collection('UserPatient').doc(uid).snapshots();
  }

  // Nouvelle méthode pour obtenir un médecin
  Future<DocumentSnapshot> getDoctor(String uid) async {
    return await _firestore.collection('UserDoctor').doc(uid).get();
  }

  // Méthode pour obtenir les données d'un médecin par son ID
  Future<Map<String, dynamic>> getDoctorById(String doctorId) async {
    try {
      final doc = await _firestore.collection('UserDoctor').doc(doctorId).get();
      if (!doc.exists) {
        throw Exception('Médecin non trouvé');
      }
      return doc.data() ?? {};
    } catch (e) {
      throw Exception('Erreur lors de la récupération du médecin: $e');
    }
  }

  // Nouveau stream pour les données médecin
  Stream<DocumentSnapshot> getDoctorStream(String uid) {
    return _firestore.collection('UserDoctor').doc(uid).snapshots();
  }

  // Méthodes existantes pour les administrateurs (mise à jour)
  Future<void> createOrUpdateAdmin({
    required String uid,
    required String name,
    required String email,
    required String role, // Rôle requis
    required String phone,
    List<String>? permissions,
  }) async {
    final adminDocRef = _firestore.collection('UserAdmin').doc(uid);
    await adminDocRef.set({
      'name': name,
      'email': email,
      'role': role, // Ajout du rôle ici
      'phone': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'permissions': permissions ?? [],
    }, SetOptions(merge: true));
  }

  // Méthodes existantes pour les rendez-vous (inchangées)
  Future<void> createAppointment({
    required String patientId,
    required String doctorId,
    required String date,
    required String time,
    required String motive,
  }) async {
    final appointmentData = {
      'patientId': patientId,
      'doctorId': doctorId,
      'date': date,
      'time': time,
      'status': 'en_attente',
      'motive': motive,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('Appointments').add(appointmentData);
  }

  Future<QuerySnapshot> getAppointments() async {
    return await _firestore.collection('Appointments').get();
  }

  // Méthodes existantes pour les messages (inchangées)
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
    required String type,
  }) async {
    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
    };
    await _firestore.collection('Messages').doc(conversationId).collection('messages').add(messageData);
  }

  Future<QuerySnapshot> getMessages(String conversationId) async {
    return await _firestore.collection('Messages').doc(conversationId).collection('messages').get();
  }

  // Méthodes existantes pour les documents (inchangées)
  Future<void> uploadDocument({
    required String patientId,
    required String doctorId,
    required String fileUrl,
    required String title,
    required String type,
  }) async {
    final documentData = {
      'patientId': patientId,
      'doctorId': doctorId,
      'fileUrl': fileUrl,
      'title': title,
      'type': type,
      'uploadedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('Documents').add(documentData);
  }

  // Méthodes existantes pour les transactions (inchangées)
  Future<void> createTransaction({
    required String patientId,
    required String doctorId,
    required double amount,
    required String method,
    required String status,
  }) async {
    final transactionData = {
      'patientId': patientId,
      'doctorId': doctorId,
      'amount': amount,
      'method': method,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('Transactions').add(transactionData);
  }

  // NOUVELLES METHODES UTILES POUR LES MEDECINS

  // Récupérer tous les médecins
  Future<QuerySnapshot> getAllDoctors() async {
    return await _firestore.collection('UserDoctor').get();
  }

  // Mettre à jour la note d'un médecin
  Future<void> updateDoctorRating(String uid, double newRating) async {
    await _firestore.collection('UserDoctor').doc(uid).update({
      'rating': newRating,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Ajouter un avis à un médecin
  Future<void> addDoctorReview(String uid, Map<String, dynamic> review) async {
    await _firestore.collection('UserDoctor').doc(uid).update({
      'reviews': FieldValue.arrayUnion([review]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Récupérer les rendez-vous d'un médecin
  Future<QuerySnapshot> getDoctorAppointments(String doctorId) async {
    return await _firestore
        .collection('Appointments')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('date')
        .orderBy('time')
        .get();
  }

  // Méthode pour récupérer les données d'un docteur
  Future<Map<String, dynamic>?> getDoctorData(String uid) async {
    try {
      DocumentSnapshot doctorDoc = await _firestore.collection('UserDoctor').doc(uid).get();
      if (doctorDoc.exists) {
        return doctorDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // NOUVELLES MÉTHODES DE RECHERCHE ET FILTRAGE POUR LES DOCTEURS

  // Rechercher des docteurs par spécialité et rating
  Future<List<DocumentSnapshot>> searchDoctorsBySpeciality(String speciality) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('UserDoctor')
          .where('speciality', isEqualTo: speciality)
          .orderBy('rating', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Obtenir les docteurs par statut
  Future<List<DocumentSnapshot>> getDoctorsByStatus(String status) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('UserDoctor')
          .where('status', isEqualTo: status)
          .orderBy('rating', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Rechercher des docteurs par localisation
  Future<List<DocumentSnapshot>> searchDoctorsByLocation(String location) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('UserDoctor')
          .where('location', isEqualTo: location)
          .orderBy('rating', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Méthode de recherche avancée des docteurs
  Future<List<DocumentSnapshot>> searchDoctorsAdvanced({
    String? query,
    String? speciality,
    String? location,
    String? status,
    double? minRating,
  }) async {
    try {
      Query doctorsQuery = _firestore.collection('UserDoctor');

      if (query != null && query.isNotEmpty) {
        doctorsQuery = doctorsQuery.where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff');
      }

      if (speciality != null) {
        doctorsQuery = doctorsQuery.where('speciality', isEqualTo: speciality);
      }

      if (location != null) {
        doctorsQuery = doctorsQuery.where('location', isEqualTo: location);
      }

      if (status != null) {
        doctorsQuery = doctorsQuery.where('status', isEqualTo: status);
      }

      final QuerySnapshot querySnapshot = await doctorsQuery.get();
      
      if (minRating != null && minRating > 0) {
        return querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rating = (data['rating'] ?? 0.0).toDouble();
          return rating >= minRating;
        }).toList();
      }

      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // MÉTHODES POUR LES RENDEZ-VOUS

  // Obtenir les rendez-vous d'un docteur par date
  Future<List<DocumentSnapshot>> getDoctorAppointmentsByDate(
    String doctorId,
    DateTime date,
  ) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('Appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date.toIso8601String().split('T')[0])
          .orderBy('time')
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Obtenir l'historique des rendez-vous d'un patient
  Stream<QuerySnapshot> getPatientAppointmentsHistory(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // MÉTHODES DE RECHERCHE POUR LES PATIENTS

  // Rechercher des patients par nom
  Future<List<DocumentSnapshot>> searchPatientsByName(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('UserPatient')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Rechercher des patients par email
  Future<List<DocumentSnapshot>> searchPatientsByEmail(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('UserPatient')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Rechercher des patients par téléphone
  Future<List<DocumentSnapshot>> searchPatientsByPhone(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('UserPatient')
          .where('phoneNumber', isGreaterThanOrEqualTo: query)
          .where('phoneNumber', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Obtenir les patients d'un docteur
  Future<List<DocumentSnapshot>> getDoctorPatients(String doctorId) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('UserPatient')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('name')
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      return [];
    }
  }

  // Nouvelle méthode pour mettre à jour les disponibilités du docteur
  Future<void> updateDoctorAvailability({
    required String uid,
    required Map<String, List<String>> availability,
  }) async {
    try {
      await _firestore.collection('UserDoctor').doc(uid).update({
        'availability': availability,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Nouvelle méthode pour obtenir les disponibilités du docteur
  Future<Map<String, List<String>>> getDoctorAvailability(String uid) async {
    try {
      final doc = await _firestore.collection('UserDoctor').doc(uid).get();
      final data = doc.data()?['availability'] as Map<String, dynamic>? ?? {};
      return data.map((key, value) => MapEntry(key, List<String>.from(value)));
    } catch (e) {
      return {};
    }
  }

  // Méthodes pour les demandes de rendez-vous
  Stream<QuerySnapshot> getAppointmentRequests(String doctorId) {
    return _firestore
        .collection('appointment_requests')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'en_attente')
        .snapshots();
  }

  Future<void> updateAppointmentRequest(String requestId, String status, {String? message}) async {
    try {
      final requestRef = _firestore.collection('appointment_requests').doc(requestId);
      final requestDoc = await requestRef.get();
      final requestData = requestDoc.data() as Map<String, dynamic>;

      await requestRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (message != null) 'doctorMessage': message,
      });

      // Notifier le patient
      if (requestData['patientId'] != null) {
        await _firestore.collection('notifications').add({
          'userId': requestData['patientId'],
          'title': status == 'accepte' ? 'Rendez-vous accepté' : 'Rendez-vous refusé',
          'message': message ?? (status == 'accepte' ? 'Votre demande de rendez-vous a été acceptée' : 'Votre demande de rendez-vous a été refusée'),
          'type': 'appointment_request',
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la demande: $e');
    }
  }

  Future<void> sendMessageToPatient(String patientId, String message) async {
    try {
      await _firestore.collection('messages').add({
        'senderId': _auth.currentUser?.uid,
        'receiverId': patientId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du message: $e');
    }
  }

  // Méthode pour rechercher des médecins
  Future<List<Map<String, dynamic>>> searchDoctors({
    required String query,
    String? filter,
  }) async {
    try {
      Query doctorsQuery = _firestore.collection('UserDoctor');

      // Si on a une requête de recherche, filtrer par nom
      if (query.isNotEmpty) {
        doctorsQuery = doctorsQuery.where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff');
      }

      // Appliquer les filtres
      if (filter != null && filter != 'Tous') {
        switch (filter) {
          case 'Généraliste':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Généraliste');
            break;
          case 'Cardiologue':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Cardiologue');
            break;
          case 'Dermatologue':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Dermatologue');
            break;
          case 'Pédiatre':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Pédiatre');
            break;
          case 'Gynécologue':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Gynécologue');
            break;
          case 'Psychiatre':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Psychiatre');
            break;
          case 'Dentiste':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Dentiste');
            break;
          case 'Ophtamologue':
            doctorsQuery = doctorsQuery.where('speciality', isEqualTo: 'Ophtamologue');
            break;
          case 'Disponible':
            doctorsQuery = doctorsQuery.where('status', isEqualTo: 'disponible');
            break;
          case 'En ligne':
            doctorsQuery = doctorsQuery.where('status', whereIn: ['disponible', 'occupé']);
            break;
          case 'Évalué 4+':
            doctorsQuery = doctorsQuery.where('rating', isGreaterThanOrEqualTo: 4.0);
            break;
        }
      }

      final QuerySnapshot querySnapshot = await doctorsQuery.limit(20).get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Erreur lors de la recherche des médecins: $e');
      return [];
    }
  }

  // Méthode pour obtenir les rendez-vous à venir d'un patient
  Stream<QuerySnapshot> getUpcomingAppointments(String patientId) {
    final now = DateTime.now();
    return _firestore
        .collection('Appointments')
        .where('patientId', isEqualTo: patientId)
        .where('date', isGreaterThanOrEqualTo: now.toIso8601String().split('T')[0])
        .where('status', isEqualTo: 'confirmé')
        .orderBy('date')
        .orderBy('time')
        .snapshots();
  }

  // Méthode pour obtenir les médecins recommandés
  Stream<QuerySnapshot> getRecommendedDoctors() {
    return _firestore
        .collection('UserDoctor')
        .where('status', isEqualTo: 'disponible')
        .orderBy('rating', descending: true)
        .limit(10)
        .snapshots();
  }

  // --- PARAMÈTRES GLOBAUX ---
  /// Récupérer le tarif global de consultation depuis app_settings/main
  Future<double> getGlobalTarif() async {
    final doc = await _firestore.collection('app_settings').doc('main').get();
    return (doc.data()?['tarif'] ?? 0).toDouble();
  }

  /// Récupérer la liste dynamique des spécialités depuis app_settings/main
  Future<List<String>> getSpecialities() async {
    final doc = await _firestore.collection('app_settings').doc('main').get();
    return List<String>.from(doc.data()?['specialities'] ?? []);
  }
}
