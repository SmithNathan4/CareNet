import 'package:cloud_firestore/cloud_firestore.dart';

class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final Map<String, dynamic> patientInfo;
  final Map<String, dynamic> doctorInfo;
  final DateTime dateTime;
  final String status; // 'pending', 'confirmed', 'cancelled', 'completed'
  final String type; // 'online', 'in_person'
  final String? notes;
  final double amount;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final bool hasReminder;
  final int reminderMinutes;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.patientInfo,
    required this.doctorInfo,
    required this.dateTime,
    required this.status,
    required this.type,
    this.notes,
    required this.amount,
    required this.paymentStatus,
    required this.createdAt,
    this.confirmedAt,
    this.cancelledAt,
    this.completedAt,
    this.hasReminder = true,
    this.reminderMinutes = 30,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      patientInfo: data['patientInfo'] ?? {},
      doctorInfo: data['doctorInfo'] ?? {},
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
      type: data['type'] ?? 'online',
      notes: data['notes'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentStatus: data['paymentStatus'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      confirmedAt: data['confirmedAt'] != null 
          ? (data['confirmedAt'] as Timestamp).toDate() 
          : null,
      cancelledAt: data['cancelledAt'] != null 
          ? (data['cancelledAt'] as Timestamp).toDate() 
          : null,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      hasReminder: data['hasReminder'] ?? true,
      reminderMinutes: data['reminderMinutes'] ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'patientInfo': patientInfo,
      'doctorInfo': doctorInfo,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status,
      'type': type,
      'notes': notes,
      'amount': amount,
      'paymentStatus': paymentStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'hasReminder': hasReminder,
      'reminderMinutes': reminderMinutes,
    };
  }

  bool get isUpcoming => 
      dateTime.isAfter(DateTime.now()) && 
      status != 'cancelled' && 
      status != 'completed';

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
} 