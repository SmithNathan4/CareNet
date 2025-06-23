import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String patientId;
  final String doctorId;
  final Map<String, dynamic> patientInfo;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final bool isAnonymous;
  final String? appointmentId;

  Rating({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.patientInfo,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.isAnonymous = false,
    this.appointmentId,
  });

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Rating(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      patientInfo: data['patientInfo'] ?? {},
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isAnonymous: data['isAnonymous'] ?? false,
      appointmentId: data['appointmentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'patientInfo': patientInfo,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAnonymous': isAnonymous,
      'appointmentId': appointmentId,
    };
  }
} 