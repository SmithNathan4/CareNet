import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/appointment_service.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class MyAppointments extends StatefulWidget {
  final AppointmentService appointmentService;

  const MyAppointments({
    Key? key,
    required this.appointmentService,
  }) : super(key: key);

  @override
  _MyAppointmentsState createState() => _MyAppointmentsState();
}

class _MyAppointmentsState extends State<MyAppointments> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _consultations = [];
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  // Cache local pour éviter de recharger plusieurs fois le même médecin
  final Map<String, Map<String, dynamic>> _doctorCache = {};

  @override
  void initState() {
    super.initState();
    _loadConsultations();
    _loadStats();
  }

  Future<void> _loadConsultations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final consultations = await widget.appointmentService.getPatientConsultations(userId);
      
      if (mounted) {
        setState(() {
          _consultations = consultations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des consultations: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final stats = await widget.appointmentService.getPatientStats(userId);
      
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des statistiques: $e');
    }
  }

  Future<Map<String, dynamic>> _getDoctorInfo(String doctorId) async {
    if (_doctorCache.containsKey(doctorId)) {
      return _doctorCache[doctorId]!;
    }
    final doc = await FirebaseFirestore.instance.collection('UserDoctor').doc(doctorId).get();
    final data = doc.data() ?? {};
    _doctorCache[doctorId] = data;
    return data;
  }

  void _navigateToChat(String doctorId, String doctorName, String? doctorPhoto) async {
    try {
      // Récupérer le nom du patient depuis Firestore
      final patientDoc = await FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(_auth.currentUser?.uid)
          .get();
      
      String patientName = 'Patient';
      if (patientDoc.exists) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        patientName = patientData['name'] ?? 'Patient';
      }

      Navigator.pushNamed(
        context,
        AppRoutes.chat,
        arguments: {
          'chatId': '', // Sera créé automatiquement
          'currentUserId': _auth.currentUser?.uid ?? '',
          'currentUserName': patientName,
          'otherParticipantId': doctorId,
          'otherParticipantName': doctorName,
          'otherParticipantPhoto': doctorPhoto,
        },
      );
    } catch (e) {
      print('Erreur lors de la récupération du nom du patient: $e');
      // Fallback avec le nom par défaut
    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: {
        'chatId': '', // Sera créé automatiquement
        'currentUserId': _auth.currentUser?.uid ?? '',
          'currentUserName': 'Patient',
        'otherParticipantId': doctorId,
        'otherParticipantName': doctorName,
        'otherParticipantPhoto': doctorPhoto,
      },
    );
  }
  }

  String _getStatutLabel(String consultationStatus) {
    if (consultationStatus == 'active') return 'En cours';
    if (consultationStatus == 'terminated') return 'Terminée';
    return 'Inconnu';
  }

  IconData _getStatutIcon(String consultationStatus) {
    if (consultationStatus == 'active') return Icons.schedule;
    if (consultationStatus == 'terminated') return Icons.check_circle;
    return Icons.help_outline;
  }

  Color _getStatutColor(String consultationStatus) {
    if (consultationStatus == 'active') return Colors.orange;
    if (consultationStatus == 'terminated') return Colors.green;
    return Colors.grey;
  }

  int _getMontantConsultation(Map<String, dynamic> c) {
    int total = 0;
    if (c['payments'] is List) {
      for (final p in c['payments']) {
        if (p is Map && p['amount'] != null) {
          total += (p['amount'] as num).toInt();
        }
      }
    } else if (c['amount'] != null) {
      total += (c['amount'] as num).toInt();
    }
    return total;
  }

  String _getPaymentMethod(Map<String, dynamic> c) {
    if (c['payments'] is List && (c['payments'] as List).isNotEmpty) {
      final last = (c['payments'] as List).last;
      if (last is Map && last['method'] != null) {
        return last['method'].toString();
      }
    }
    return c['paymentMethod']?.toString() ?? '-';
  }

  // Calcule le montant total dépensé par médecin
  Map<String, int> _getMontantParMedecin() {
    final Map<String, int> map = {};
    for (final c in _consultations) {
      final doctorId = c['doctorId'] ?? '';
      int montant = 0;
      if (c['payments'] is List) {
        for (final p in c['payments']) {
          if (p is Map && p['amount'] != null) {
            montant += (p['amount'] as num).toInt();
          }
        }
      } else if (c['amount'] != null) {
        montant += (c['amount'] as num).toInt();
      }
      map[doctorId] = (map[doctorId] ?? 0) + montant;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final montantParMedecin = _getMontantParMedecin();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Consultations'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau',
            onPressed: () async {
              final result = await showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
                items: [
                  const PopupMenuItem<String>(
                    value: 'consulter',
                    child: Text('Consulter un médecin'),
                  ),
                ],
              );
              if (result == 'consulter') {
                Navigator.pushNamed(context, AppRoutes.doctorList, arguments: {'showBack': true});
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStatsCard(montantParMedecin),
                  if (_consultations.any((c) => c['consultationStatus'] == 'terminated'))
                    _buildSectionTitle('Consultations payées'),
                  if (_consultations.any((c) => c['consultationStatus'] == 'terminated'))
                    ..._consultations.where((c) => c['consultationStatus'] == 'terminated').map((c) => _buildConsultationCard(c, montantParMedecin)).toList(),
                  if (_consultations.any((c) => c['consultationStatus'] == 'active'))
                    _buildSectionTitle('Consultations en attente'),
                  if (_consultations.any((c) => c['consultationStatus'] == 'active'))
                    ..._consultations.where((c) => c['consultationStatus'] == 'active').map((c) => _buildConsultationCard(c, montantParMedecin)).toList(),
                  if (_consultations.isEmpty) _buildEmptyState(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard(Map<String, int> montantParMedecin) {
    // Calcul des statistiques dynamiquement
    final totalConsultations = _consultations.length;
    final consultationsPayees = _consultations.where((c) => c['consultationStatus'] == 'terminated').length;
    int montantTotal = 0;
    for (final c in _consultations) {
      if (c['payments'] is List) {
        for (final p in c['payments']) {
          if (p is Map && p['amount'] != null) {
            montantTotal += (p['amount'] as num).toInt();
          }
        }
      } else if (c['amount'] != null) {
        montantTotal += (c['amount'] as num).toInt();
      }
    }
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total',
              '$totalConsultations',
              Icons.medical_services,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Payées',
              '$consultationsPayees',
              Icons.check_circle,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Montant',
              '$montantTotal FCFA',
              Icons.payment,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune consultation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez pas encore de consultations.\nConsultez un médecin pour commencer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.doctorList);
            },
            icon: const Icon(Icons.search),
            label: const Text('Consulter un médecin'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationsList(Map<String, int> montantParMedecin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _consultations.length,
      itemBuilder: (context, index) {
        final consultation = _consultations[index];
        return _buildConsultationCard(consultation, montantParMedecin);
      },
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> consultation, Map<String, int> montantParMedecin) {
    final createdAt = consultation['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(createdAt.toDate())
        : 'Date inconnue';
    final consultationStatus = consultation['consultationStatus'] ?? '';
    final statutLabel = _getStatutLabel(consultationStatus);
    final statutIcon = _getStatutIcon(consultationStatus);
    final statutColor = _getStatutColor(consultationStatus);
    final montant = _getMontantConsultation(consultation);
    final method = _getPaymentMethod(consultation);
    final doctorId = consultation['doctorId'] ?? '';
    final montantMedecin = montantParMedecin[doctorId] ?? 0;
    return FutureBuilder<Map<String, dynamic>>(
      future: _getDoctorInfo(doctorId),
      builder: (context, snapshot) {
        final doctorData = snapshot.data ?? {};
        final doctorName = doctorData['name'] ?? 'Médecin inconnu';
        final doctorPhoto = doctorData['photoUrl'] ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: doctorPhoto.isNotEmpty
                          ? NetworkImage(doctorPhoto)
                          : null,
                      child: doctorPhoto.isEmpty
                          ? Icon(Icons.medical_services, size: 20, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. $doctorName',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (montantMedecin > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                'Total dépensé chez ce médecin : $montantMedecin FCFA',
                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statutColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statutColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(statutIcon, size: 16, color: statutColor),
                          const SizedBox(width: 4),
                          Text(
                            statutLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: statutColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (consultation['reason']?.isNotEmpty == true) ...[
                  Text(
                    'Motif: ${consultation['reason']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.payment, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$montant FCFA',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.credit_card, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(
                      method,
                      style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
} 