import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prescription.dart';

class PrescriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Créer une nouvelle ordonnance
  Future<Prescription> createPrescription({
    required String patientId,
    required String doctorId,
    required Map<String, dynamic> patientInfo,
    required Map<String, dynamic> doctorInfo,
    required String diagnosis,
    required List<Map<String, dynamic>> medications,
    String? notes,
    DateTime? validUntil,
    bool isRenewable = false,
    int maxRenewals = 0,
  }) async {
    final docRef = await _firestore.collection('prescriptions').add({
      'patientId': patientId,
      'doctorId': doctorId,
      'patientInfo': patientInfo,
      'doctorInfo': doctorInfo,
      'diagnosis': diagnosis,
      'medications': medications,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil) : null,
      'isRenewable': isRenewable,
      'renewalCount': 0,
      'maxRenewals': maxRenewals,
    });

    final doc = await docRef.get();
    return Prescription.fromFirestore(doc);
  }

  // Obtenir les ordonnances d'un patient
  Stream<List<Prescription>> getPatientPrescriptions(String patientId) {
    return _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList());
  }

  // Obtenir les ordonnances d'un médecin
  Stream<List<Prescription>> getDoctorPrescriptions(String doctorId) {
    return _firestore
        .collection('prescriptions')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList());
  }

  // Obtenir une ordonnance spécifique
  Stream<Prescription?> getPrescription(String prescriptionId) {
    return _firestore
        .collection('prescriptions')
        .doc(prescriptionId)
        .snapshots()
        .map((doc) => doc.exists ? Prescription.fromFirestore(doc) : null);
  }

  // Renouveler une ordonnance
  Future<void> renewPrescription(String prescriptionId) async {
    final prescriptionRef = _firestore.collection('prescriptions').doc(prescriptionId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(prescriptionRef);
      if (!doc.exists) throw Exception('Ordonnance non trouvée');
      
      final prescription = Prescription.fromFirestore(doc);
      if (!prescription.canBeRenewed) {
        throw Exception('Cette ordonnance ne peut pas être renouvelée');
      }

      transaction.update(prescriptionRef, {
        'renewalCount': prescription.renewalCount + 1,
      });
    });
  }

  // Obtenir les ordonnances valides d'un patient
  Stream<List<Prescription>> getValidPatientPrescriptions(String patientId) {
    final now = DateTime.now();
    return _firestore
        .collection('prescriptions')
        .where('patientId', isEqualTo: patientId)
        .where('validUntil', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('validUntil', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Prescription.fromFirestore(doc)).toList());
  }

  // Mettre à jour les notes d'une ordonnance
  Future<void> updatePrescriptionNotes(String prescriptionId, String notes) async {
    await _firestore.collection('prescriptions').doc(prescriptionId).update({
      'notes': notes,
    });
  }

  // Mettre à jour la date de validité d'une ordonnance
  Future<void> updateValidUntil(String prescriptionId, DateTime validUntil) async {
    await _firestore.collection('prescriptions').doc(prescriptionId).update({
      'validUntil': Timestamp.fromDate(validUntil),
    });
  }
} 