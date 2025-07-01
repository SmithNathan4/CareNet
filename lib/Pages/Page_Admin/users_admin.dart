import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_details_admin.dart';

class UsersAdmin extends StatefulWidget {
  const UsersAdmin({Key? key}) : super(key: key);

  @override
  State<UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<UsersAdmin> {
  String _selectedType = 'Docteurs';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: isWide ? 400 : double.infinity,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Recherche nom/email',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildTypeChip('Docteurs'),
                          _buildTypeChip('Patients'),
                          _buildTypeChip('Admins'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 16),
                    child: _buildUserList(),
                  ),
                ),
              ],
            ),
            if (_selectedType != 'Patients')
              Positioned(
                bottom: 24,
                right: isWide ? 48 : 24,
                child: FloatingActionButton.extended(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.add),
                  label: Text(_selectedType == 'Docteurs' ? 'Ajouter Docteur' : 'Ajouter Admin'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTypeChip(String type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(type),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
        });
      },
      selectedColor: Colors.blue[600],
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUserList() {
    String collection;
    switch (_selectedType) {
      case 'Docteurs':
        collection = 'UserDoctor';
        break;
      case 'Patients':
        collection = 'UserPatient';
        break;
      case 'Admins':
        collection = 'UserAdmin';
        break;
      default:
        collection = 'UserDoctor';
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun utilisateur trouvé.'));
        }
        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
        }).toList();
        if (users.isEmpty) {
          return const Center(child: Text('Aucun résultat pour cette recherche.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final id = users[index].id;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(_selectedType == 'Docteurs'
                    ? Icons.medical_services
                    : _selectedType == 'Admins'
                        ? Icons.admin_panel_settings
                        : Icons.person),
              ),
              title: Text(data['name'] ?? ''),
              subtitle: Text(data['email'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedType != 'Admins')
                    IconButton(
                      icon: Icon(
                        (data['active'] == false) ? Icons.lock : Icons.lock_open,
                        color: (data['active'] == false) ? Colors.red : Colors.green,
                      ),
                      tooltip: (data['active'] == false) ? 'Débloquer' : 'Bloquer',
                      onPressed: () => _toggleActive(collection, id, !(data['active'] == false)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Supprimer',
                    onPressed: () => _deleteUser(collection, id),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserDetailsAdmin(
                    userData: data,
                    userType: _selectedType,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActive(String collection, String id, bool activate) async {
    await FirebaseFirestore.instance.collection(collection).doc(id).update({'active': activate});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activate ? 'Utilisateur débloqué' : 'Utilisateur bloqué'),
          backgroundColor: activate ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteUser(String collection, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
      try {
        await FirebaseAuth.instance.currentUser?.delete(); // Suppression dans Auth (si connecté)
      } catch (e) {
        // Si ce n'est pas l'utilisateur connecté, utiliser l'API Admin côté serveur
      }
    }
  }

  void _showCreateUserDialog() {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isDoctor = _selectedType == 'Docteurs';
    bool obscurePassword = true;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isDoctor ? 'Créer un compte Docteur' : 'Créer un compte Admin'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Nom complet'),
                        validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: obscurePassword,
                        validator: (v) => v == null || v.length < 6 ? 'Au moins 6 caractères' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    await _createUser(
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                      isDoctor: isDoctor,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createUser({
    required String name,
    required String email,
    required String password,
    required bool isDoctor,
  }) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user?.uid;
      if (uid == null) return;
      if (isDoctor) {
        await FirebaseFirestore.instance.collection('UserDoctor').doc(uid).set({
          'name': name,
          'email': email,
          'photoUrl': '',
          'description': '',
          'address': '',
          'rating': 0,
          'experience': 0,
          'reviews': [],
          'availability': null,
          'location': '',
          'active': true,
        });
      } else {
        await FirebaseFirestore.instance.collection('UserAdmin').doc(uid).set({
          'name': name,
          'email': email,
          'active': true,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création : $e'), backgroundColor: Colors.red),
      );
    }
  }
} 