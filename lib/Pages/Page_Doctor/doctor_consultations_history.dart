import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorConsultationsHistory extends StatelessWidget {
  const DoctorConsultationsHistory({Key? key}) : super(key: key);

  Future<Map<String, dynamic>?> _getPatientInfo(String patientId) async {
    final doc = await FirebaseFirestore.instance.collection('UserPatient').doc(patientId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>?> _getConsultationRating(String consultationId) async {
    final snap = await FirebaseFirestore.instance
        .collection('ratings')
        .where('appointmentId', isEqualTo: consultationId)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.data();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des consultations'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .where('doctorId', isEqualTo: doctorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final consultations = snapshot.data!.docs;
          final totalConsultations = consultations.length;
          final patientsIds = consultations.map((c) => (c.data() as Map<String, dynamic>)['patientId']).toSet();
          final totalPatients = patientsIds.length;
          final inProgress = consultations.where((c) {
            final data = c.data() as Map<String, dynamic>;
            return (data['status'] ?? '') == 'active';
          }).length;

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('ratings')
                .where('doctorId', isEqualTo: doctorId)
                .get(),
            builder: (context, ratingSnap) {
              final totalRatings = ratingSnap.data?.docs.length ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Patients', totalPatients, Colors.blue),
                        _buildStat('En cours', inProgress, Colors.orange),
                        _buildStat('Évaluations', totalRatings, Colors.amber),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: consultations.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final doc = consultations[index];
                        final c = doc.data() as Map<String, dynamic>;
                        final patientId = c['patientId'];
                        final consultationId = doc.id;
                        return FutureBuilder<Map<String, dynamic>?>(
                          future: _getPatientInfo(patientId),
                          builder: (context, patientSnap) {
                            final patient = patientSnap.data;
                            final address = c['patientAddress'] ?? patient?['address'] ?? '';
                            return FutureBuilder<Map<String, dynamic>?>(
                              future: _getConsultationRating(consultationId),
                              builder: (context, ratingSnap) {
                                final rating = ratingSnap.data;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: _getProfileImage(c, patient),
                                  ),
                                  title: Text(c['patientName'] ?? patient?['name'] ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (address.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                address,
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (c['reason'] != null)
                                        Text('Motif : ${c['reason']}'),
                                      if (c['amount'] != null)
                                        Text('Montant : ${c['amount']} FCFA'),
                                      if (c['paymentMethod'] != null)
                                        Text('Paiement : ${c['paymentMethod']}'),
                                      if (rating != null)
                                        Row(
                                          children: [
                                            Icon(Icons.star, color: Colors.amber, size: 16),
                                            Text('${rating['rating'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            if (rating['comment'] != null && rating['comment'].toString().isNotEmpty)
                                              Flexible(
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 8.0),
                                                  child: Text('"${rating['comment']}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                                                ),
                                              ),
                                          ],
                                        ),
                                      if (c['status'] != null)
                                        Text('Statut : ' + (c['status'] == 'completed' ? 'Terminé' : 'En cours'),
                                            style: TextStyle(
                                              color: c['status'] == 'completed' ? Colors.green : Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            )),
                                      if (c['dateTime'] != null)
                                        Text('Date : ' + (c['dateTime'] is Timestamp
                                            ? (c['dateTime'] as Timestamp).toDate().toString().substring(0, 16)
                                            : c['dateTime'].toString())),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  ImageProvider _getProfileImage(Map<String, dynamic> c, Map<String, dynamic>? patient) {
    final photoUrl = c['patientPhoto'];
    final profileUrl = patient?['profileImageUrl'];
    if (photoUrl != null && photoUrl is String && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    } else if (profileUrl != null && profileUrl is String && profileUrl.isNotEmpty) {
      return NetworkImage(profileUrl);
    } else {
      return const AssetImage('assets/default_profile.png');
    }
  }
} 