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

  void _navigateToChat(String doctorId, String doctorName, String? doctorPhoto) {
    Navigator.pushNamed(
      context,
      AppRoutes.chat,
      arguments: {
        'chatId': '', // Sera créé automatiquement
        'currentUserId': _auth.currentUser?.uid ?? '',
        'currentUserName': _auth.currentUser?.displayName ?? 'Patient',
        'otherParticipantId': doctorId,
        'otherParticipantName': doctorName,
        'otherParticipantPhoto': doctorPhoto,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Consultations'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: _consultations.isEmpty
                      ? _buildEmptyState()
                      : _buildConsultationsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
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
              '${_stats['totalConsultations'] ?? 0}',
              Icons.medical_services,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Actives',
              '${_stats['activeConsultations'] ?? 0}',
              Icons.check_circle,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Montant',
              '${_stats['totalAmount'] ?? 0} FCFA',
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

  Widget _buildConsultationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _consultations.length,
      itemBuilder: (context, index) {
        final consultation = _consultations[index];
        return _buildConsultationCard(consultation);
      },
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> consultation) {
    final createdAt = consultation['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? DateFormat('dd/MM/yyyy à HH:mm').format(createdAt.toDate())
        : 'Date inconnue';

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
                  backgroundImage: consultation['doctorPhoto']?.isNotEmpty == true
                      ? NetworkImage(consultation['doctorPhoto'])
                      : null,
                  child: consultation['doctorPhoto']?.isEmpty != false
                      ? Icon(Icons.medical_services, size: 20, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${consultation['doctorName'] ?? 'Médecin inconnu'}',
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
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(consultation['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(consultation['status']).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusText(consultation['status']),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(consultation['status']),
                      fontWeight: FontWeight.w500,
                    ),
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
                  '${consultation['amount'] ?? 0} FCFA - ${consultation['paymentMethod'] ?? 'Paiement'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _navigateToChat(
                        consultation['doctorId'],
                        consultation['doctorName'],
                        consultation['doctorPhoto'],
                      );
                    },
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigation vers les détails de la consultation
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Détails'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }
} 