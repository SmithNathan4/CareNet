import 'package:cloud_firestore/cloud_firestore.dart';

class Prescription {
  final String id;
  final String patientId;
  final String doctorId;
  final Map<String, dynamic> patientInfo;
  final Map<String, dynamic> doctorInfo;
  final String diagnosis;
  final List<Map<String, dynamic>> medications;
  final String? notes;
  final DateTime createdAt;
  final DateTime? validUntil;
  final bool isRenewable;
  final int renewalCount;
  final int maxRenewals;

  Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.patientInfo,
    required this.doctorInfo,
    required this.diagnosis,
    required this.medications,
    this.notes,
    required this.createdAt,
    this.validUntil,
    this.isRenewable = false,
    this.renewalCount = 0,
    this.maxRenewals = 0,
  });

  factory Prescription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Prescription(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      patientInfo: data['patientInfo'] ?? {},
      doctorInfo: data['doctorInfo'] ?? {},
      diagnosis: data['diagnosis'] ?? '',
      medications: List<Map<String, dynamic>>.from(data['medications'] ?? []),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      validUntil: data['validUntil'] != null 
          ? (data['validUntil'] as Timestamp).toDate() 
          : null,
      isRenewable: data['isRenewable'] ?? false,
      renewalCount: data['renewalCount'] ?? 0,
      maxRenewals: data['maxRenewals'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'patientInfo': patientInfo,
      'doctorInfo': doctorInfo,
      'diagnosis': diagnosis,
      'medications': medications,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'isRenewable': isRenewable,
      'renewalCount': renewalCount,
      'maxRenewals': maxRenewals,
    };
  }

  bool get isValid {
    if (validUntil == null) return true;
    return validUntil!.isAfter(DateTime.now());
  }

  bool get canBeRenewed {
    return isRenewable && renewalCount < maxRenewals;
  }
} 