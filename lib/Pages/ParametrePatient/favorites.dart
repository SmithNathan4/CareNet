import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Page_Patient/appointment.dart';
import '../../services/rating_service.dart';

class Favorites extends StatefulWidget {
  const Favorites({super.key});

  @override
  State<Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<Favorites> {
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _secondaryColor = const Color(0xFFE3F2FD);
  final Color _accentColor = const Color(0xFF42A5F5);
  final Color _textColor = const Color(0xFF0D47A1);

  late Stream<QuerySnapshot> _favoritesStream;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  final RatingService _ratingService = RatingService();

  @override
  void initState() {
    super.initState();
    _initializeFavoritesStream();
  }

  void _initializeFavoritesStream() {
    if (_userId != null) {
      _favoritesStream = FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(_userId)
          .collection('favorites')
          .snapshots();
    }
  }

  Future<void> _removeFavorite(String doctorId) async {
    try {
      await FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(_userId)
          .collection('favorites')
          .doc(doctorId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Médecin retiré des favoris'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du retrait des favoris'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: _secondaryColor,
        appBar: _buildAppBar(),
        body: Center(
          child: Text(
            'Veuillez vous connecter pour voir vos favoris',
            style: TextStyle(color: _textColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _secondaryColor,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _favoritesStream,
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

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return _buildFavoritesList(snapshot.data!.docs);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Mes Favoris',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: _primaryColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border,
                size: 60,
                color: _accentColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun favori ajouté',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajoutez des médecins à vos favoris pour les retrouver ici.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList(List<QueryDocumentSnapshot> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final doctorData = favorites[index].data() as Map<String, dynamic>;
        final doctorId = favorites[index].id;

        return Dismissible(
          key: Key(doctorId),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _removeFavorite(doctorId);
          },
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: CircleAvatar(
                radius: 35,
                backgroundColor: _secondaryColor,
                backgroundImage: doctorData['photoUrl'] != null
                    ? NetworkImage(doctorData['photoUrl'])
                    : const AssetImage('assets/default_doctor.png') as ImageProvider,
              ),
              title: Text(
                'Dr. ${doctorData['name'] ?? 'Sans nom'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textColor,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    doctorData['speciality'] ?? 'Spécialité non spécifiée',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<double>(
                        stream: _ratingService.getDoctorAverageRating(doctorId),
                        builder: (context, snapshot) {
                          final avg = snapshot.data ?? 0.0;
                          return Row(
                            children: [
                              ...List.generate(5, (index) => Icon(
                            Icons.star,
                                color: index < avg.round() ? Colors.amber : Colors.grey[300],
                            size: 16,
                              )),
                              const SizedBox(width: 4),
                              Text(
                                avg.toStringAsFixed(1),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _textColor,
                          ),
                        ),
                            ],
                          );
                        },
                      ),
                      if (doctorData['status'] != null)
                        _buildStatusIndicator(doctorData['status']),
                    ],
                  ),
                ],
              ),
              trailing: doctorData['certified'] == true
                  ? Icon(Icons.verified, color: _accentColor, size: 20)
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Appointment(doctorId: doctorId),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(String status) {
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

    return Container(
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}