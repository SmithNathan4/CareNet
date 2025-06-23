import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase/firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilDoctor extends StatefulWidget {
  final FirestoreService firestoreService;

  const ProfilDoctor({Key? key, required this.firestoreService}) : super(key: key);

  @override
  _ProfilDoctorState createState() => _ProfilDoctorState();
}

class _ProfilDoctorState extends State<ProfilDoctor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialityController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _locationController = TextEditingController();
  final _educationController = TextEditingController();
  final _languagesController = TextEditingController();
  final _servicesController = TextEditingController();
  bool _isLoading = false;
  String? _currentPhotoUrl;
  File? _imageFile;
  double _rating = 0.0;
  List<dynamic> _reviews = [];

  // Disponibilités par jour
  final Map<String, List<String>> _availability = {
    'Lundi': [],
    'Mardi': [],
    'Mercredi': [],
    'Jeudi': [],
    'Vendredi': [],
    'Samedi': [],
    'Dimanche': [],
  };

  // Créneaux horaires disponibles
  final List<String> _timeSlots = [
    '08:00-10:00',
    '10:00-12:00',
    '14:00-16:00',
    '16:00-18:00',
    '18:00-20:00',
  ];

  List<String> _specialities = [];
  String? _selectedSpeciality;
  bool _showOtherSpecialityField = false;

  @override
  void initState() {
    super.initState();
    _loadSpecialities();
    _loadDoctorData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specialityController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _locationController.dispose();
    _educationController.dispose();
    _languagesController.dispose();
    _servicesController.dispose();
    super.dispose();
  }

  Future<void> _loadSpecialities() async {
    final specialities = await widget.firestoreService.getSpecialities();
    if (mounted) setState(() => _specialities = [...specialities, 'Autre']);
  }

  Future<void> _loadDoctorData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doctorDoc = await widget.firestoreService.getDoctor(user.uid);
        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data() as Map<String, dynamic>;
          setState(() {
            _nameController.text = doctorData['name'] ?? '';
            _emailController.text = doctorData['email'] ?? '';
            _phoneController.text = doctorData['phone'] ?? '';
            _specialityController.text = doctorData['speciality'] ?? '';
            _selectedSpeciality = _specialities.contains(doctorData['speciality'])
                ? doctorData['speciality']
                : (doctorData['speciality']?.isNotEmpty == true ? 'Autre' : null);
            _showOtherSpecialityField = _selectedSpeciality == 'Autre';
            if (_showOtherSpecialityField) {
              _specialityController.text = doctorData['speciality'] ?? '';
            }
            _addressController.text = doctorData['address'] ?? '';
            _bioController.text = doctorData['description'] ?? '';
            _experienceController.text = (doctorData['experience'] ?? '0').toString();
            _locationController.text = doctorData['location'] ?? '';
            _educationController.text = doctorData['education'] ?? '';
            _languagesController.text = doctorData['languages']?.join(', ') ?? '';
            _servicesController.text = doctorData['services']?.join(', ') ?? '';
            _currentPhotoUrl = doctorData['photoUrl'];
            _rating = (doctorData['rating'] ?? 0.0).toDouble();
            _reviews = doctorData['reviews'] ?? [];

            // Charger les disponibilités
            final availability = doctorData['availability'] as Map<String, dynamic>? ?? {};
            availability.forEach((key, value) {
              if (value is List) {
                _availability[key] = List<String>.from(value);
              }
            });
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement des données'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      print('Erreur lors de la sélection de l\'image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentPhotoUrl;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('doctor_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Aucun utilisateur connecté');

      String? photoUrl = await _uploadImage();

      // Convertir les chaînes en listes pour les langues et services
      final languages = _languagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final services = _servicesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await widget.firestoreService.createOrUpdateDoctor(
        uid: user.uid,
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        speciality: _specialityController.text,
        address: _addressController.text,
        description: _bioController.text,
        photoUrl: photoUrl ?? _currentPhotoUrl ?? '',
        availability: _availability,
        experience: int.tryParse(_experienceController.text) ?? 0,
        location: _locationController.text,
        education: _educationController.text,
        languages: languages,
        services: services,
        rating: _rating,
        reviews: _reviews,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Erreur lors de la mise à jour du profil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour du profil'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAvailabilitySection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disponibilités',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 16),
            ..._availability.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((timeSlot) {
                      final isSelected = entry.value.contains(timeSlot);
                      return FilterChip(
                        label: Text(timeSlot),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _availability[entry.key]!.add(timeSlot);
                            } else {
                              _availability[entry.key]!.remove(timeSlot);
                            }
                          });
                        },
                        selectedColor: Colors.blue[100],
                        checkmarkColor: Colors.blue,
                      );
                    }).toList(),
                  ),
                  const Divider(),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_currentPhotoUrl != null
                                    ? NetworkImage(_currentPhotoUrl!)
                                    : const AssetImage('assets/default_doctor.png')) as ImageProvider,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              radius: 18,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildSection('Informations personnelles', [
                      _buildTextField(_nameController, 'Nom complet', Icons.person),
                      _buildTextField(_emailController, 'Email', Icons.email),
                      _buildTextField(_phoneController, 'Téléphone', Icons.phone),
                    ]),

                    const SizedBox(height: 32),
                    _buildSection('Informations professionnelles', [
                      DropdownButtonFormField<String>(
                        value: _selectedSpeciality,
                        items: _specialities.map((sp) => DropdownMenuItem(
                          value: sp,
                          child: Text(sp),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSpeciality = value;
                            _showOtherSpecialityField = value == 'Autre';
                            if (value != 'Autre') {
                              _specialityController.text = value ?? '';
                            } else {
                              _specialityController.clear();
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Spécialité',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Ce champ est requis'
                            : null,
                      ),
                      if (_showOtherSpecialityField) ...[
                        const SizedBox(height: 12),
                        _buildTextField(_specialityController, 'Précisez votre spécialité', Icons.edit),
                      ],
                      _buildTextField(_experienceController, 'Années d\'expérience', Icons.work, keyboardType: TextInputType.number),
                      _buildTextField(_educationController, 'Formation et diplômes', Icons.school),
                      _buildTextField(_servicesController, 'Services offerts (séparés par des virgules)', Icons.medical_information),
                      _buildTextField(_languagesController, 'Langues parlées (séparées par des virgules)', Icons.language),
                    ]),

                    const SizedBox(height: 32),
                    _buildSection('Localisation', [
                      _buildTextField(_addressController, 'Adresse du cabinet', Icons.location_on),
                      _buildTextField(_locationController, 'Ville/Quartier', Icons.location_city),
                    ]),

                    const SizedBox(height: 32),
                    _buildSection('Description', [
                      _buildTextField(_bioController, 'Description professionnelle', Icons.description, maxLines: 5),
                    ]),

                    const SizedBox(height: 32),
                    _buildSection('Disponibilités', [
                      _buildAvailabilitySection(),
                    ]),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Ce champ est requis';
          }
          return null;
        },
      ),
    );
  }
} 