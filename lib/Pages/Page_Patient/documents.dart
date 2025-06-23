import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class Documents extends StatefulWidget {
  const Documents({Key? key}) : super(key: key);

  @override
  State<Documents> createState() => _DocumentsState();
}

class _DocumentsState extends State<Documents> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'Ordonnance';
  bool _isUploading = false;

  final List<String> _categories = [
    'Ordonnance',
    'Analyse médicale',
    'Radiographie',
    'Certificat médical',
    'Résultats de test',
    'Autre',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un titre'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Simuler l'upload d'un fichier (dans une vraie app, vous utiliseriez Firebase Storage)
      await Future.delayed(const Duration(seconds: 2));

      await _firestore.collection('documents').add({
        'userId': userId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'fileName': 'document_${DateTime.now().millisecondsSinceEpoch}.pdf',
        'fileSize': '2.5 MB',
        'uploadDate': FieldValue.serverTimestamp(),
        'isImportant': false,
      });

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = 'Ordonnance';
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document ajouté avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleImportant(String documentId, bool isImportant) async {
    try {
      await _firestore.collection('documents').doc(documentId).update({
        'isImportant': !isImportant,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    try {
      await _firestore.collection('documents').doc(documentId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document supprimé'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'Ordonnance':
        return '💊';
      case 'Analyse médicale':
        return '🔬';
      case 'Radiographie':
        return '📷';
      case 'Certificat médical':
        return '📋';
      case 'Résultats de test':
        return '📊';
      default:
        return '📄';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Ordonnance':
        return Colors.blue;
      case 'Analyse médicale':
        return Colors.green;
      case 'Radiographie':
        return Colors.purple;
      case 'Certificat médical':
        return Colors.orange;
      case 'Résultats de test':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mes Documents',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildAddDocumentCard(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildDocumentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddDocumentCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajouter un document',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre du document',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: _categories.map((String category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Row(
                  children: [
                    Text(_getCategoryIcon(category)),
                    const SizedBox(width: 8),
                    Text(category),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategory = newValue!;
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadDocument,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploading ? 'Upload en cours...' : 'Ajouter le document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('documents')
          .where('userId', isEqualTo: userId)
          .orderBy('uploadDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data?.docs ?? [];

        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun document',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajoutez votre premier document ci-dessus',
                  style: TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index].data() as Map<String, dynamic>;
            final documentId = documents[index].id;
            final title = document['title'] ?? '';
            final description = document['description'] ?? '';
            final category = document['category'] ?? 'Autre';
            final fileName = document['fileName'] ?? '';
            final fileSize = document['fileSize'] ?? '';
            final uploadDate = (document['uploadDate'] as Timestamp?)?.toDate();
            final isImportant = document['isImportant'] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: isImportant
                    ? Border.all(color: Colors.orange, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getCategoryIcon(category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      '$fileName • $fileSize',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    if (uploadDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ajouté le ${uploadDate.day}/${uploadDate.month}/${uploadDate.year}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isImportant ? Icons.star : Icons.star_border,
                        color: isImportant ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () => _toggleImportant(documentId, isImportant),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDocument(documentId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
} 