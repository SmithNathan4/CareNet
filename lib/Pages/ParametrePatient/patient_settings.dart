import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase/firestore.dart';
import '../../routes/app_routes.dart';
import '../../services/firebase/auth.dart';
import 'change_password.dart';
import 'favorites.dart';
import 'notifications.dart';
import '../Payment/payment_methods.dart';
import 'myprofil.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class PatientSettings extends StatefulWidget {
  final FirestoreService firestoreService;

  const PatientSettings({
    Key? key,
    required this.firestoreService,
  }) : super(key: key);

  @override
  State<PatientSettings> createState() => _PatientSettingsState();
}

class _PatientSettingsState extends State<PatientSettings> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('Utilisateur non connecté');
      }

      DocumentSnapshot patientDoc = await widget.firestoreService.getPatient(uid);
      if (!patientDoc.exists) {
        DocumentSnapshot doctorDoc = await widget.firestoreService.getDoctor(uid);
        if (!doctorDoc.exists) {
          throw Exception('Profil non trouvé');
        }
        setState(() {
          _userData = doctorDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _userData = patientDoc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Déconnexion',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuler',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final authService = AuthService();
                  await authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la déconnexion: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Paramètres',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildUserProfile(),
                  const SizedBox(height: 10),
                  Text(
                    _userData?['name'] ?? 'Utilisateur',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _userData?['email'] ?? 'email@exemple.com',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildSettingsList(context),
                ],
              ),
            ),
    );
  }

  Widget _buildUserProfile() {
    if (_userData == null) {
      return const CircleAvatar(
        radius: 50,
        backgroundImage: AssetImage('assets/default_profile.png'),
      );
    }

    final photoUrl = _userData!['photoUrl']?.isNotEmpty == true 
        ? _userData!['photoUrl'] 
        : 'assets/default_profile.png';

    return CircleAvatar(
      radius: 50,
      backgroundImage: photoUrl.startsWith('http')
          ? NetworkImage(photoUrl)
          : const AssetImage('assets/default_profile.png') as ImageProvider,
      onBackgroundImageError: (_, __) {
        const AssetImage('assets/default_profile.png');
      },
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        _buildSettingsSection(
          'Apparence',
          [
            _buildSettingsTile(
              context,
              'Mode sombre',
              Icons.dark_mode,
              () {
                // Action vide car le switch gère le changement
              },
              trailing: Switch(
                value: Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
                onChanged: (value) {
                  Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                },
              ),
            ),
          ],
        ),
        _buildSettingsSection(
          'Compte',
          [
            _buildSettingsTile(
              context,
              'Modifier le profil',
              Icons.person,
              () => Navigator.pushNamed(context, AppRoutes.myProfile),
            ),
            _buildSettingsTile(
              context,
              'Changer le mot de passe',
              Icons.lock,
              () => Navigator.pushNamed(context, AppRoutes.changePassword),
            ),
          ],
        ),
        _buildSettingsSection(
          'Préférences',
          [
            _buildSettingsTile(
              context,
              'Favoris',
              Icons.favorite,
              () => Navigator.pushNamed(context, AppRoutes.favorites),
            ),
            _buildSettingsTile(
              context,
              'Notifications',
              Icons.notifications,
              () => Navigator.pushNamed(context, AppRoutes.notifications),
            ),
          ],
        ),
        _buildSettingsSection(
          'Informations',
          [
            _buildSettingsTile(
              context,
              'Politique de confidentialité',
              Icons.privacy_tip,
              () => _showPrivacyPolicy(),
            ),
            _buildSettingsTile(
              context,
              'Conditions d\'utilisation',
              Icons.description,
              () => _showTermsOfService(),
            ),
            _buildSettingsTile(
              context,
              'Aide et support',
              Icons.help,
              () => _showHelpAndSupport(),
            ),
          ],
        ),
        _buildSettingsSection(
          'Sécurité',
          [
            _buildSettingsTile(
              context,
              'Déconnexion',
              Icons.logout,
              _showLogoutDialog,
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    Widget? trailing,
    Color? textColor,
    Color? iconColor,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (isDark ? Colors.blue[300] : Colors.blue),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: isDark ? Colors.grey[400] : Colors.grey,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showPrivacyPolicy() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Politique de confidentialité',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CareNet s\'engage à protéger votre vie privée. Cette politique décrit comment nous collectons, utilisons et protégeons vos informations personnelles.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Informations collectées :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Informations de profil (nom, email, téléphone)\n• Données médicales (antécédents, rendez-vous)\n• Données d\'utilisation de l\'application',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
                SizedBox(height: 16),
                Text(
                  'Utilisation des données :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Fournir des services médicaux\n• Améliorer l\'expérience utilisateur\n• Communication avec les médecins\n• Notifications importantes',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
                SizedBox(height: 16),
                Text(
                  'Protection des données :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Chiffrement des données sensibles\n• Accès limité au personnel autorisé\n• Conformité aux réglementations locales\n• Sauvegarde sécurisée',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Fermer',
                style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTermsOfService() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Conditions d\'utilisation',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'En utilisant CareNet, vous acceptez les conditions suivantes :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Utilisation du service :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Utilisation personnelle uniquement\n• Respect des lois en vigueur\n• Non-utilisation à des fins commerciales\n• Responsabilité de vos actions',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
                SizedBox(height: 16),
                Text(
                  'Obligations :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Fournir des informations exactes\n• Respecter la confidentialité médicale\n• Ne pas partager vos identifiants\n• Signaler les problèmes de sécurité',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
                SizedBox(height: 16),
                Text(
                  'Limitations :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Service non garanti 24/7\n• Responsabilité limitée\n• Modifications possibles des conditions\n• Droit de résiliation',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Fermer',
                style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHelpAndSupport() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            'Aide et support',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Besoin d\'aide ? Nous sommes là pour vous.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                _buildHelpItem(
                  Icons.email,
                  'Email de support',
                  'support@carenet.com',
                  () {},
                ),
                _buildHelpItem(
                  Icons.phone,
                  'Téléphone',
                  '+237 673047340',
                  () {},
                ),
                _buildHelpItem(
                  Icons.chat,
                  'Chat en ligne',
                  'Disponible 24/7',
                  () {},
                ),
                SizedBox(height: 16),
                Text(
                  'FAQ :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '• Comment prendre un rendez-vous ?\n• Comment modifier mon profil ?\n• Comment contacter un médecin ?\n• Problèmes de paiement',
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Fermer',
                style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600]),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
