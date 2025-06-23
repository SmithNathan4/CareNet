import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Vérifier si un patient a déjà payé un médecin
  Future<bool> hasPatientPaidDoctor({
    required String patientId,
    required String doctorId,
  }) async {
    try {
      final query = await _firestore
          .collection('consultations')
          .where('patientId', isEqualTo: patientId)
          .where('doctorId', isEqualTo: doctorId)
          .where('paymentStatus', isEqualTo: 'completed')
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification du paiement: $e');
      return false;
    }
  }

  // Créer une nouvelle consultation avec paiement
  Future<String> createConsultation({
    required String patientId,
    required String doctorId,
    required String patientName,
    required String doctorName,
    required String reason,
    required String paymentMethod,
    String? patientPhoto,
    String? doctorPhoto,
  }) async {
    try {
      // Vérifier si le patient a déjà payé ce médecin
      final hasPaid = await hasPatientPaidDoctor(
        patientId: patientId,
        doctorId: doctorId,
      );

      if (hasPaid) {
        throw Exception('Vous avez déjà payé ce médecin. Vous pouvez le contacter directement dans vos messages.');
      }

      // Créer la consultation
      final consultationRef = await _firestore.collection('consultations').add({
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'reason': reason,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
        'amount': 3000,
        'paymentStatus': 'completed',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'patientPhoto': patientPhoto,
        'doctorPhoto': doctorPhoto,
      });

      return consultationRef.id;
    } catch (e) {
      print('Erreur lors de la création de la consultation: $e');
      rethrow;
    }
  }

  // Récupérer toutes les consultations d'un patient
  Future<List<Map<String, dynamic>>> getPatientConsultations(String patientId) async {
    try {
      final query = await _firestore
          .collection('consultations')
          .where('patientId', isEqualTo: patientId)
          .where('paymentStatus', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des consultations: $e');
      return [];
    }
  }

  // Récupérer toutes les consultations d'un médecin
  Future<List<Map<String, dynamic>>> getDoctorConsultations(String doctorId) async {
    try {
      final query = await _firestore
          .collection('consultations')
          .where('doctorId', isEqualTo: doctorId)
          .where('paymentStatus', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des consultations: $e');
      return [];
    }
  }

  // Obtenir les informations d'une consultation
  Future<Map<String, dynamic>?> getConsultationById(String consultationId) async {
    try {
      final doc = await _firestore
          .collection('consultations')
          .doc(consultationId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de la consultation: $e');
      return null;
    }
  }

  // Mettre à jour le statut d'une consultation
  Future<void> updateConsultationStatus({
    required String consultationId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection('consultations')
          .doc(consultationId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de la mise à jour du statut: $e');
      rethrow;
    }
  }

  // Supprimer une consultation (pour les tests ou corrections)
  Future<void> deleteConsultation(String consultationId) async {
    try {
      await _firestore
          .collection('consultations')
          .doc(consultationId)
          .delete();
    } catch (e) {
      print('Erreur lors de la suppression de la consultation: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques de consultation pour un patient
  Future<Map<String, dynamic>> getPatientStats(String patientId) async {
    try {
      final consultations = await getPatientConsultations(patientId);
      
      return {
        'totalConsultations': consultations.length,
        'activeConsultations': consultations.where((c) => c['status'] == 'active').length,
        'completedConsultations': consultations.where((c) => c['status'] == 'completed').length,
        'totalAmount': consultations.fold<int>(0, (sum, c) => sum + (c['amount'] as int? ?? 0)),
      };
    } catch (e) {
      print('Erreur lors du calcul des statistiques: $e');
      return {
        'totalConsultations': 0,
        'activeConsultations': 0,
        'completedConsultations': 0,
        'totalAmount': 0,
      };
    }
  }

  // Obtenir les statistiques de consultation pour un médecin
  Future<Map<String, dynamic>> getDoctorStats(String doctorId) async {
    try {
      final consultations = await getDoctorConsultations(doctorId);
      
      return {
        'totalConsultations': consultations.length,
        'activeConsultations': consultations.where((c) => c['status'] == 'active').length,
        'completedConsultations': consultations.where((c) => c['status'] == 'completed').length,
        'totalEarnings': consultations.fold<int>(0, (sum, c) => sum + (c['amount'] as int? ?? 0)),
      };
    } catch (e) {
      print('Erreur lors du calcul des statistiques: $e');
      return {
        'totalConsultations': 0,
        'activeConsultations': 0,
        'completedConsultations': 0,
        'totalEarnings': 0,
      };
    }
  }

  // Créer un nouveau rendez-vous
  Future<Appointment> createAppointment({
    required String patientId,
    required String doctorId,
    required Map<String, dynamic> patientInfo,
    required Map<String, dynamic> doctorInfo,
    required DateTime dateTime,
    required String type,
    required double amount,
    String? notes,
    bool hasReminder = true,
    int reminderMinutes = 30,
  }) async {
    final docRef = await _firestore.collection('appointments').add({
      'patientId': patientId,
      'doctorId': doctorId,
      'patientInfo': patientInfo,
      'doctorInfo': doctorInfo,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': 'pending',
      'type': type,
      'notes': notes,
      'amount': amount,
      'paymentStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'hasReminder': hasReminder,
      'reminderMinutes': reminderMinutes,
    });

    final doc = await docRef.get();
    return Appointment.fromFirestore(doc);
  }

  // Obtenir les rendez-vous d'un patient
  Stream<List<Appointment>> getPatientAppointments(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList());
  }

  // Obtenir les rendez-vous d'un médecin
  Stream<List<Appointment>> getDoctorAppointments(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList());
  }

  // Obtenir les rendez-vous d'un médecin pour une date donnée
  Stream<List<Appointment>> getDoctorAppointmentsForDate(
      String doctorId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('dateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList());
  }

  // Confirmer un rendez-vous
  Future<void> confirmAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': 'confirmed',
      'confirmedAt': FieldValue.serverTimestamp(),
    });
  }

  // Annuler un rendez-vous
  Future<void> cancelAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // Marquer un rendez-vous comme terminé
  Future<void> completeAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // Mettre à jour le statut de paiement
  Future<void> updatePaymentStatus(String appointmentId, String status) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'paymentStatus': status,
    });
  }

  // Mettre à jour les notes d'un rendez-vous
  Future<void> updateAppointmentNotes(String appointmentId, String notes) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'notes': notes,
    });
  }

  // Obtenir un rendez-vous spécifique
  Stream<Appointment?> getAppointment(String appointmentId) {
    return _firestore
        .collection('appointments')
        .doc(appointmentId)
        .snapshots()
        .map((doc) => doc.exists ? Appointment.fromFirestore(doc) : null);
  }

  // Obtenir les prochains rendez-vous d'un patient
  Stream<List<Appointment>> getUpcomingPatientAppointments(String patientId) {
    final now = DateTime.now();
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('status', whereIn: ['pending', 'confirmed'])
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList());
  }

  // Obtenir les prochains rendez-vous d'un médecin
  Stream<List<Appointment>> getUpcomingDoctorAppointments(String doctorId) {
    final now = DateTime.now();
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('status', whereIn: ['pending', 'confirmed'])
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Appointment.fromFirestore(doc)).toList());
  }
} 