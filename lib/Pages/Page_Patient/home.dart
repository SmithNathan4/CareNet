import 'package:flutter/material.dart';
import '../Chat/conversations_list.dart';
import '../../services/firebase/firestore.dart';
import '../../services/firebase/auth.dart';
import '../../routes/app_routes.dart';
import 'doctor_list.dart';
import '../ParametrePatient/patient_settings.dart';
import 'package:carenet/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reminders.dart';
import 'documents.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'package:badges/badges.dart' as badges;

class Home extends StatefulWidget {
  final String userName;
  final String userPhoto;
  final String userId;
  final FirestoreService firestoreService;

  const Home({
    super.key,
    required this.userName,
    required this.userPhoto,
    required this.userId,
    required this.firestoreService,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentMainIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String _selectedFilter = 'Tous';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAllDoctors();
    _checkAuthState();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['selectedIndex'] != null) {
      final idx = args['selectedIndex'] as int;
      if (_currentMainIndex != idx) {
        setState(() {
          _currentMainIndex = idx;
        });
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  List<Widget> get _mainPages => [
    _buildHomeContent(),
    const DoctorList(),
    _buildConversationsPage(),
  ];

  static Widget _buildHomeContent() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.medical_services, 
                        size: 60, 
                        color: isDark ? Colors.blue[300] : Color(0xFF4285F4)
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Bienvenue sur CareNet',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Color(0xFF333333),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Votre santé, notre priorité',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[300] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationsPage() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? widget.userId;
    
    return ConversationsList(
      currentUserId: userId,
      currentUserName: widget.userName,
    );
  }

  Widget _buildOptionButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildPatientInfo() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return FutureBuilder<DocumentSnapshot>(
          future: _firestoreService.getPatient(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final photoUrl = userData?['photoUrl'] as String?;
              final userName = userData?['name'] as String? ?? widget.userName;

              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: photoUrl?.isNotEmpty == true
                        ? NetworkImage(photoUrl!)
                        : const AssetImage('assets/default_profile.png') as ImageProvider,
                    onBackgroundImageError: (_, __) {
                      const AssetImage('assets/default_profile.png');
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Patient',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage('assets/default_profile.png'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.userName.isNotEmpty ? widget.userName : 'Chargement...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Patient',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final userId = FirebaseAuth.instance.currentUser?.uid ?? widget.userId;
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isTablet = screenWidth > 600 && screenWidth <= 1024;
            final isDesktop = screenWidth > 1024;
            final isMobile = screenWidth <= 600;
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                elevation: 0,
                title: _buildPatientInfo(),
                actions: [
                  IconButton(
                    icon: Icon(Icons.favorite_border, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.favorites);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.notifications);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.settingsRoute);
                    },
                  ),
                ],
              ),
              body: _currentMainIndex == 0
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 120 : isTablet ? 40 : 0,
                          vertical: isDesktop ? 40 : isTablet ? 24 : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchBar(),
                            const SizedBox(height: 20),
                            _buildQuickActions(),
                          ],
                        ),
                      ),
                    )
                  : _mainPages[_currentMainIndex],
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
                    selectedItemColor: isDark ? Colors.blue[300] : Colors.blue,
                    unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    elevation: 8,
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Accueil',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.medical_services),
                        label: 'Médecins',
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
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rechercher un médecin',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Nom, spécialité, localisation ou symptômes',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isSearching = false;
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _isSearching = value.isNotEmpty;
                    });
                    if (value.isNotEmpty) {
                      _performSearch();
                    } else {
                      setState(() {
                        _searchResults = [];
                        _isSearching = false;
                      });
                    }
                  },
                ),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 12),
                _buildFilterSection(),
              ],
              if (_isSearching || _searchResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSearchResults(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtres',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tous', Icons.medical_services),
                  _buildFilterChip('Généraliste', Icons.person),
                  _buildFilterChip('Cardiologue', Icons.favorite),
                  _buildFilterChip('Dermatologue', Icons.face),
                  _buildFilterChip('Pédiatre', Icons.child_care),
                  _buildFilterChip('Gynécologue', Icons.pregnant_woman),
                  _buildFilterChip('Psychiatre', Icons.psychology),
                  _buildFilterChip('Dentiste', Icons.medical_services),
                  _buildFilterChip('Ophtamologue', Icons.remove_red_eye),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Disponible', Icons.check_circle),
                  _buildFilterChip('En ligne', Icons.online_prediction),
                  _buildFilterChip('Proche', Icons.location_on),
                  _buildFilterChip('Évalué 4+', Icons.star),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final isSelected = _selectedFilter == label;
        
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
            selected: isSelected,
            onSelected: (bool selected) {
              _handleFilterSelection(label);
            },
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
            selectedColor: isDark ? Colors.blue[600] : Colors.blue[600]!,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]!),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? (isDark ? Colors.blue[400]! : Colors.blue[600]!) : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
              width: 1,
            ),
          ),
        );
      },
    );
  }

  void _handleFilterSelection(String filter) {
    setState(() {
      _selectedFilter = filter;
      // Charger les médecins même sans texte de recherche
      if (_searchQuery.isNotEmpty) {
        _performSearch();
      } else {
        _loadAllDoctors();
      }
    });
  }

  Future<void> _loadAllDoctors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _firestoreService.searchDoctors(
        query: '',
        filter: _selectedFilter,
      );
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
        _isSearching = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors du chargement des médecins'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _firestoreService.searchDoctors(
        query: _searchQuery,
        filter: _selectedFilter,
      );
      
      // Appliquer des filtres supplémentaires côté client
      List<Map<String, dynamic>> filteredResults = results;
      
      switch (_selectedFilter) {
        case 'Disponible':
          filteredResults = results.where((doctor) => 
            doctor['status'] == 'disponible'
          ).toList();
          break;
        case 'En ligne':
          filteredResults = results.where((doctor) => 
            doctor['status'] == 'disponible' || doctor['status'] == 'occupé'
          ).toList();
          break;
        case 'Évalué 4+':
          filteredResults = results.where((doctor) => 
            (doctor['rating'] ?? 0.0) >= 4.0
          ).toList();
          break;
        case 'Proche':
          // Ici on pourrait implémenter une logique de géolocalisation
          // Pour l'instant, on garde tous les résultats
          break;
        default:
          // Pour les spécialités, le filtrage est déjà fait côté serveur
          break;
      }
      
      setState(() {
        _searchResults = filteredResults;
        _isLoading = false;
        _isSearching = _searchQuery.isNotEmpty || _selectedFilter != 'Tous';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la recherche'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQuickActions() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actions rapides',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.calendar_today,
                    label: 'Mes RDV',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.myAppointments);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.history,
                    label: 'Historique',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.medicalHistory);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.alarm,
                    label: 'Rappels',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Reminders(),
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.folder,
                    label: 'Documents',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Documents(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        if (_isLoading) {
          return Container(
            height: 100,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_searchResults.isEmpty) {
          return Container(
            height: 100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 40, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun médecin trouvé',
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final doctor = _searchResults[index];
              return _buildDoctorCard(doctor);
            },
          ),
        );
      },
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.doctorPage,
                arguments: {'doctorId': doctor['uid']},
              );
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: doctor['photoUrl']?.isNotEmpty == true
                      ? NetworkImage(doctor['photoUrl'])
                      : const AssetImage('assets/default_profile.png') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor['name'] ?? 'Médecin'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        doctor['speciality'] ?? 'Spécialité non spécifiée',
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            doctor['location'] ?? 'Localisation non spécifiée',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('ratings')
                          .where('doctorId', isEqualTo: doctor['uid'])
                          .snapshots(),
                      builder: (context, snapshot) {
                        final ratings = snapshot.data?.docs ?? [];
                        final avg = ratings.isNotEmpty
                            ? ratings.map((r) => (r['rating'] ?? 0.0) as num).fold(0.0, (a, b) => a + b) / ratings.length
                            : 0.0;
                        return Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              avg.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date non spécifiée';
    if (date is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(date.toDate());
    }
    return 'Date invalide';
  }

  Future<void> _checkAuthState() async {
    final authService = AuthService();
    if (!authService.isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }
}