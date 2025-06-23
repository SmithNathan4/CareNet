import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'appointment.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/rating_service.dart';

class DoctorList extends StatefulWidget {
  const DoctorList({Key? key}) : super(key: key);

  @override
  _DoctorListState createState() => _DoctorListState();
}

class _DoctorListState extends State<DoctorList> {
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _filteredDoctors = [];
  String _selectedCategory = 'Tous';
  String _searchQuery = '';

  // État pour suivre les favoris localement
  final Map<String, bool> _favorites = {};

  final RatingService _ratingService = RatingService();

  List<String> _specialities = [];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _loadSpecialities();
  }

  Future<void> _fetchDoctors() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('UserDoctor').get();
      final doctorsData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Nom inconnu',
          'specialty': data['speciality'] ?? 'Spécialité inconnue',
          'image': data['photoUrl']?.isNotEmpty == true ? data['photoUrl'] : 'assets/default_profile.png',
          'rating': data['rating'] ?? 0.0,
          'status': data['status'] ?? 'hors_ligne',
          'certified': data['certified'] ?? false,
        };
      }).toList();

      setState(() {
        _doctors = List<Map<String, dynamic>>.from(doctorsData);
        _filteredDoctors = _doctors;

        for (var doctor in _doctors) {
          _favorites[doctor['name']] = false;
        }
      });
    } catch (e) {
      print("Erreur lors de la récupération des médecins: $e");
    }
  }

  Future<void> _loadSpecialities() async {
    final specialities = await FirebaseFirestore.instance.collection('app_settings').doc('main').get().then((doc) => List<String>.from(doc.data()?['specialities'] ?? []));
    if (mounted) setState(() => _specialities = specialities);
  }

  void _filterDoctors() {
    setState(() {
      _filteredDoctors = _doctors.where((doctor) {
        final matchesCategory = _selectedCategory == 'Tous' || doctor['specialty'] == _selectedCategory;
        final matchesSearchQuery = doctor['name'].toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearchQuery;
      }).toList();
    });
  }

  void _toggleFavorite(Map<String, dynamic> doctor) async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      final doctorName = doctor['name'];
      _favorites[doctorName] = !_favorites[doctorName]!;
    });

    try {
      if (_favorites[doctor['name']]!) {
        // Ajouter aux favoris dans Firestore
        await FirebaseFirestore.instance
            .collection('UserPatient')
            .doc(userId)
            .collection('favorites')
            .doc(doctor['id'])
            .set({
          'id': doctor['id'],
          'name': doctor['name'],
          'speciality': doctor['specialty'],
          'photoUrl': doctor['image'],
          'rating': doctor['rating'],
          'addedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Retirer des favoris dans Firestore
        await FirebaseFirestore.instance
            .collection('UserPatient')
            .doc(userId)
            .collection('favorites')
            .doc(doctor['id'])
            .delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_favorites[doctor['name']]! 
              ? 'Ajouté aux favoris' 
              : 'Retiré des favoris'),
          backgroundColor: _favorites[doctor['name']]! ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      // En cas d'erreur, on revient à l'état précédent
      setState(() {
        _favorites[doctor['name']] = !_favorites[doctor['name']]!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour des favoris'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Rechercher un médecin...',
              hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _filterDoctors();
                  });
                },
              )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterDoctors();
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String category) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final isSelected = _selectedCategory == category;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FilterChip(
            label: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
                fontWeight: FontWeight.w500,
              ),
            ),
            selected: isSelected,
            onSelected: (isSelected) {
              setState(() {
                _selectedCategory = category;
                _filterDoctors();
              });
            },
            selectedColor: isDark ? Colors.blue[600] : Colors.blue,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? (isDark ? Colors.blue[400]! : Colors.blue) : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryChip('Tous'),
          ..._specialities.map((sp) => _buildCategoryChip(sp)).toList(),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: doctor['image'].startsWith('http')
                  ? NetworkImage(doctor['image'])
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
              onBackgroundImageError: (_, __) {
                const AssetImage('assets/default_profile.png');
              },
            ),
            title: Text(
              'Dr. ${doctor['name']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  doctor['specialty'],
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<double>(
                      stream: _ratingService.getDoctorAverageRating(doctor['id']),
                      builder: (context, snapshot) {
                        final avg = snapshot.data ?? 0.0;
                        return Row(
                          children: [
                            ...List.generate(5, (index) => Icon(
                              Icons.star,
                              color: index < avg.round() ? Colors.amber : (isDark ? Colors.grey[600] : Colors.grey[300]),
                              size: 16,
                            )),
                            const SizedBox(width: 4),
                            Text(
                              avg.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    _buildStatusIndicator(doctor['status']),
                  ],
                ),
                const SizedBox(height: 4),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('app_settings').doc('main').get(),
                  builder: (context, snapshot) {
                    final tarif = (snapshot.data?.data() as Map<String, dynamic>?)?['tarif']?.toString() ?? '-';
                    return Text('Tarif: $tarif FCFA', style: TextStyle(fontSize: 12, color: Colors.blueGrey));
                  },
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _favorites[doctor['name']]! ? Icons.favorite : Icons.favorite_border,
                    color: _favorites[doctor['name']]! ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  onPressed: () => _toggleFavorite(doctor),
                ),
                if (doctor['certified'] == true)
                  Icon(Icons.verified, color: isDark ? Colors.white : Colors.black87, size: 20),
              ],
            ),
            onTap: () {
              _navigateToDoctorPage(doctor);
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(String status) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
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
            statusColor = isDark ? Colors.grey[400]! : Colors.grey;
            statusText = 'Hors ligne';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  void _navigateToDoctorPage(Map<String, dynamic> doctor) async {
    Navigator.pushNamed(
      context,
      'appointment',
      arguments: {
        'doctorId': doctor['id'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isTablet = screenWidth > 600 && screenWidth <= 1024;
            final isDesktop = screenWidth > 1024;
            final isMobile = screenWidth <= 600;
            final crossAxisCount = isDesktop ? 3 : isTablet ? 2 : 1;
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 120 : isTablet ? 40 : 0,
                    vertical: isDesktop ? 40 : isTablet ? 24 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 16.0),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'Médecins',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 28 : isTablet ? 22 : 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: crossAxisCount == 1
                            ? ListView.builder(
                                itemCount: _filteredDoctors.length,
                                itemBuilder: (context, index) {
                                  return _buildDoctorCard(_filteredDoctors[index]);
                                },
                              )
                            : GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: isDesktop ? 1.5 : 1.2,
                                ),
                                itemCount: _filteredDoctors.length,
                                itemBuilder: (context, index) {
                                  return _buildDoctorCard(_filteredDoctors[index]);
                                },
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
}