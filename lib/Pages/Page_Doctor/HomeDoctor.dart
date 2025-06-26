import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/firebase/firestore.dart';
import '../../services/firebase/auth.dart';
import '../Page_Doctor/PatientList.dart';
import '../Chat/conversations_list.dart';
import '../ParametreDoctor/settingsDoctor.dart';
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;

class HomeDoctor extends StatefulWidget {
  final FirestoreService firestoreService;

  const HomeDoctor({
    Key? key,
    required this.firestoreService,
  }) : super(key: key);

  @override
  State<HomeDoctor> createState() => _HomeDoctorState();
}

class _HomeDoctorState extends State<HomeDoctor> {
  late FirestoreService _firestoreService;
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;
  int _currentMainIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  bool _showEmojiPicker = false;
  final TextEditingController _messageController = TextEditingController();

  // Color Scheme
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _secondaryColor = const Color(0xFFE3F2FD);
  final Color _accentColor = const Color(0xFF42A5F5);
  final Color _textColor = const Color(0xFF0D47A1);

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService;
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _initializeDoctorStatus();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authService = AuthService();
    if (!authService.isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  // Initialiser le statut du docteur s'il n'en a pas
  Future<void> _initializeDoctorStatus() async {
    try {
      final doctorDoc = await _firestore
          .collection('UserDoctor')
          .doc(_auth.currentUser?.uid)
          .get();
      
      if (doctorDoc.exists) {
        final data = doctorDoc.data() as Map<String, dynamic>?;
        if (data != null && !data.containsKey('status')) {
          // Si le docteur n'a pas de statut, on l'initialise à 'disponible'
          await _firestoreService.updateDoctorStatus(
            uid: _auth.currentUser!.uid,
            status: 'disponible',
          );
        }
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation du statut: $e');
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      // Recherche dans plusieurs champs
      final results = await _firestoreService.searchPatientsByName(query);
      
      // Recherche supplémentaire par email et téléphone
      final emailResults = await _firestoreService.searchPatientsByEmail(query);
      final phoneResults = await _firestoreService.searchPatientsByPhone(query);
      
      // Combiner et dédupliquer les résultats
      final allResults = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      
      void addResult(Map<String, dynamic> result) {
        if (!seenIds.contains(result['id'])) {
          seenIds.add(result['id']);
          allResults.add(result);
        }
      }
      
      // Ajouter les résultats de recherche par nom
      for (final doc in results) {
        final data = doc.data() as Map<String, dynamic>;
        addResult({
          'id': doc.id,
          'name': data['name'] ?? 'Patient',
          'email': data['email'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'lastConsultation': data['lastConsultation'],
          'consultationCount': data['consultationCount'] ?? 0,
          'status': data['status'] ?? 'actif',
        });
      }
      
      // Ajouter les résultats de recherche par email
      for (final doc in emailResults) {
        final data = doc.data() as Map<String, dynamic>;
        addResult({
          'id': doc.id,
          'name': data['name'] ?? 'Patient',
          'email': data['email'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'lastConsultation': data['lastConsultation'],
          'consultationCount': data['consultationCount'] ?? 0,
          'status': data['status'] ?? 'actif',
        });
      }
      
      // Ajouter les résultats de recherche par téléphone
      for (final doc in phoneResults) {
        final data = doc.data() as Map<String, dynamic>;
        addResult({
          'id': doc.id,
          'name': data['name'] ?? 'Patient',
          'email': data['email'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'lastConsultation': data['lastConsultation'],
          'consultationCount': data['consultationCount'] ?? 0,
          'status': data['status'] ?? 'actif',
        });
      }
      
      setState(() {
        _searchResults = allResults;
        _showSearchResults = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur lors de la recherche'),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<int> _getTotalPendingRequests() async {
    final QuerySnapshot snapshot = await _firestore
        .collection('consultations')
        .where('doctorId', isEqualTo: _auth.currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.size;
  }

  Stream<int> _getPendingRequests() {
    return _firestore
        .collection('consultations')
        .where('doctorId', isEqualTo: _auth.currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> _openChat(Map<String, dynamic> patient) async {
    try {
      final String currentUserId = _auth.currentUser!.uid;
      final List<String> ids = [currentUserId, patient['id']];
      ids.sort();
      final String chatRoomId = ids.join('_');

      final chatDoc = await _firestore.collection('chats').doc(chatRoomId).get();

      if (!chatDoc.exists) {
        final doctorDoc = await _firestore.collection('UserDoctor').doc(currentUserId).get();
        final doctorData = doctorDoc.data() ?? {};

        await _firestore.collection('chats').doc(chatRoomId).set({
          'participants': [currentUserId, patient['id']],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageTimestamp': null,
          'doctorInfo': {
            'id': currentUserId,
            'name': 'Dr. ${_auth.currentUser?.displayName ?? ''}',
            'photoUrl': doctorData['photoUrl'] ?? '',
            'speciality': doctorData['speciality'] ?? '',
            'role': 'doctor'
          },
          'patientInfo': {
            'id': patient['id'],
            'name': patient['name'],
            'photoUrl': patient['profileImageUrl'] ?? '',
            'role': 'patient'
          }
        });
      }

      if (mounted) {
        AppRoutes.navigateToChat(
          context,
          currentUserId: currentUserId,
          currentUserName: 'Dr. ${_auth.currentUser?.displayName ?? ''}',
          currentUserRole: 'doctor',
          recipientId: patient['id'],
          recipientName: patient['name'],
          recipientRole: 'patient',
          recipientPhoto: patient['profileImageUrl'] ?? '',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ouverture du chat: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatusIndicator() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(_auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final status = data?['status'] ?? 'hors_ligne';
        
        Color statusColor;
        String statusText;
        switch (status) {
          case 'disponible':
            statusColor = Colors.green;
            statusText = 'Disponible';
            break;
          case 'occupé':
            statusColor = Colors.orange;
            statusText = 'Occupé';
            break;
          default:
            statusColor = Colors.grey;
            statusText = 'Hors ligne';
        }

        return PopupMenuButton<String>(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          onSelected: (String newStatus) async {
            try {
              await _firestoreService.updateDoctorStatus(
                uid: _auth.currentUser!.uid,
                status: newStatus,
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Statut mis à jour : $statusText'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de la mise à jour du statut: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'disponible',
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 12),
                  SizedBox(width: 8),
                  Text('Disponible'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'occupé',
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.orange, size: 12),
                  SizedBox(width: 8),
                  Text('Occupé'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'hors_ligne',
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.grey, size: 12),
                  SizedBox(width: 8),
                  Text('Hors ligne'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('Aucun résultat trouvé'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final patient = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: patient['profileImageUrl'] != null
                ? NetworkImage(patient['profileImageUrl'])
                : null,
            child: patient['profileImageUrl'] == null
                ? Text(patient['name'][0].toUpperCase())
                : null,
          ),
          title: Text(patient['name']),
          subtitle: Text(patient['email']),
          onTap: () => _openChat(patient),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher un patient, un rendez-vous...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.search, color: Colors.blue, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) {
          // TODO: Implémenter la recherche
        },
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtres rapides',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tous les patients', Icons.people),
              _buildFilterChip('Consultations récentes', Icons.history),
              _buildFilterChip('Patients actifs', Icons.check_circle),
              _buildFilterChip('Nouveaux patients', Icons.person_add),
              _buildFilterChip('Patients urgents', Icons.priority_high),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: false,
        onSelected: (bool selected) {
          // Implémenter la logique de filtrage ici
        },
        backgroundColor: Colors.grey[100],
        selectedColor: _primaryColor.withOpacity(0.2),
        checkmarkColor: _primaryColor,
        labelStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
        ),
        side: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  Widget _buildAppointmentRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consultations')
          .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('status', isEqualTo: 'paid')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: TextStyle(color: _textColor),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, 'appointment_requests');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Demandes de consultation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${requests.length} nouvelle${requests.length > 1 ? 's' : ''} demande${requests.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, String requestId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: request['patientPhotoUrl']?.isNotEmpty == true
                    ? NetworkImage(request['patientPhotoUrl'])
                    : const AssetImage('assets/default_profile.png') as ImageProvider,
                onBackgroundImageError: (_, __) {
                  const AssetImage('assets/default_profile.png');
                },
            ),
              const SizedBox(width: 12),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['patientName'] ?? 'Patient inconnu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
                    Text(
                      'Date: ${_formatDate(request['date'])}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
              ),
            ),
          ],
        ),
              ),
      ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
      children: [
              TextButton(
                onPressed: () => _handleAppointmentRequest(requestId, 'refuse'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Refuser'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _handleAppointmentRequest(requestId, 'accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Accepter'),
              ),
            ],
        ),
      ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date non spécifiée';
    if (date is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(date.toDate());
    }
    return 'Date invalide';
  }

  Future<void> _handleAppointmentRequest(String requestId, String action) async {
    try {
      if (action == 'accept') {
        final message = await _showMessageDialog();
        if (message != null) {
          await _firestoreService.updateAppointmentRequest(
            requestId,
            'accepte',
            message: message,
          );
          await _firestoreService.sendMessageToPatient(
            requestId,
            message,
          );
        }
      } else {
        await _firestoreService.updateAppointmentRequest(
          requestId,
          'refuse',
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept' 
                ? 'Rendez-vous accepté' 
                : 'Rendez-vous refusé'
            ),
            backgroundColor: action == 'accept' ? Colors.green : Colors.red,
            ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            ),
        );
      }
    }
  }

  Future<String?> _showMessageDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message au patient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Entrez votre message au patient',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _messageController.text),
            child: const Text('Envoyer'),
          ),
          ],
      ),
    );
  }

  Widget _buildPatientReviews() {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ratings = snapshot.data?.docs ?? [];
        if (ratings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucun avis patient pour le moment.', style: TextStyle(color: Colors.grey)),
          );
        }
        final avg = ratings.map((r) => (r['rating'] ?? 0.0) as num).fold(0.0, (a, b) => a + b) / ratings.length;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                    Icons.star,
                    color: i < avg.round() ? Colors.amber : Colors.grey[300],
                    size: 22,
                  )),
                  const SizedBox(width: 8),
                  Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  Text('(${ratings.length} avis)', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 12),
              ...ratings.take(5).map((r) {
                final patientName = (r['patientInfo']?['name'] ?? 'Patient').toString();
                final comment = r['comment'] ?? '';
                final createdAt = r['createdAt'] != null && r['createdAt'] is Timestamp
                  ? DateFormat('dd/MM/yyyy').format((r['createdAt'] as Timestamp).toDate())
                  : '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ...List.generate(5, (i) => Icon(
                              Icons.star,
                              color: i < ((r['rating'] ?? 0.0) as num).round() ? Colors.amber : Colors.grey[300],
                              size: 18,
                            )),
                            const SizedBox(width: 8),
                            Text(createdAt, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(patientName, style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                          ],
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(comment),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
              if (ratings.length > 5)
                TextButton(
                  onPressed: () {
                    // TODO: Naviguer vers une page d'avis complète si besoin
                  },
                  child: const Text('Voir tous les avis'),
                ),
            ],
          ),
        );
      },
    );
  }

  // Contenu de la page d'accueil sans AppBar
  Widget _buildHomeContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;
        final isDesktop = screenWidth > 1024;
        final isMobile = screenWidth <= 600;
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 120 : isTablet ? 40 : 0,
              vertical: isDesktop ? 40 : isTablet ? 24 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatistics(),
                _buildPatientReviews(),
                SizedBox(height: isDesktop ? 40 : isTablet ? 24 : 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatistics() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.all(isTablet ? 30 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques du jour',
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: isTablet ? 24 : 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('consultations')
                      .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .where('status', isEqualTo: 'completed')
                      .where('paymentStatus', isEqualTo: 'paid')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final paidPatientsCount = snapshot.data?.docs.length ?? 0;
                    return _buildStatCard(
                      'Patients payés',
                      '$paidPatientsCount',
                      Icons.people,
                      Colors.green,
                    );
                  },
                ),
              ),
              SizedBox(width: isTablet ? 20 : 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .where('hasUnreadMessages', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final pendingMessagesCount = snapshot.data?.docs.length ?? 0;
                    return _buildStatCard(
                      'Messages en attente',
                      '$pendingMessagesCount',
                      Icons.message,
                      Colors.orange,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth <= 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(isTablet ? 30 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: isTablet ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: isTablet ? 24 : 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isTablet ? 3 : 2,
            crossAxisSpacing: isTablet ? 24 : 12,
            mainAxisSpacing: isTablet ? 24 : 12,
            childAspectRatio: isTablet ? 1.4 : 1.05,
            children: [
              _buildActionCard(
                'Nouveaux rendez-vous',
                Icons.calendar_today,
                Colors.blue,
                () => Navigator.pushNamed(context, AppRoutes.appointmentRequests),
              ),
              _buildActionCard(
                'Mes patients',
                Icons.people,
                Colors.green,
                () => Navigator.pushNamed(context, AppRoutes.patientList),
              ),
              _buildActionCard(
                'Messages',
                Icons.message,
                Colors.orange,
                () => Navigator.pushNamed(context, AppRoutes.conversations),
              ),
              _buildActionCard(
                'Mon profil',
                Icons.person,
                Colors.purple,
                () => Navigator.pushNamed(context, AppRoutes.profilDoctor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: isTablet ? 32 : 28,
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prochains rendez-vous',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigation vers tous les RDV
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('consultations')
                .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .where('status', isEqualTo: 'accepted')
                .orderBy('appointmentDate')
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final appointments = snapshot.data!.docs;
              
              if (appointments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Aucun rendez-vous à venir',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: appointments.map((appointment) {
                  final data = appointment.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.event, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['patientName'] ?? 'Patient',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                data['reason'] ?? 'Consultation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${data['appointmentTime'] ?? '--:--'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Pages principales sans AppBar (car elle sera dans le Scaffold principal)
  List<Widget> get _mainPages => [
    _buildHomeContent(),
    const PatientList(showAppBar: false),
    ConversationsList(
      currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
      currentUserName: 'Docteur',
      currentUserRole: 'doctor',
      showAppBar: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userId = _auth.currentUser?.uid ?? '';
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: _buildHomeAppBar(),
      body: _mainPages[_currentMainIndex],
      bottomNavigationBar: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: userId)
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          int totalUnread = 0;
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final lastMessageId = data['lastMessageId'];
              final lastReadMessageId = (data['lastReadMessageId'] != null)
                  ? Map<String, dynamic>.from(data['lastReadMessageId'])
                  : null;
              if (lastMessageId != null && lastReadMessageId != null) {
                if (lastReadMessageId[userId] != lastMessageId) {
                  totalUnread++;
                }
              }
            }
          }
          return BottomNavigationBar(
            currentIndex: _currentMainIndex,
            onTap: (index) {
              setState(() {
                _currentMainIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.blue,
            unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 8,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Accueil',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Patients',
              ),
              BottomNavigationBarItem(
                icon: (totalUnread > 0 && _currentMainIndex != 2)
                    ? badges.Badge(
                        badgeContent: Text('$totalUnread', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        badgeStyle: const badges.BadgeStyle(
                          badgeColor: Colors.blue,
                          padding: EdgeInsets.all(5),
                        ),
                        child: const Icon(Icons.message),
                      )
                    : const Icon(Icons.message),
                label: 'Messages',
              ),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildHomeAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 600;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 2,
      shadowColor: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
      title: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('UserDoctor')
            .doc(_auth.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Text(
              'Chargement...', 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87)
            );
          }
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final photoUrl = data?['photoUrl'] as String?;
          return Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 16 : 22,
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : const AssetImage('assets/default_profile.png') as ImageProvider,
                onBackgroundImageError: (_, __) {
                  const AssetImage('assets/default_profile.png');
                },
              ),
              SizedBox(width: isMobile ? 8 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Dr. ${data?['name']?.toString().split(' ').first ?? 'Docteur'}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    Text(
                      data?['speciality']?.toString() ?? 'Spécialité',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 14,
                        color: isDark ? Colors.grey[300] : Colors.grey,
                        fontWeight: FontWeight.w500,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: isMobile ? 4 : 8),
              StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('UserDoctor')
                    .doc(_auth.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final doctorData = snapshot.data?.data() as Map<String, dynamic>?;
                  final currentStatus = doctorData?['status'] ?? 'disponible';
                  Color statusColor;
                  String statusText;
                  switch (currentStatus) {
                    case 'disponible':
                      statusColor = Colors.green;
                      statusText = 'Disponible';
                      break;
                    case 'occupé':
                      statusColor = Colors.orange;
                      statusText = 'Occupé';
                      break;
                    case 'hors_ligne':
                      statusColor = Colors.grey;
                      statusText = 'Hors ligne';
                      break;
                    default:
                      statusColor = Colors.green;
                      statusText = 'Disponible';
                  }
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8, vertical: isMobile ? 2 : 4),
                    decoration: BoxDecoration(
                      color: isDark ? statusColor.withOpacity(0.2) : statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? statusColor.withOpacity(0.5) : statusColor.withOpacity(0.3), 
                        width: 1
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: currentStatus,
                      underline: Container(),
                      icon: Icon(Icons.keyboard_arrow_down, color: statusColor, size: isMobile ? 14 : 16),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'disponible',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isMobile ? 5 : 6,
                                height: isMobile ? 5 : 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isMobile ? 2 : 4),
                              Text('Disponible', style: TextStyle(fontSize: isMobile ? 10 : 12)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'occupé',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isMobile ? 5 : 6,
                                height: isMobile ? 5 : 6,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isMobile ? 2 : 4),
                              Text('Occupé', style: TextStyle(fontSize: isMobile ? 10 : 12)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'hors_ligne',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: isMobile ? 5 : 6,
                                height: isMobile ? 5 : 6,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isMobile ? 2 : 4),
                              Text('Hors ligne', style: TextStyle(fontSize: isMobile ? 10 : 12)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? newStatus) async {
                        if (newStatus != null && newStatus != currentStatus) {
                          try {
                            await _firestoreService.updateDoctorStatus(
                              uid: _auth.currentUser!.uid,
                              status: newStatus,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Statut mis à jour : $newStatus'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur lors de la mise à jour du statut: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsDoctor(
              firestoreService: _firestoreService,
            )),
          ),
        ),
        const SizedBox(width: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('consultations')
              .where('doctorId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            final pendingCount = snapshot.data?.docs.length ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications, color: isDark ? Colors.white : Colors.black87),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.appointmentRequests);
                  },
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}