import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsAdmin extends StatefulWidget {
  const SettingsAdmin({Key? key}) : super(key: key);

  @override
  State<SettingsAdmin> createState() => _SettingsAdminState();
}

class _SettingsAdminState extends State<SettingsAdmin> {
  final TextEditingController _tarifController = TextEditingController();
  final TextEditingController _specialityController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  bool _isLoading = false;
  List<String> _specialities = [];
  double? _tarif;
  String? _email;
  String? _uid;
  bool _isOldPasswordVerified = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAdminProfile();
  }

  @override
  void dispose() {
    _tarifController.dispose();
    _specialityController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _oldPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final doc = await FirebaseFirestore.instance.collection('app_settings').doc('main').get();
    final data = doc.data() ?? {};
    setState(() {
      _tarif = (data['tarif'] ?? 0).toDouble();
      _tarifController.text = _tarif?.toStringAsFixed(0) ?? '';
      _specialities = List<String>.from(data['specialities'] ?? []);
      _isLoading = false;
    });
  }

  Future<void> _saveTarif() async {
    final value = double.tryParse(_tarifController.text);
    if (value == null || value <= 0) return;
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('app_settings').doc('main').set({
      'tarif': value,
      'specialities': _specialities,
    }, SetOptions(merge: true));
    setState(() {
      _tarif = value;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif mis à jour')));
  }

  Future<void> _addSpeciality() async {
    final value = _specialityController.text.trim();
    if (value.isEmpty || _specialities.contains(value)) return;
    setState(() => _isLoading = true);
    _specialities.add(value);
    await FirebaseFirestore.instance.collection('app_settings').doc('main').set({
      'specialities': _specialities,
    }, SetOptions(merge: true));
    setState(() {
      _specialityController.clear();
      _isLoading = false;
    });
  }

  Future<void> _removeSpeciality(String speciality) async {
    setState(() => _isLoading = true);
    _specialities.remove(speciality);
    await FirebaseFirestore.instance.collection('app_settings').doc('main').set({
      'specialities': _specialities,
    }, SetOptions(merge: true));
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _email = user.email;
    _uid = user.uid;
    final doc = await FirebaseFirestore.instance.collection('UserAdmin').doc(_uid).get();
    final data = doc.data() ?? {};
    setState(() {
      _nameController.text = data['name'] ?? '';
    });
  }

  Future<void> _saveAdminName() async {
    if (_uid == null) return;
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('UserAdmin').doc(_uid).update({
      'name': _nameController.text.trim(),
    });
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom mis à jour')));
  }

  Future<void> _verifyOldPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final oldPassword = _oldPasswordController.text.trim();
    if (oldPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer votre ancien mot de passe')));
      return;
    }
    final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
    try {
      setState(() => _isLoading = true);
      await user.reauthenticateWithCredential(cred);
      setState(() {
        _isOldPasswordVerified = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ancien mot de passe vérifié. Vous pouvez maintenant définir un nouveau mot de passe.')));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ancien mot de passe incorrect.')));
    }
  }

  Future<void> _changePassword() async {
    if (!_isOldPasswordVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez d\'abord vérifier votre ancien mot de passe.')));
      return;
    }
    final newPassword = _passwordController.text.trim();
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères')));
      return;
    }
    try {
      setState(() => _isLoading = true);
      await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
      setState(() {
        _isLoading = false;
        _isOldPasswordVerified = false;
      });
      _passwordController.clear();
      _oldPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour')));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 32),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profil administrateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: TextEditingController(text: _email ?? ''),
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nom',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _saveAdminName,
                              child: const Text('Enregistrer'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _oldPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Ancien mot de passe',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _verifyOldPassword,
                          child: const Text('Vérifier'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                enabled: _isOldPasswordVerified,
                                decoration: const InputDecoration(
                                  labelText: 'Nouveau mot de passe',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isOldPasswordVerified ? _changePassword : null,
                              child: const Text('Modifier'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Text('Tarif de consultation (FCFA)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tarifController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Entrer le tarif',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveTarif,
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text('Spécialités médicales', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _specialityController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Ajouter une spécialité',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addSpeciality,
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _specialities.map((sp) => Chip(
                    label: Text(sp),
                    onDeleted: () => _removeSpeciality(sp),
                  )).toList(),
                ),
                const SizedBox(height: 40),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
} 