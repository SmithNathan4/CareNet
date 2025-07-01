import 'package:flutter/material.dart';

class UserDetailsAdmin extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String userType;

  const UserDetailsAdmin({Key? key, required this.userData, required this.userType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails $userType'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ...userData.entries.map((e) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(
                  e.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(e.value?.toString() ?? ''),
              ),
            )),
          ],
        ),
      ),
    );
  }
} 