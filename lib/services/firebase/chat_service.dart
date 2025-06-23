import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createConversation({
    required String patientId,
    required String doctorId,
    required String patientName,
    required String doctorName,
    String? patientPhoto,
    String? doctorPhoto,
    String? consultationId,
  }) async {
    try {
      // Vérifier si une conversation existe déjà
      final existingChat = await _firestore
          .collection('chats')
          .where('participants', arrayContains: patientId)
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in existingChat.docs) {
        final data = doc.data();
        if (data['participants'].contains(doctorId)) {
          // La conversation existe déjà, on met à jour consultationId
          if (consultationId != null && consultationId.isNotEmpty) {
            await _firestore.collection('chats').doc(doc.id).update({
              'consultationId': consultationId,
              'isActive': true,
              'hiddenFor': FieldValue.arrayRemove([patientId]),
            });
          }
          print('Conversation existante trouvée: ${doc.id}');
          return doc.id;
        }
      }

      // Créer une nouvelle conversation
      final chatRef = await _firestore.collection('chats').add({
        'participants': [patientId, doctorId],
        'participantNames': {
          patientId: patientName,
          doctorId: doctorName,
        },
        'participantPhotos': {
          patientId: patientPhoto,
          doctorId: doctorPhoto,
        },
        'participantRoles': {
          patientId: 'patient',
          doctorId: 'doctor',
        },
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unreadCount': {
          patientId: 0,
          doctorId: 0,
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'consultationId': consultationId ?? '',
      });

      print('Nouvelle conversation créée: ${chatRef.id}');

      return chatRef.id;
    } catch (e) {
      print('Erreur lors de la création de la conversation: $e');
      rethrow;
    }
  }

  Future<bool> canPatientChatWithDoctor({
    required String patientId,
    required String doctorId,
  }) async {
    try {
      // Vérifier si le patient a payé ce médecin
      final paymentDoc = await _firestore
          .collection('consultations')
          .where('patientId', isEqualTo: patientId)
          .where('doctorId', isEqualTo: doctorId)
          .where('paymentStatus', isEqualTo: 'completed')
          .get();

      return paymentDoc.docs.isNotEmpty;
    } catch (e) {
      print('Erreur lors de la vérification du paiement: $e');
      return false;
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String content,
    required String senderName,
    required String senderRole,
  }) async {
    try {
      // Vérifier que la conversation existe et est active
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists || !(chatDoc.data()?['isActive'] ?? false)) {
        throw Exception('Conversation non trouvée ou inactive');
      }

      final message = {
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'senderRole': senderRole,
        'read': false,
        'delivered': false,
        'status': 'sent', // sent, delivered, read
      };

      // Ajouter le message
      final messageRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message);

      // Mettre à jour les informations de la conversation
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      final otherParticipantId = participants.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      );

      // Marquer tous les messages précédents de l'autre participant comme lus
      // car si quelqu'un répond, c'est qu'il a lu les messages précédents
      await _markAllPreviousMessagesAsRead(chatId, otherParticipantId);

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount.$otherParticipantId': FieldValue.increment(1),
        'lastMessageId': messageRef.id,
      });
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
      rethrow;
    }
  }

  Future<void> _markAllPreviousMessagesAsRead(String chatId, String userId) async {
    try {
      // Marquer tous les messages envoyés par cet utilisateur comme lus
      final messagesRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .where('read', isEqualTo: false);

      final messages = await messagesRef.get();
      final batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.update(doc.reference, {
          'read': true,
          'status': 'read',
        });
      }

      await batch.commit();
    } catch (e) {
      print('Erreur lors du marquage des messages précédents comme lus: $e');
    }
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
  }) async {
    try {
      final messagesRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('read', isEqualTo: false);

      final messages = await messagesRef.get();
      final batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.update(doc.reference, {
          'read': true,
          'status': 'read',
        });
      }

      // Réinitialiser le compteur de messages non lus
      batch.update(_firestore.collection('chats').doc(chatId), {
        'unreadCount.$userId': 0,
      });

      await batch.commit();
    } catch (e) {
      print('Erreur lors du marquage des messages comme lus: $e');
      rethrow;
    }
  }

  Future<void> markMessageAsDelivered({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'delivered': true,
        'status': 'delivered',
      });
    } catch (e) {
      print('Erreur lors du marquage du message comme livré: $e');
    }
  }

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserConversationsStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
    try {
      // Essayer d'abord avec l'ID fourni
      var snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('lastMessageTime', descending: true)
          .get();
      
      // Si aucune conversation trouvée, essayer avec l'ID de l'utilisateur connecté
      if (snapshot.docs.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid != userId) {
          snapshot = await _firestore
              .collection('chats')
              .where('participants', arrayContains: currentUser.uid)
              .where('isActive', isEqualTo: true)
              .orderBy('lastMessageTime', descending: true)
              .get();
        }
      }
      
      final conversations = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'chatId': doc.id,
          ...data,
        };
      }).toList();
      
      return conversations;
    } catch (e) {
      print('Erreur lors de la récupération des conversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPatientDoctors(String patientId) async {
    try {
      // Récupérer tous les médecins avec qui le patient a payé
      final consultations = await _firestore
          .collection('consultations')
          .where('patientId', isEqualTo: patientId)
          .where('paymentStatus', isEqualTo: 'completed')
          .get();

      final List<Map<String, dynamic>> doctors = [];
      
      for (var doc in consultations.docs) {
        final data = doc.data();
        final doctorId = data['doctorId'];
        
        // Récupérer les informations du médecin
        final doctorDoc = await _firestore
            .collection('UserDoctor')
            .doc(doctorId)
            .get();
            
        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data()!;
          doctors.add({
            'doctorId': doctorId,
            'doctorName': doctorData['name'] ?? 'Médecin inconnu',
            'doctorPhoto': doctorData['photoUrl'] ?? '',
            'speciality': doctorData['speciality'] ?? 'Médecin généraliste',
            'consultationId': doc.id,
            'paymentDate': data['createdAt'],
          });
        }
      }
      
      return doctors;
    } catch (e) {
      print('Erreur lors de la récupération des médecins du patient: $e');
      return [];
    }
  }
} 