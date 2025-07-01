import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientPage extends StatelessWidget {
  final String patientId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PatientPage({Key? key, required this.patientId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark ? const Color(0xFF121212) : Colors.grey[50]!;
    final Color cardColor = isDark ? const Color(0xFF232323) : Colors.white;
    final Color mainText = isDark ? Colors.white : Colors.black87;
    final Color subText = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    final Color divider = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Profil du patient'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.blue,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('UserPatient').doc(patientId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}', style: TextStyle(color: mainText)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Patient non trouvé', style: TextStyle(color: mainText)));
          }
          final patientData = snapshot.data!.data() as Map<String, dynamic>;
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        _buildHeader(context, patientData, isDark, mainText, subText),
                        _buildInfoSection(context, patientData, cardColor, mainText, subText, divider, isDark),
                        _buildMedicalHistory(context, patientData, cardColor, mainText, subText, divider, isDark),
                        _buildAppointmentHistory(context, cardColor, mainText, subText, divider, isDark),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> patientData, bool isDark, Color mainText, Color subText) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF232323), const Color(0xFF1E1E1E)]
              : [Colors.blue.shade700, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            backgroundImage: (patientData['profileImageUrl'] != null && patientData['profileImageUrl'].toString().isNotEmpty)
                ? NetworkImage(patientData['profileImageUrl'])
                : const AssetImage('assets/default_profile.png') as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(
            patientData['name'] ?? 'Non spécifié',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            patientData['email'] ?? 'Email non défini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          if (patientData['phoneNumber'] != null && patientData['phoneNumber'].toString().isNotEmpty)
            Text(
              patientData['phoneNumber'],
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          if (patientData['address'] != null && patientData['address'].toString().isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    patientData['address'],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Map<String, dynamic> patientData, Color cardColor, Color mainText, Color subText, Color divider, bool isDark) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue, size: 22),
                const SizedBox(width: 8),
                Text('Informations personnelles', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: mainText)),
              ],
            ),
            Divider(color: divider, height: 24),
            _buildInfoRow('Adresse', patientData['address'] ?? 'Non spécifiée', mainText, subText),
            _buildInfoRow('Date de naissance', patientData['birthDate'] != null
                ? DateFormat('dd/MM/yyyy').format((patientData['birthDate'] as Timestamp).toDate())
                : 'Non spécifiée', mainText, subText),
            _buildInfoRow('Groupe sanguin', patientData['bloodGroup'] ?? 'Non spécifié', mainText, subText),
            _buildInfoRow('Genre', patientData['gender'] ?? 'Non spécifié', mainText, subText),
            _buildInfoRow('Taille', patientData['height'] != null && patientData['height'] > 0 ? '${patientData['height']} m' : 'Non spécifiée', mainText, subText),
            _buildInfoRow('Poids', patientData['weight'] != null && patientData['weight'] > 0 ? '${patientData['weight']} kg' : 'Non spécifié', mainText, subText),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalHistory(BuildContext context, Map<String, dynamic> patientData, Color cardColor, Color mainText, Color subText, Color divider, bool isDark) {
    final String? medicalHistory = patientData['medicalHistoryDescription'];
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: isDark ? Colors.blue[300] : Colors.blue, size: 22),
                const SizedBox(width: 8),
                Text('Antécédents médicaux', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: mainText)),
              ],
            ),
            Divider(color: divider, height: 24),
            if (medicalHistory != null && medicalHistory.trim().isNotEmpty)
              Text(medicalHistory, style: TextStyle(color: mainText, fontSize: 16))
            else
              Text('Aucun antécédent médical renseigné', style: TextStyle(color: subText, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentHistory(BuildContext context, Color cardColor, Color mainText, Color subText, Color divider, bool isDark) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('consultations')
            .where('patientId', isEqualTo: patientId)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final appointments = snapshot.data!.docs;
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: isDark ? Colors.blue[300] : Colors.blue, size: 22),
                    const SizedBox(width: 8),
                    Text('Derniers rendez-vous', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: mainText)),
                  ],
                ),
                Divider(color: divider, height: 24),
                if (appointments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucun rendez-vous', style: TextStyle(color: subText)),
                  )
                else
                  Column(
                    children: appointments.map((appointment) {
                      final data = appointment.data() as Map<String, dynamic>;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        leading: Icon(Icons.calendar_today, color: isDark ? Colors.blue[200] : Colors.blue),
                        title: Text(data['reason'] ?? 'Consultation générale', style: TextStyle(color: mainText)),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(
                            (data['timestamp'] as Timestamp).toDate(),
                          ),
                          style: TextStyle(color: subText),
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

  Widget _buildInfoRow(String label, String value, Color mainText, Color subText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: subText,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: mainText)),
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