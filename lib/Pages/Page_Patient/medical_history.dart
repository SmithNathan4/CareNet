import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/firebase/firestore.dart';

class MedicalHistory extends StatefulWidget {
  final FirestoreService firestoreService;

  const MedicalHistory({
    Key? key,
    required this.firestoreService,
  }) : super(key: key);

  @override
  State<MedicalHistory> createState() => _MedicalHistoryState();
}

class _MedicalHistoryState extends State<MedicalHistory> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique médical'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.firestoreService.getPatientAppointmentsHistory(_auth.currentUser?.uid ?? ''),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data?.docs ?? [];
          if (appointments.isEmpty) {
            return const Center(
              child: Text(
                'Aucun historique disponible',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index].data() as Map<String, dynamic>;
              return _buildHistoryCard(appointment);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> appointment) {
    final date = appointment['date'] as String;
    final time = appointment['time'] as String;
    final status = appointment['status'] as String;
    final doctorName = appointment['doctorName'] as String? ?? 'Médecin non spécifié';
    final reason = appointment['reason'] as String? ?? 'Raison non spécifiée';
    final notes = appointment['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dr. $doctorName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.calendar_today, 'Date', date),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time, 'Heure', time),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.medical_services, 'Motif', reason),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow(Icons.note, 'Notes', notes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'terminé':
        color = Colors.green;
        text = 'Terminé';
        break;
      case 'annulé':
        color = Colors.red;
        text = 'Annulé';
        break;
      default:
        color = Colors.grey;
        text = 'Inconnu';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
} 