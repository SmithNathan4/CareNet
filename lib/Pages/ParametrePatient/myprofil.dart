import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase/firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MyProfile extends StatefulWidget {
  final FirestoreService firestoreService;

  const MyProfile({super.key, required this.firestoreService});

  @override
  _MyProfileState createState() => _MyProfileState();
}

class _MyProfileState extends State<MyProfile> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Couleurs principales harmonisées
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _accentColor = const Color(0xFF42A5F5);

  // Données du profil
  String? _email;
  String? _name; // Nouveau champ pour le nom
  String? _phoneNumber;
  String? _gender;
  String? _bloodGroup;
  double? _height;
  double? _weight;
  DateTime? _birthDate;
  bool _hasMedicalHistory = false;
  String? _medicalHistoryDescription;
  String? _profileImageUrl; // Pour l'image de profil

  // Listes déroulantes avec codes pays améliorés
  final List<Map<String, String>> _countryCodes = [
    {'code': '+237', 'country': '🇨🇲 Cameroun', 'shortCode': '237'},
    {'code': '+236', 'country': '🇨🇫 République Centrafricaine', 'shortCode': '236'},
    {'code': '+235', 'country': '🇹🇩 Tchad', 'shortCode': '235'},
    {'code': '+242', 'country': '🇨🇬 Congo (Brazzaville)', 'shortCode': '242'},
    {'code': '+243', 'country': '🇨🇩 Congo (Kinshasa)', 'shortCode': '243'},
    {'code': '+240', 'country': '🇬🇶 Guinée Équatoriale', 'shortCode': '240'},
    {'code': '+241', 'country': '🇬🇦 Gabon', 'shortCode': '241'},
  ];
  String? _selectedCountryCode;

  final List<String> _genders = ['Homme', 'Femme'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    // Initialisation par défaut pour éviter des valeurs null
    _selectedCountryCode = _countryCodes[0]['code'];
    _gender = _genders[0];
    _bloodGroup = _bloodGroups[0];
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non connecté. Veuillez vous reconnecter.')),
        );
        Navigator.pop(context);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        setState(() {
          _email = data['email']?.toString() ?? user.email ?? '';
          _name = data['name']?.toString() ?? user.displayName ?? '';
          _profileImageUrl = data['profileImageUrl']?.toString() ?? user.photoURL;
          _phoneNumber = data['phoneNumber']?.toString() ?? '';

          // Gestion de _selectedCountryCode
          _selectedCountryCode = _countryCodes[0]['code']; // Par défaut
          if (_phoneNumber != null && _phoneNumber!.isNotEmpty) {
            final matchingCode = _countryCodes.firstWhere(
                  (code) => _phoneNumber!.startsWith(code['code']!),
              orElse: () => _countryCodes[0],
            );
            _selectedCountryCode = matchingCode['code'];
            _phoneNumber = _phoneNumber!.replaceFirst(_selectedCountryCode!, '');
          }

          // Gestion de _gender
          final loadedGender = data['gender']?.toString();
          _gender = _genders.contains(loadedGender) ? loadedGender : _genders[0];

          // Gestion de _bloodGroup
          final loadedBloodGroup = data['bloodGroup']?.toString();
          _bloodGroup = _bloodGroups.contains(loadedBloodGroup) ? loadedBloodGroup : _bloodGroups[0];

          _height = double.tryParse(data['height']?.toString() ?? '0') ?? 0;
          _weight = double.tryParse(data['weight']?.toString() ?? '0') ?? 0;
          _birthDate = (data['birthDate'] as Timestamp?)?.toDate();
          _hasMedicalHistory = data['hasMedicalHistory'] as bool? ?? false;
          _medicalHistoryDescription = data['medicalHistoryDescription']?.toString() ?? '';
        });
      } else {
        // Si pas de données Firestore, utiliser les données Firebase Auth
        final user = FirebaseAuth.instance.currentUser!;
        setState(() {
          _email = user.email;
          _name = user.displayName;
          _profileImageUrl = user.photoURL;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez compléter votre profil')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des données: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur non connecté')),
        );
        return;
      }

      // Construction du numéro avec le code pays
      String fullPhoneNumber = '';
      if (_phoneNumber != null && _phoneNumber!.isNotEmpty) {
        final selectedCountry = _countryCodes.firstWhere(
              (country) => country['code'] == _selectedCountryCode,
          orElse: () => _countryCodes[0],
        );
        fullPhoneNumber = '${selectedCountry['shortCode']} ${_phoneNumber}';
      }

      await FirebaseFirestore.instance.collection('UserPatient').doc(user.uid).set({
        'email': _email,
        'name': _name,
        'phoneNumber': _selectedCountryCode! + (_phoneNumber ?? ''),
        'phoneNumberDisplay': fullPhoneNumber, // Numéro formaté pour affichage
        'gender': _gender,
        'bloodGroup': _bloodGroup,
        'height': _height,
        'weight': _weight,
        'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
        'hasMedicalHistory': _hasMedicalHistory,
        'medicalHistoryDescription': _medicalHistoryDescription,
        'profileImageUrl': _profileImageUrl,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _selectBirthDate() async {
    final initialDate = _birthDate ?? DateTime(2000);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildProfileHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildFormCard(
                      title: 'Nom complet',
                      icon: Icons.person_outline,
                      child: TextFormField(
                        initialValue: _name ?? '',
                        decoration: InputDecoration(
                          hintText: 'Entrez votre nom complet',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer votre nom';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _name = value;
                        },
                      ),
                    ),

                    _buildFormCard(
                      title: 'Numéro de téléphone',
                      icon: Icons.phone_outlined,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              underline: Container(),
                              items: _countryCodes.map((code) {
                                return DropdownMenuItem<String>(
                                  value: code['code'],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        code['country']!.split(' ')[0], // Juste le drapeau
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        code['shortCode']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCountryCode = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: _phoneNumber ?? '',
                              decoration: InputDecoration(
                                hintText: 'Numéro de téléphone',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer un numéro de téléphone';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _phoneNumber = value;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildFormCard(
                      title: 'Genre',
                      icon: Icons.wc_outlined,
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _genders.map((gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _gender = value;
                          });
                        },
                      ),
                    ),

                    _buildFormCard(
                      title: 'Groupe sanguin',
                      icon: Icons.bloodtype_outlined,
                      child: DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _bloodGroups.map((bloodGroup) {
                          return DropdownMenuItem<String>(
                            value: bloodGroup,
                            child: Text(bloodGroup),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _bloodGroup = value;
                          });
                        },
                      ),
                    ),

                    _buildFormCard(
                      title: 'Informations physiques',
                      icon: Icons.straighten_outlined,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _height != null && _height! > 0 ? _height.toString() : '',
                              decoration: InputDecoration(
                                labelText: 'Taille (en mètre)',
                                suffixText: 'm',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Requis';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Nombre invalide';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _height = double.tryParse(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _weight != null && _weight! > 0 ? _weight.toString() : '',
                              decoration: InputDecoration(
                                labelText: 'Poids (kg)',
                                suffixText: 'kg',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Requis';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Nombre invalide';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _weight = double.tryParse(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildFormCard(
                      title: 'Date d\'anniversaire',
                      icon: Icons.cake_outlined,
                      child: InkWell(
                        onTap: _selectBirthDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.grey.shade600),
                              const SizedBox(width: 12),
                              Text(
                                _birthDate != null
                                    ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                                    : 'Sélectionner une date',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _birthDate != null ? Colors.black : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    _buildFormCard(
                      title: 'Antécédents médicaux',
                      icon: Icons.medical_information_outlined,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SwitchListTile(
                              title: const Text('Avez-vous des antécédents médicaux ?'),
                              value: _hasMedicalHistory,
                              activeColor: Colors.blue,
                              onChanged: (value) {
                                setState(() {
                                  _hasMedicalHistory = value;
                                });
                              },
                            ),
                          ),
                          if (_hasMedicalHistory) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _medicalHistoryDescription,
                              decoration: InputDecoration(
                                labelText: 'Description des antécédents médicaux',
                                hintText: 'Décrivez vos antécédents médicaux...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 4,
                              onChanged: (value) {
                                _medicalHistoryDescription = value;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      height: 56,
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _saveUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined),
                            SizedBox(width: 8),
                            Text(
                              'Enregistrer les modifications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: const Text('Mon Profil'),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : _primaryColor,
      elevation: 0,
      shape: null,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _profileImageUrl = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l\'image: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _getProfileImage(),
                  child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey.shade600,
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.camera_alt, color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _name?.isNotEmpty == true ? _name! : 'Nom non défini',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _email ?? 'Email non défini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) {
      return null;
    }
    
    if (_profileImageUrl!.startsWith('http')) {
      return NetworkImage(_profileImageUrl!);
    } else {
      return FileImage(File(_profileImageUrl!));
    }
  }

  Widget _buildFormCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}