import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/rating_service.dart';
import 'package:intl/intl.dart';
import '../../models/rating.dart';

class DoctorPage extends StatefulWidget {
  final String doctorId;

  const DoctorPage({super.key, required this.doctorId});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  // Color Scheme from HomeDoctor
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _secondaryColor = const Color(0xFFE3F2FD);
  final Color _accentColor = const Color(0xFF42A5F5);
  final Color _textColor = const Color(0xFF0D47A1);

  final RatingService _ratingService = RatingService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600 && screenWidth <= 1024;
        final isDesktop = screenWidth > 1024;
        final isMobile = screenWidth <= 600;
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          appBar: _buildAppBar(isDark),
          body: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('UserDoctor').doc(widget.doctorId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _accentColor));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erreur: ${snapshot.error}',
                    style: TextStyle(color: _textColor, fontSize: 16),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Text(
                    'Information indisponible',
                    style: TextStyle(color: _textColor, fontSize: 16),
                  ),
                );
              }

              try {
                final doctorDataRaw = snapshot.data!.data();
                if (doctorDataRaw == null || doctorDataRaw is! Map<String, dynamic>) {
                  return Center(
                    child: Text(
                      'Information du médecin indisponible pour l\'instant',
                      style: TextStyle(color: _textColor, fontSize: 16),
                    ),
                  );
                }
                final doctorData = Map<String, dynamic>.from(doctorDataRaw);
              final String photoUrl = doctorData['photoUrl']?.isNotEmpty == true 
                  ? doctorData['photoUrl'] 
                  : 'assets/default_profile.png';
              final Map<String, dynamic> availability = (doctorData['availability'] ?? {}) as Map<String, dynamic>;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 120 : isTablet ? 40 : 0,
                    vertical: isDesktop ? 40 : isTablet ? 24 : 0,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: photoUrl.startsWith('http')
                                  ? NetworkImage(photoUrl)
                                  : const AssetImage('assets/default_profile.png') as ImageProvider,
                              onBackgroundImageError: (_, __) {
                                const AssetImage('assets/default_profile.png');
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Dr. ${doctorData['name'] ?? 'Inconnu'}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              doctorData['speciality'] ?? 'Spécialité non spécifiée',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
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
                            _buildInfoSection(
                              'Informations',
                              [
                                _buildInfoRow(Icons.email, 'Email', doctorData['email'] ?? 'Non spécifié'),
                                _buildInfoRow(Icons.phone, 'Téléphone', doctorData['phone'] ?? 'Non spécifié'),
                                _buildInfoRow(Icons.location_on, 'Adresse', doctorData['address'] ?? 'Non spécifié'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoSection(
                              'Expérience',
                              [
                                _buildInfoRow(Icons.work, 'Années d\'expérience', '${doctorData['experience'] ?? 0} ans'),
                                _buildInfoRow(Icons.school, 'Formation', doctorData['education'] ?? 'Non spécifié'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoSection(
                              'Services',
                              [
                                _buildInfoRow(Icons.medical_services, 'Services', doctorData['services']?.join(', ') ?? 'Non spécifié'),
                                _buildInfoRow(Icons.language, 'Langues', doctorData['languages']?.join(', ') ?? 'Non spécifié'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildHonorairesSection(availability),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Évaluations des patients',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('ratings')
                            .where('doctorId', isEqualTo: widget.doctorId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text('Erreur lors du chargement des évaluations', style: TextStyle(color: Colors.red));
                          }
                          final ratings = snapshot.data?.docs ?? [];
                          if (ratings.isEmpty) {
                            return Text('Aucune évaluation pour ce médecin.', style: TextStyle(color: Colors.grey[600]));
                          }
                          return Column(
                            children: ratings.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final double rating = (data['rating'] ?? 0.0).toDouble();
                              final String comment = data['comment'] ?? '';
                              final String patientName = data['patientName'] ?? (data['patientInfo']?['name'] ?? 'Patient');
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.star, color: Colors.amber, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            patientName,
                                            style: TextStyle(color: Colors.blueGrey[700], fontSize: 13, fontWeight: FontWeight.w500),
                                          ),
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
              } catch (e) {
                return Center(
                  child: Text(
                    'Information du médecin indisponible pour l\'instant',
                    style: TextStyle(color: _textColor, fontSize: 16),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text('Profil du Médecin'),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : _primaryColor,
      elevation: 0,
      shape: null,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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

  Widget _buildRatingRow(double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.star, color: _accentColor, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Étoiles',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                color: index < rating.floor() ? Colors.amber : Colors.grey[300],
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ],
      ),
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

  Widget _buildAvailabilitySection(Map<String, dynamic> availability) {
    if (availability.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Aucune disponibilité renseignée',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disponibilités',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 16),
            ...availability.entries.map((entry) {
              final slots = List<String>.from(entry.value);
              if (slots.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots.map((timeSlot) {
                      return Chip(
                        label: Text(
                          timeSlot,
                          style: TextStyle(color: _textColor),
                        ),
                        backgroundColor: _secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _primaryColor.withOpacity(0.3)),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 8),
                ],
              );
            }).where((widget) => widget != const SizedBox.shrink()).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(List<dynamic> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: reviews.map((review) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${review['rating']?.toStringAsFixed(1) ?? '0.0'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      review['date'] ?? '',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                if (review['comment'] != null) ...[
                  const SizedBox(height: 8),
                  Text(review['comment']),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHonorairesSection(Map<String, dynamic> availability) {
    if (availability.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Aucune disponibilité renseignée',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    // Affichage professionnel : jours et créneaux horaires
    List<Widget> rows = [];
    availability.forEach((jour, creneaux) {
      if (creneaux is List) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jour, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                ...creneaux.map<Widget>((heure) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Text(heure.toString(), style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        );
      }
    });
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jours et horaires de travail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }
}