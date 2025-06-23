import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase/firestore.dart';
import '../../routes/app_routes.dart';
import '../../services/firebase/auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

//import 'notifications_doctors.dart';
//import 'availability.dart';
//import 'messaging.dart';

class SettingsDoctor extends StatelessWidget {
  final FirestoreService firestoreService;

  const SettingsDoctor({Key? key, required this.firestoreService}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Déconnexion',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Annuler',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Déconnexion',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                try {
                  final authService = AuthService();
                  await authService.signOut();
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                } catch (e) {
                  print('Erreur de déconnexion: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la déconnexion: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _goBackToHome(BuildContext context) {
    Navigator.pop(context);
  }

  Future<Map<String, dynamic>> _fetchDoctorData(String uid) async {
    try {
      DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(uid)
          .get();
      
      if (doctorDoc.exists) {
        final data = doctorDoc.data() as Map<String, dynamic>;
        return {
          'name': data['name'] ?? 'Docteur',
          'email': data['email'] ?? 'email@exemple.com',
          'photoUrl': data['photoUrl']?.isNotEmpty == true ? data['photoUrl'] : 'assets/default_profile.png',
          'speciality': data['speciality'] ?? 'Non spécifié',
        };
      }
      return {
        'name': 'Docteur',
        'email': 'email@exemple.com',
        'photoUrl': 'assets/default_profile.png',
        'speciality': 'Non spécifié',
      };
    } catch (e) {
      print('Erreur lors de la récupération des données du docteur: $e');
      return {
        'name': 'Docteur',
        'email': 'email@exemple.com',
        'photoUrl': 'assets/default_profile.png',
        'speciality': 'Non spécifié',
      };
    }
  }

  Widget _buildUserProfile(BuildContext context, String name, String email, String photoUrl, String speciality) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: photoUrl.startsWith('http')
                  ? NetworkImage(photoUrl)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
              onBackgroundImageError: (_, __) {
                const AssetImage('assets/default_profile.png');
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Dr. $name',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              speciality,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildDarkModeSwitch(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Mode sombre'),
        trailing: Switch(
          value: themeProvider.isDarkMode,
          onChanged: (bool value) {
            themeProvider.toggleTheme();
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.red[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.logout, color: Colors.red[600]),
        title: Text(
          'Déconnexion',
          style: TextStyle(
            color: Colors.red[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: () => _signOut(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBackToHome(context),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Utilisateur non connecté'))
          : FutureBuilder<Map<String, dynamic>>(
              future: _fetchDoctorData(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Erreur lors du chargement des données'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Aucune donnée utilisateur trouvée'));
                }

                final userData = snapshot.data!;
                final String userName = userData['name'];
                final String userEmail = userData['email'];
                final String photoUrl = userData['photoUrl'];
                final String speciality = userData['speciality'];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildUserProfile(context, userName, userEmail, photoUrl, speciality),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Apparence',
                      [
                        _buildDarkModeSwitch(context, themeProvider),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Compte',
                      [
                        _buildSettingsTile(
                          context: context,
                          icon: Icons.person,
                          title: 'Modifier mon profil',
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.profilDoctor,
                            arguments: {'firestoreService': firestoreService},
                          ),
                        ),
                        _buildSettingsTile(
                          context: context,
                          icon: Icons.lock,
                          title: 'Modifier mon mot de passe',
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.changePasswordDoctor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Informations',
                      [
                        _buildSettingsTile(
                          context: context,
                          icon: Icons.privacy_tip,
                          title: 'Politique de confidentialité',
                          onTap: () {
                            _showPrivacyPolicy(context);
                          },
                        ),
                        _buildSettingsTile(
                          context: context,
                          icon: Icons.description,
                          title: "Conditions d'utilisation",
                          onTap: () {
                            _showTermsOfService(context);
                          },
                        ),
                        _buildSettingsTile(
                          context: context,
                          icon: Icons.help,
                          title: 'Aide et support',
                          onTap: () {
                            _showHelpAndSupport(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      'Sécurité',
                      [
                        _buildLogoutTile(context),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Politique de confidentialité'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Votre vie privée est importante pour nous.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'CareNet s\'engage à protéger vos données personnelles et médicales. '
                'Nous collectons uniquement les informations nécessaires au bon fonctionnement '
                'de l\'application et ne les partageons jamais avec des tiers sans votre consentement explicite.',
              ),
              SizedBox(height: 16),
              Text(
                'Principales mesures de protection :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Chiffrement de bout en bout des messages\n'
                  '• Stockage sécurisé des données médicales\n'
                  '• Accès restreint aux informations sensibles\n'
                  '• Conformité aux réglementations médicales'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Conditions d'utilisation"),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'En utilisant CareNet, vous acceptez les conditions suivantes :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '1. Utilisation responsable : Vous vous engagez à utiliser l\'application '
                'de manière éthique et professionnelle.',
              ),
              SizedBox(height: 8),
              Text(
                '2. Confidentialité : Vous respectez la confidentialité des informations '
                'médicales de vos patients.',
              ),
              SizedBox(height: 8),
              Text(
                '3. Disponibilité : L\'application peut être temporairement indisponible '
                'pour maintenance.',
              ),
              SizedBox(height: 8),
              Text(
                '4. Responsabilité : CareNet ne peut être tenu responsable des décisions '
                'médicales prises via l\'application.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showHelpAndSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aide et support'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Besoin d\'aide ? Nous sommes là pour vous.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Contactez notre équipe support :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('📧 Email : support@carenet.com\n'
                  '📞 Téléphone : +237 6 75 04 75 40\n'
                  '💬 Chat en ligne : Disponible 24h/24'),
              SizedBox(height: 16),
              Text(
                'FAQ :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Comment modifier mon profil ?\n'
                  '• Comment gérer mes rendez-vous ?\n'
                  '• Comment sécuriser mon compte ?\n'
                  '• Comment contacter un patient ?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}