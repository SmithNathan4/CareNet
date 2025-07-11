import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorConsultationsHistory extends StatelessWidget {
  const DoctorConsultationsHistory({Key? key}) : super(key: key);

  Future<Map<String, dynamic>?> _getPatientInfo(String patientId) async {
    try {
      if (patientId.isEmpty) {
        return null;
      }

      // Essayer de récupérer depuis UserPatient
      final doc = await FirebaseFirestore.instance.collection('UserPatient').doc(patientId).get();
      
      if (doc.exists) {
        final patientData = doc.data() as Map<String, dynamic>;
        return {
          'name': patientData['name'] ?? 'Patient',
          'phoneNumber': patientData['phoneNumber'] ?? '',
          'email': patientData['email'] ?? '',
          'address': patientData['address'] ?? '',
          'profileImageUrl': patientData['profileImageUrl'] ?? '',
        };
      }
      
      // Si le patient n'est pas trouvé dans UserPatient, essayer de récupérer depuis les consultations
      final consultationQuery = await FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: patientId)
          .limit(1)
          .get();
      
      if (consultationQuery.docs.isNotEmpty) {
        final consultationData = consultationQuery.docs.first.data();
        final patientName = consultationData['patientName']?.toString();
        if (patientName != null && patientName.isNotEmpty) {
          return {
            'name': patientName,
            'phoneNumber': consultationData['patientPhone']?.toString() ?? '',
            'email': consultationData['patientEmail']?.toString() ?? '',
            'address': consultationData['patientAddress']?.toString() ?? '',
            'profileImageUrl': consultationData['patientPhoto']?.toString() ?? '',
          };
        }
      }
      
      return null;
    } catch (e) {
      print('Erreur lors de la récupération des informations du patient $patientId: $e');
      return null;
    }
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

  // Calculer le montant total des consultations
  int _calculateTotalAmount(List<QueryDocumentSnapshot> consultations) {
    int total = 0;
    for (final doc in consultations) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = data['amount'];
      if (amount != null) {
        if (amount is int) {
          total += amount;
        } else if (amount is double) {
          total += amount.toInt();
        } else if (amount is String) {
          total += int.tryParse(amount) ?? 0;
        }
      }
    }
    return total;
  }

  // Obtenir le statut de consultation avec couleur
  Widget _getConsultationStatus(String? status) {
    String label;
    Color color;
    IconData icon;

    if (status == 'active' || status == 'en cours') {
      label = 'En cours';
      color = Colors.orange;
      icon = Icons.schedule;
    } else if (status == 'terminated' || status == 'completed' || status == 'terminé') {
      label = 'Terminé';
      color = Colors.green;
      icon = Icons.check_circle;
    } else {
      label = 'En attente';
      color = Colors.grey;
      icon = Icons.help_outline;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des consultations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          
          // Calculer les consultations en cours
          final inProgress = consultations.where((c) {
            final data = c.data() as Map<String, dynamic>;
            final status = data['status'] ?? data['consultationStatus'] ?? '';
            return status == 'active' || status == 'en cours';
          }).length;

          // Calculer le montant total
          final totalAmount = _calculateTotalAmount(consultations);

          // Séparer les consultations en cours et terminées
          final activeConsultations = consultations.where((c) {
            final data = c.data() as Map<String, dynamic>;
            final status = data['status'] ?? data['consultationStatus'] ?? '';
            return status == 'active' || status == 'en cours';
          }).toList();

          final completedConsultations = consultations.where((c) {
            final data = c.data() as Map<String, dynamic>;
            final status = data['status'] ?? data['consultationStatus'] ?? '';
            return status == 'terminated' || status == 'completed' || status == 'terminé';
          }).toList();

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('ratings')
                .where('doctorId', isEqualTo: doctorId)
                .get(),
            builder: (context, ratingSnap) {
              final totalRatings = ratingSnap.data?.docs.length ?? 0;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carte de statistiques
                    Container(
                      margin: const EdgeInsets.all(16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Statistiques des consultations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('Total', totalConsultations, Colors.blue),
                              _buildStat('En cours', inProgress, Colors.orange),
                              _buildStat('Évaluations', totalRatings, Colors.amber),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.monetization_on, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Montant total: ${totalAmount.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Section des consultations en cours
                    if (activeConsultations.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.schedule, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Consultations en cours (${activeConsultations.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...activeConsultations.map((doc) => _buildConsultationCard(doc, true)).toList(),
                      const Divider(),
                    ],

                    // Section des consultations terminées
                    if (completedConsultations.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Consultations terminées (${completedConsultations.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...completedConsultations.map((doc) => _buildConsultationCard(doc, false)).toList(),
                    ],

                    // Message si aucune consultation
                    if (consultations.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Aucune consultation trouvée',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildConsultationCard(QueryDocumentSnapshot doc, bool isActive) {
    final c = doc.data() as Map<String, dynamic>;
    final patientId = c['patientId'];
    final consultationId = doc.id;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getPatientInfo(patientId),
      builder: (context, patientSnap) {
        final patient = patientSnap.data;
        final address = patient?['address'] ?? c['patientAddress'] ?? '';
        
        return FutureBuilder<Map<String, dynamic>?>(
          future: _getConsultationRating(consultationId),
          builder: (context, ratingSnap) {
            final rating = ratingSnap.data;
            final consultationStatus = c['status'] ?? c['consultationStatus'] ?? '';
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              elevation: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isActive ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: _getProfileImage(c, patient),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient?['name'] ?? 'Patient inconnu',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (patient?['phoneNumber'] != null && patient!['phoneNumber'].toString().isNotEmpty)
                              Text(
                                '📞 ${patient['phoneNumber']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive 
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? Colors.orange : Colors.green,
                            width: 1,
                          ),
                        ),
                        child: _getConsultationStatus(consultationStatus),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
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
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.medical_services, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Motif : ${c['reason']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (c['amount'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.attach_money, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Montant : ${c['amount']} FCFA',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (c['paymentMethod'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.payment, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Paiement : ${c['paymentMethod']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      if (rating != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${rating['rating'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (rating['comment'] != null && rating['comment'].toString().isNotEmpty)
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      '"${rating['comment']}"',
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (c['createdAt'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Créée le : ${_formatDate(c['createdAt'])}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      if (c['endedAt'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Terminée le : ${_formatDate(c['endedAt'])}',
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Date inconnue';
  }

  ImageProvider _getProfileImage(Map<String, dynamic> c, Map<String, dynamic>? patient) {
    // Priorité aux informations récupérées depuis Firestore
    final profileUrl = patient?['profileImageUrl'];
    if (profileUrl != null && profileUrl is String && profileUrl.isNotEmpty) {
      return NetworkImage(profileUrl);
    }
    
    // Fallback sur les informations de la consultation
    final photoUrl = c['patientPhoto'];
    if (photoUrl != null && photoUrl is String && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    
    // Image par défaut
    return const AssetImage('assets/default_profile.png');
  }
} 