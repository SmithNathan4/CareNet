import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carenet/services/firebase/firestore.dart';
import 'package:carenet/Pages/Payment/payment_methods.dart';
import 'package:carenet/routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Appointment extends StatefulWidget {
  final String doctorId;

  const Appointment({Key? key, required this.doctorId}) : super(key: key);

  @override
  _AppointmentState createState() => _AppointmentState();
}

class _AppointmentState extends State<Appointment> {
  final TextEditingController _reasonController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  Map<String, dynamic>? _doctorData;
  bool _isSubmitting = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double? _tarif;
  bool _hasActiveConsultation = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadDoctorData();
    await _loadTarif();
    await _checkActiveConsultation();
  }

  Future<void> _loadDoctorData() async {
    try {
      final doctorData = await _firestoreService.getDoctorById(widget.doctorId);
      setState(() {
        _doctorData = doctorData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _loadTarif() async {
    final tarif = await _firestoreService.getGlobalTarif();
    if (mounted) setState(() => _tarif = tarif);
  }

  Future<void> _checkActiveConsultation() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final existingActiveConsultation = await FirebaseFirestore.instance
        .collection('consultations')
        .where('patientId', isEqualTo: user.uid)
        .where('doctorId', isEqualTo: widget.doctorId)
        .where('status', isEqualTo: 'active')
        .get();
    if (mounted) {
      setState(() {
        _hasActiveConsultation = existingActiveConsultation.docs.isNotEmpty;
      });
    }
  }

  Future<void> _submitAppointment() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentMethods(
            doctorId: widget.doctorId,
            doctorName: _doctorData!['name'],
            reason: _reasonController.text,
            patientId: _auth.currentUser?.uid ?? '',
            patientName: _auth.currentUser?.displayName ?? 'Patient',
            patientPhoto: _auth.currentUser?.photoURL,
            doctorPhoto: _doctorData!['photoUrl'],
            onPaymentSuccess: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_doctorData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
        ),
        body: const Center(
          child: Text('Impossible de charger les informations du médecin'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;
        final isDesktop = screenWidth > 1024;
        final isMobile = screenWidth <= 600;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: _buildAppBar(isDark),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 120 : isTablet ? 40 : 0,
                vertical: isDesktop ? 40 : isTablet ? 24 : 0,
              ),
              child: _buildBody(isDark),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text('Prendre rendez-vous'),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Theme.of(context).primaryColor,
      elevation: 0,
      shape: null,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildBody(bool isDark) {
    return SingleChildScrollView(
      child: Card(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 2,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: (_doctorData!['photoUrl'] != null && _doctorData!['photoUrl'].toString().isNotEmpty)
                              ? NetworkImage(_doctorData!['photoUrl'])
                              : const AssetImage('assets/default_profile.png') as ImageProvider,
                          child: (_doctorData!['photoUrl'] == null || _doctorData!['photoUrl'].toString().isEmpty)
                              ? null
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dr. ${_doctorData!['name']}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _doctorData!['speciality'] ?? 'Médecin généraliste',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem(
                      Icons.location_on,
                      'Adresse',
                      _doctorData!['address'] ?? 'Non spécifiée',
                    ),
                    _buildDetailItem(
                      Icons.medical_services,
                      'Spécialité',
                      _doctorData!['speciality'] ?? 'Non spécifiée',
                    ),
                    _buildDetailItem(
                      Icons.payment,
                      'Tarif consultation',
                      '${_tarif?.toStringAsFixed(0) ?? "-"} FCFA',
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.doctorPage,
                            arguments: {
                              'doctorId': widget.doctorId,
                            },
                          );
                        },
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Voir plus d\'informations'),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motif de consultation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Décrivez brièvement votre motif de consultation...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF232323) : Colors.white,
                        labelStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
                      ),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: _hasActiveConsultation
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Vous avez déjà une consultation en cours avec ce médecin.',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitAppointment,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'Contacter le medecin',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}