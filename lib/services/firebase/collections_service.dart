import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollectionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection References
  CollectionReference get appointments => _firestore.collection('appointments');
  CollectionReference get reminders => _firestore.collection('reminders');
  CollectionReference get documents => _firestore.collection('documents');
  CollectionReference get transactions => _firestore.collection('transactions');
  CollectionReference get userDoctor => _firestore.collection('UserDoctor');
  CollectionReference get userPatient => _firestore.collection('UserPatient');

  // Appointments Methods
  Future<void> createAppointment({
    required String doctorId,
    required String date,
    required String time,
    required String reason,
    double price = 50.0,
  }) async {
    final String? patientId = _auth.currentUser?.uid;
    if (patientId == null) throw Exception('Utilisateur non connecté');

    await appointments.add({
      'doctorId': doctorId,
      'patientId': patientId,
      'date': date,
      'time': time,
      'reason': reason,
      'status': 'pending',
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getPatientAppointments() {
    final String? patientId = _auth.currentUser?.uid;
    if (patientId == null) throw Exception('Utilisateur non connecté');

    return appointments
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Reminders Methods
  Future<void> createMedicationReminder({
    required String medicationName,
    required String dosage,
    required String frequency,
    required DateTime nextTime,
  }) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    await reminders.add({
      'userId': userId,
      'type': 'medication',
      'medicationName': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'nextTime': Timestamp.fromDate(nextTime),
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  Future<void> createConsultationReminder({
    required String doctorName,
    required String reason,
    required DateTime nextTime,
  }) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    await reminders.add({
      'userId': userId,
      'type': 'consultation',
      'doctorName': doctorName,
      'reason': reason,
      'nextTime': Timestamp.fromDate(nextTime),
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  Stream<QuerySnapshot> getMedicationReminders() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    return reminders
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'medication')
        .where('isActive', isEqualTo: true)
        .orderBy('nextTime')
        .snapshots();
  }

  Stream<QuerySnapshot> getConsultationReminders() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    return reminders
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'consultation')
        .where('isActive', isEqualTo: true)
        .orderBy('nextTime')
        .snapshots();
  }

  // Documents Methods
  Future<void> createDocument({
    required String title,
    required String doctorName,
    required String type,
    String? description,
    String? fileUrl,
  }) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    await documents.add({
      'userId': userId,
      'title': title,
      'doctorName': doctorName,
      'type': type,
      'description': description,
      'fileUrl': fileUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getDocuments(String type) {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    return documents
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Transactions Methods
  Future<void> createTransaction({
    required String doctorId,
    required double amount,
    required String method,
    required String type,
    String? referenceId,
  }) async {
    final String? patientId = _auth.currentUser?.uid;
    if (patientId == null) throw Exception('Utilisateur non connecté');

    await transactions.add({
      'patientId': patientId,
      'doctorId': doctorId,
      'amount': amount,
      'method': method,
      'type': type,
      'referenceId': referenceId,
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getTransactions() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('Utilisateur non connecté');

    return transactions
        .where('patientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Delete Methods
  Future<void> deleteReminder(String reminderId) async {
    await reminders.doc(reminderId).delete();
  }

  Future<void> deleteDocument(String documentId) async {
    await documents.doc(documentId).delete();
  }

  // Update Methods
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await appointments.doc(appointmentId).update({'status': status});
  }

  Future<void> updateReminderStatus(String reminderId, bool isActive) async {
    await reminders.doc(reminderId).update({'isActive': isActive});
  }
} 