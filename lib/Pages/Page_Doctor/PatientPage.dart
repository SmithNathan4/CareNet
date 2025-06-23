import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientPage extends StatelessWidget {
  final String patientId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PatientPage({Key? key, required this.patientId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil du patient'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('UserPatient').doc(patientId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Patient non trouvé'));
          }

          final patientData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(patientData),
                _buildInfoSection(patientData),
                _buildMedicalHistory(patientData),
                _buildAppointmentHistory(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> patientData) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: patientData['photoUrl'] != null
                ? NetworkImage(patientData['photoUrl'])
                : const AssetImage('assets/default_profile.png') as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(
            patientData['name'] ?? 'Non spécifié',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Patient ID: $patientId',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> patientData) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations personnelles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow('Email', patientData['email'] ?? 'Non spécifié'),
            _buildInfoRow('Téléphone', patientData['phone'] ?? 'Non spécifié'),
            _buildInfoRow('Adresse', patientData['address'] ?? 'Non spécifiée'),
            _buildInfoRow('Date de naissance', patientData['birthDate'] != null
                ? DateFormat('dd/MM/yyyy').format((patientData['birthDate'] as Timestamp).toDate())
                : 'Non spécifiée'),
            _buildInfoRow('Groupe sanguin', patientData['bloodGroup'] ?? 'Non spécifié'),
            _buildInfoRow('Genre', patientData['gender'] ?? 'Non spécifié'),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalHistory(Map<String, dynamic> patientData) {
    final List<dynamic> conditions = patientData['medicalConditions'] ?? [];
    final List<dynamic> allergies = patientData['allergies'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique médical',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const Text(
              'Conditions médicales:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (conditions.isEmpty)
              const Text('Aucune condition médicale enregistrée')
            else
              Column(
                children: conditions
                    .map((condition) => ListTile(
                          leading: const Icon(Icons.medical_services),
                          title: Text(condition),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            const Text(
              'Allergies:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (allergies.isEmpty)
              const Text('Aucune allergie enregistrée')
            else
              Column(
                children: allergies
                    .map((allergy) => ListTile(
                          leading: const Icon(Icons.warning),
                          title: Text(allergy),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentHistory(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('appointments')
            .where('patientId', isEqualTo: patientId)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Derniers rendez-vous',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                if (appointments.isEmpty)
                  const Text('Aucun rendez-vous')
                else
                  Column(
                    children: appointments.map((appointment) {
                      final data = appointment.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['reason'] ?? 'Consultation générale'),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(
                            (data['timestamp'] as Timestamp).toDate(),
                          ),
                        ),
                        trailing: _getStatusChip(data['status']),
                      );
                    }).toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _getStatusChip(String? status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'En attente';
        break;
      case 'accepted':
        color = Colors.green;
        text = 'Accepté';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Refusé';
        break;
      default:
        color = Colors.grey;
        text = 'Inconnu';
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
} 