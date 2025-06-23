import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Créer une nouvelle évaluation
  Future<Rating> createRating({
    required String patientId,
    required String doctorId,
    required Map<String, dynamic> patientInfo,
    required double rating,
    String? comment,
    bool isAnonymous = false,
    String? appointmentId,
  }) async {
    final docRef = await _firestore.collection('ratings').add({
      'patientId': patientId,
      'doctorId': doctorId,
      'patientInfo': patientInfo,
      'patientName': patientInfo['name'] ?? '',
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'isAnonymous': isAnonymous,
      'appointmentId': appointmentId,
    });

    final doc = await docRef.get();
    final newRating = Rating.fromFirestore(doc);

    // Recalculer la moyenne et mettre à jour UserDoctor
    await _updateDoctorAverageRating(doctorId);

    return newRating;
  }

  Future<void> _updateDoctorAverageRating(String doctorId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('doctorId', isEqualTo: doctorId)
        .get();
    if (snapshot.docs.isEmpty) return;
    final total = snapshot.docs.fold<double>(
        0.0, (sum, doc) => sum + (doc.data()['rating'] ?? 0.0));
    final avg = total / snapshot.docs.length;
    await _firestore.collection('UserDoctor').doc(doctorId).update({
      'rating': avg,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Obtenir les évaluations d'un médecin
  Stream<List<Rating>> getDoctorRatings(String doctorId) {
    return _firestore
        .collection('ratings')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Rating.fromFirestore(doc)).toList());
  }

  // Obtenir la moyenne des évaluations d'un médecin
  Stream<double> getDoctorAverageRating(String doctorId) {
    return _firestore
        .collection('ratings')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 0.0;
      final total = snapshot.docs.fold<double>(
          0.0, (sum, doc) => sum + (doc.data()['rating'] ?? 0.0));
      return total / snapshot.docs.length;
    });
  }

  // Obtenir les évaluations d'un patient
  Stream<List<Rating>> getPatientRatings(String patientId) {
    return _firestore
        .collection('ratings')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Rating.fromFirestore(doc)).toList());
  }

  // Obtenir une évaluation spécifique
  Stream<Rating?> getRating(String ratingId) {
    return _firestore
        .collection('ratings')
        .doc(ratingId)
        .snapshots()
        .map((doc) => doc.exists ? Rating.fromFirestore(doc) : null);
  }

  // Mettre à jour une évaluation
  Future<void> updateRating(String ratingId, {
    double? rating,
    String? comment,
    bool? isAnonymous,
  }) async {
    final updates = <String, dynamic>{};
    if (rating != null) updates['rating'] = rating;
    if (comment != null) updates['comment'] = comment;
    if (isAnonymous != null) updates['isAnonymous'] = isAnonymous;

    await _firestore.collection('ratings').doc(ratingId).update(updates);
  }

  // Supprimer une évaluation
  Future<void> deleteRating(String ratingId) async {
    await _firestore.collection('ratings').doc(ratingId).delete();
  }

  // Vérifier si un patient a déjà évalué un rendez-vous
  Future<bool> hasPatientRatedAppointment(String patientId, String appointmentId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('patientId', isEqualTo: patientId)
        .where('appointmentId', isEqualTo: appointmentId)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Obtenir les statistiques des évaluations d'un médecin
  Future<Map<String, dynamic>> getDoctorRatingStats(String doctorId) async {
    final snapshot = await _firestore
        .collection('ratings')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    if (snapshot.docs.isEmpty) {
      return {
        'average': 0.0,
        'total': 0,
        'distribution': {
          '5': 0,
          '4': 0,
          '3': 0,
          '2': 0,
          '1': 0,
        }
      };
    }

    final distribution = {
      '5': 0,
      '4': 0,
      '3': 0,
      '2': 0,
      '1': 0,
    };

    double total = 0;
    for (var doc in snapshot.docs) {
      final rating = doc.data()['rating'] ?? 0.0;
      total += rating;
      distribution[rating.round().toString()] = 
          (distribution[rating.round().toString()] ?? 0) + 1;
    }

    return {
      'average': total / snapshot.docs.length,
      'total': snapshot.docs.length,
      'distribution': distribution,
    };
  }
} 