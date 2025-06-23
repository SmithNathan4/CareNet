import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'users_admin.dart';
import 'settings_admin.dart';

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({Key? key}) : super(key: key);

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  int _selectedIndex = 0;

  // Statistiques
  int _nbDoctors = 0;
  int _nbPatients = 0;
  int _nbAdmins = 0;
  int _nbConsultations = 0;
  int _nbEvaluations = 0;
  int _nbPaiements = 0;
  int _nbUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final firestore = FirebaseFirestore.instance;
    final doctors = await firestore.collection('UserDoctor').get();
    final patients = await firestore.collection('UserPatient').get();
    final admins = await firestore.collection('UserAdmin').get();
    final consultations = await firestore.collection('appointments').get();
    final evaluations = await firestore.collection('ratings').get();
    final paiements = await firestore.collection('payments').get().catchError((_) => null);
    setState(() {
      _nbDoctors = doctors.size;
      _nbPatients = patients.size;
      _nbAdmins = admins.size;
      _nbConsultations = consultations.size;
      _nbEvaluations = evaluations.size;
      _nbPaiements = paiements?.size ?? 0;
      _nbUsers = doctors.size + patients.size + admins.size;
    });
  }

  final List<String> _titles = const [
    'Tableau de bord',
    'Utilisateurs',
    'Paramètres',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        automaticallyImplyLeading: false,
      ),
      body: _selectedIndex == 0
          ? _buildDashboard(context)
          : _selectedIndex == 1
              ? const UsersAdmin()
              : const SettingsAdmin(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Utilisateurs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.blueGrey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final List<_StatCardData> stats = [
      _StatCardData('Docteurs', _nbDoctors, Icons.medical_services, Colors.blue),
      _StatCardData('Patients', _nbPatients, Icons.people, Colors.green),
      _StatCardData('Admins', _nbAdmins, Icons.admin_panel_settings, Colors.deepPurple),
      _StatCardData('Utilisateurs', _nbUsers, Icons.group, Colors.indigo),
    ];
    return RefreshIndicator(
      onRefresh: () async => _loadStats(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          double width = constraints.maxWidth;
          if (width > 900) {
            crossAxisCount = 4;
          } else if (width > 600) {
            crossAxisCount = 3;
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: stats.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) => _buildStatCard(stats[index], cardColor, textColor),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(_StatCardData stat, Color? cardColor, Color textColor) {
    return Card(
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(stat.icon, color: stat.color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stat.title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              stat.value.toString(),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: stat.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCardData {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  _StatCardData(this.title, this.value, this.icon, this.color);
}
