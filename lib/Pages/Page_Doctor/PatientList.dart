import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart';

class PatientList extends StatefulWidget {
  final bool showAppBar;
  
  const PatientList({
    Key? key,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  _PatientListState createState() => _PatientListState();
}

class _PatientListState extends State<PatientList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Color Scheme consistent with HomeDoctor and previous widgets
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _secondaryColor = const Color(0xFFE3F2FD);
  final Color _accentColor = const Color(0xFF42A5F5);
  final Color _textColor = const Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Widget content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showAppBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 16.0),
              child: Text(
                'Liste des Patients',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          if (!widget.showAppBar)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Liste des Patients',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('UserPatient').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Une erreur est survenue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                    ),
                  );
                }

                final patients = snapshot.data!.docs;

                if (patients.isEmpty) {
                  return Center(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 60,
                              color: _accentColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun patient trouvé',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aucun patient n\'est actuellement enregistré.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    final patientData = patient.data() as Map<String, dynamic>;
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: isDark ? Colors.grey[700] : _secondaryColor,
                          backgroundImage: patientData['photoUrl'] != null &&
                                  patientData['photoUrl'].isNotEmpty
                              ? NetworkImage(patientData['photoUrl'])
                              : const AssetImage('assets/default_profile.png')
                                  as ImageProvider,
                        ),
                        title: Text(
                          patientData['name'] ?? 'Patient sans nom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : _textColor,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (patientData['address'] != null && patientData['address'].toString().isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      patientData['address'],
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(
                              patientData['email'] ?? 'Non renseigné',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tél: ${patientData['phoneNumber'] ?? 'Non renseigné'}',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDark ? Colors.grey[400] : _accentColor,
                          size: 24,
                        ),
                        onTap: () {
                          AppRoutes.navigateToPatientPage(
                            context,
                            patient.id,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    // Bloc de retour final, en dehors de la liste des widgets
    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: content,
      );
    }
    return content;
  }
}