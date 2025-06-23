import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase/firestore.dart';
import 'package:intl/intl.dart';

class AppointmentRequests extends StatefulWidget {
  const AppointmentRequests({super.key});

  @override
  State<AppointmentRequests> createState() => _AppointmentRequestsState();
}

class _AppointmentRequestsState extends State<AppointmentRequests> {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes de consultation'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .where('status', isEqualTo: 'paid')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final appointments = snapshot.data?.docs ?? [];

          if (appointments.isEmpty) {
            return const Center(
              child: Text('Aucune nouvelle demande'),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appointment = appointments[index].data() as Map<String, dynamic>;
              final appointmentId = appointments[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('UserPatient')
                    .doc(appointment['patientId'])
                    .get(),
                builder: (context, patientSnapshot) {
                  if (!patientSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final patientData = patientSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: patientData['profileImageUrl'] != null
                                    ? NetworkImage(patientData['profileImageUrl'])
                                    : null,
                                child: patientData['profileImageUrl'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patientData['name'] ?? 'Patient',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Motif: ${appointment['reason']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Montant: ${appointment['amount']} FCFA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Vérifier que les IDs ne sont pas vides
                                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                  final patientId = appointment['patientId'];

                                  if (currentUserId == null || currentUserId.isEmpty || patientId == null || patientId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Erreur: ID utilisateur manquant'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Récupérer les informations du docteur
                                  final doctorDoc = await FirebaseFirestore.instance
                                      .collection('UserDoctor')
                                      .doc(currentUserId)
                                      .get();

                                  if (!doctorDoc.exists) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Erreur: Informations du médecin non trouvées'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final doctorData = doctorDoc.data()!;
                                  final doctorName = doctorData['name'] as String?;

                                  if (doctorName == null || doctorName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Erreur: Nom du médecin non trouvé'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  if (mounted) {
                                    Navigator.pushNamed(
                                      context,
                                      '/chat',
                                      arguments: {
                                        'currentUserId': currentUserId,
                                        'currentUserName': 'Dr. $doctorName',
                                        'currentUserRole': 'doctor',
                                        'recipientId': patientId,
                                        'recipientName': patientData['name'] ?? 'Patient',
                                        'recipientRole': 'patient',
                                        'recipientPhoto': patientData['profileImageUrl'],
                                      },
                                    );
                                  }
                                },
                                icon: const Icon(Icons.chat),
                                label: const Text('Contacter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    try {
      String? message;
      if (status == 'accepted') {
        message = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Message au patient'),
            content: TextField(
              decoration: const InputDecoration(
                hintText: 'Entrez votre message au patient (optionnel)',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final TextEditingController controller = context.findAncestorWidgetOfExactType<TextField>()?.controller as TextEditingController;
                  Navigator.pop(context, controller.text);
                },
                child: const Text('Continuer'),
              ),
            ],
          ),
        );
        
        if (message == null) return; // L'utilisateur a annulé
      }

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (message != null && message.isNotEmpty) 'doctorMessage': message,
      });

      // Récupérer les informations de la demande
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();
      
      final appointmentData = appointmentDoc.data()!;
      final patientId = appointmentData['patientId'];
      final doctorId = appointmentData['doctorId'];

      // Créer une notification pour le patient
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': patientId,
        'title': status == 'accepted' ? 'Demande acceptée' : 'Demande refusée',
        'body': status == 'accepted' 
            ? message != null && message.isNotEmpty
                ? message
                : 'Le médecin a accepté votre demande de consultation'
            : 'Le médecin a refusé votre demande de consultation',
        'type': 'appointment_response',
        'appointmentId': appointmentId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted' ? 'Demande acceptée' : 'Demande refusée'
            ),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du statut: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 