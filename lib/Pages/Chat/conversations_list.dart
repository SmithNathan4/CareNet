import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';
import '../../services/firebase/chat_service.dart';

class ConversationsList extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final bool showAppBar;

  const ConversationsList({
    Key? key,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserRole = 'patient',
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends State<ConversationsList> {
  bool _selectionMode = false;
  Set<String> _selectedChats = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _updateConversationsStructure();
  }

  Future<void> _updateConversationsStructure() async {
    try {
      // Récupérer toutes les conversations de l'utilisateur
      final conversations = await ChatService().getUserConversations(widget.currentUserId);
      
      for (final conversation in conversations) {
        final chatId = conversation['chatId'];
        final participantNames = conversation['participantNames'] as Map<String, dynamic>?;
        
        // Si participantNames n'existe pas ou est vide, mettre à jour la conversation
        if (participantNames == null || participantNames.isEmpty) {
          await _updateConversationStructure(chatId, conversation);
        }
      }
    } catch (e) {
      print('Erreur lors de la mise à jour des conversations: $e');
    }
  }

  Future<void> _updateConversationStructure(String chatId, Map<String, dynamic> conversation) async {
    try {
      final participants = List<String>.from(conversation['participants'] ?? []);
      final Map<String, String> participantNames = {};
      final Map<String, String> participantPhotos = {};
      final Map<String, String> participantRoles = {};
      
      for (final participantId in participants) {
        if (participantId == widget.currentUserId) continue;
        
        // Déterminer si c'est un médecin ou un patient
        final doctorDoc = await FirebaseFirestore.instance
            .collection('UserDoctor')
            .doc(participantId)
            .get();
        
        if (doctorDoc.exists) {
          // C'est un médecin
          final doctorData = doctorDoc.data() as Map<String, dynamic>;
          participantNames[participantId] = 'Dr. ${doctorData['name'] ?? 'Médecin'}';
          participantPhotos[participantId] = doctorData['photoUrl'] ?? '';
          participantRoles[participantId] = 'doctor';
        } else {
          // C'est un patient
          final patientDoc = await FirebaseFirestore.instance
              .collection('UserPatient')
              .doc(participantId)
              .get();
          
          if (patientDoc.exists) {
            final patientData = patientDoc.data() as Map<String, dynamic>;
            participantNames[participantId] = patientData['name'] ?? 'Patient';
            participantPhotos[participantId] = patientData['profileImageUrl'] ?? '';
            participantRoles[participantId] = 'patient';
          }
        }
      }
      
      // Mettre à jour la conversation avec les nouvelles informations
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'participantRoles': participantRoles,
      });
      
      print('Conversation $chatId mise à jour avec succès');
    } catch (e) {
      print('Erreur lors de la mise à jour de la conversation $chatId: $e');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedChats.clear();
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChats.contains(chatId)) {
        _selectedChats.remove(chatId);
      } else {
        _selectedChats.add(chatId);
      }
    });
  }

  Future<void> _deleteSelectedConversations() async {
    final toDelete = _selectedChats.toList();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer les conversations'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${toDelete.length} conversation(s) ?\n\nCette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      setState(() {
        _selectedChats.clear();
        _selectionMode = false;
      });
      return;
    }

    try {
      for (final chatId in toDelete) {
        // Supprimer tous les messages de la conversation
        final messages = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();
        for (final msg in messages.docs) {
          await msg.reference.delete();
        }
        // Mettre à jour la consultation liée comme terminée
        final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
        final consultationId = chatDoc.data()?['consultationId'];
        if (consultationId != null && consultationId.toString().isNotEmpty) {
          await FirebaseFirestore.instance.collection('consultations').doc(consultationId).update({
            'status': 'completed',
          });
        }
        // Supprimer la conversation elle-même
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .delete();
      }

      setState(() {
        _selectedChats.clear();
        _selectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${toDelete.length} conversation(s) supprimée(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markLastMessageAsRead(String chatId, String userId) async {
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;
    final lastMessageId = chatDoc.data()?['lastMessageId'];
    if (lastMessageId != null) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastReadMessageId.$userId': lastMessageId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: _selectionMode
                  ? Text('${_selectedChats.length} sélectionné(s)')
                  : Text(
                      'MES MESSAGES',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
              actions: [
                if (_selectionMode) ...[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedChats.clear();
                        _selectionMode = false;
                      });
                    },
                    child: Text(
                      'Annuler',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: isDark ? Colors.white : Colors.black87),
                    onPressed: _selectedChats.isEmpty
                        ? null
                        : () async {
                            await _deleteSelectedConversations();
                          },
                  ),
                ] else
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black87),
                    onSelected: (value) {
                      if (value == 'select') {
                        _toggleSelectionMode();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'select',
                        child: Row(
                          children: [
                            Icon(Icons.select_all, color: isDark ? Colors.white : Colors.black87),
                            SizedBox(width: 8),
                            Text('Sélectionner les messages', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          if (!widget.showAppBar)
            // Titre pour la navigation sans AppBar
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
                'Mes Messages',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService().getUserConversationsStream(widget.currentUserId),
              builder: (context, snapshot) {
                return _buildConversationsContent(snapshot, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsContent(AsyncSnapshot<QuerySnapshot> snapshot, bool isDark) {
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vérifiez votre connexion internet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final chats = snapshot.data!.docs;
    
    // Filtrer les conversations cachées côté client
    final visibleChats = chats.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
      return !hiddenFor.contains(widget.currentUserId);
    }).where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final participantNames = Map<String, String>.from(data['participantNames'] ?? {});
      final otherParticipantId = (List<String>.from(data['participants'] ?? [])).firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => '',
      );
      final name = participantNames[otherParticipantId]?.toLowerCase() ?? '';
      return _searchQuery.isEmpty || name.contains(_searchQuery);
    }).toList();
    
    if (visibleChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.currentUserRole == 'doctor' 
                  ? 'Les conversations avec vos patients apparaîtront ici'
                  : 'Commencez une consultation pour échanger avec un médecin',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: visibleChats.length,
      itemBuilder: (context, index) {
        final chat = visibleChats[index].data() as Map<String, dynamic>;
        final chatId = visibleChats[index].id;
        final participants = List<String>.from(chat['participants'] ?? []);
        final otherParticipantId = participants.firstWhere(
          (id) => id != widget.currentUserId,
          orElse: () => '',
        );
        
        final unreadCount = Map<String, int>.from(chat['unreadCount'] ?? {});
        final currentUserUnreadCount = unreadCount[widget.currentUserId] ?? 0;
        final lastMessage = chat['lastMessage'] ?? '';
        final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
        final lastMessageSenderId = chat['lastMessageSenderId'] ?? '';
        
        // Toujours utiliser FutureBuilder pour récupérer les vraies informations depuis Firestore
        return FutureBuilder<Map<String, String>>(
          future: _getParticipantInfo(otherParticipantId),
          builder: (context, snapshot) {
            String otherParticipantName = 'Chargement...';
            String otherParticipantPhoto = '';
            
            if (snapshot.hasData) {
              otherParticipantName = snapshot.data!['name'] ?? 'Utilisateur inconnu';
              otherParticipantPhoto = snapshot.data!['photo'] ?? '';
            } else if (snapshot.hasError) {
              otherParticipantName = 'Erreur de chargement';
            }

            String displayName = otherParticipantName;
            if (widget.currentUserRole == 'patient') {
              if (displayName.toLowerCase().contains('dr') == false) {
                displayName = 'DR $displayName';
              }
            }

            return _selectionMode
                ? _buildSelectableChatTile(
                    chatId: chatId,
                    otherParticipantId: otherParticipantId,
                    otherParticipantName: displayName,
                    otherParticipantPhoto: otherParticipantPhoto,
                    lastMessage: lastMessage,
                    lastMessageTime: lastMessageTime,
                    lastMessageSenderId: lastMessageSenderId,
                    currentUserUnreadCount: currentUserUnreadCount,
                    isSelected: _selectedChats.contains(chatId),
                    isDark: isDark,
                  )
                : _buildChatTile(
                    chatId: chatId,
                    otherParticipantId: otherParticipantId,
                    otherParticipantName: displayName,
                    otherParticipantPhoto: otherParticipantPhoto,
                    lastMessage: lastMessage,
                    lastMessageTime: lastMessageTime,
                    lastMessageSenderId: lastMessageSenderId,
                    currentUserUnreadCount: currentUserUnreadCount,
                    isDark: isDark,
                  );
          },
        );
      },
    );
  }

  Widget _buildChatTile({
    required String chatId,
    required String otherParticipantId,
    required String otherParticipantName,
    required String otherParticipantPhoto,
    required String lastMessage,
    required Timestamp? lastMessageTime,
    required String lastMessageSenderId,
    required int currentUserUnreadCount,
    required bool isDark,
  }) {
    final isLastMessageFromMe = lastMessageSenderId == widget.currentUserId;
    final formattedTime = lastMessageTime != null
        ? DateFormat('HH:mm').format(lastMessageTime.toDate())
        : '';

    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    return FutureBuilder<DocumentSnapshot>(
      future: chatDoc.get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        String? lastMessageId = data?['lastMessageId'];
        Map<String, dynamic>? lastReadMessageId = data?['lastReadMessageId'] != null
            ? Map<String, dynamic>.from(data!['lastReadMessageId'])
            : null;
        bool isUnread = false;
        if (lastMessageId != null && lastReadMessageId != null) {
          isUnread = lastReadMessageId[widget.currentUserId] != lastMessageId;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                  backgroundImage: otherParticipantPhoto.isNotEmpty
                      ? NetworkImage(otherParticipantPhoto)
                      : null,
                  child: otherParticipantPhoto.isEmpty
                      ? Icon(Icons.person, size: 25, color: isDark ? Colors.white : Colors.grey[600])
                      : null,
                ),
                if (isUnread)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    otherParticipantName,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isLastMessageFromMe)
                      Icon(
                        Icons.check,
                        size: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                    if (isLastMessageFromMe) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lastMessage.isEmpty ? 'Aucun message' : lastMessage,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            trailing: null,
            onTap: () async {
              // Marquer le dernier message comme lu pour l'utilisateur courant
              await _markLastMessageAsRead(chatId, widget.currentUserId);
              
              // Récupérer les informations du chat pour passer les détails du patient
              final chatDoc = await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .get();
              
              String? consultationId;
              String? patientEmail;
              String? patientPhone;
              
              if (chatDoc.exists) {
                final data = chatDoc.data() as Map<String, dynamic>?;
                consultationId = data?['consultationId'];
                final patientInfo = data?['patientInfo'] as Map<String, dynamic>?;
                if (patientInfo != null) {
                  patientEmail = patientInfo['email'];
                  patientPhone = patientInfo['phone'];
                }
              }
              
              await Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'chatId': chatId,
                  'currentUserId': widget.currentUserId,
                  'currentUserName': widget.currentUserName,
                  'otherParticipantId': otherParticipantId,
                  'otherParticipantName': otherParticipantName,
                  'otherParticipantPhoto': otherParticipantPhoto,
                  'consultationId': consultationId,
                  'patientEmail': patientEmail,
                  'patientPhone': patientPhone,
                },
              );
              await Future.delayed(const Duration(milliseconds: 300));
              setState(() {}); // Rafraîchir la liste après retour du chat
            },
          ),
        );
      },
    );
  }

  Widget _buildSelectableChatTile({
    required String chatId,
    required String otherParticipantId,
    required String otherParticipantName,
    required String otherParticipantPhoto,
    required String lastMessage,
    required Timestamp? lastMessageTime,
    required String lastMessageSenderId,
    required int currentUserUnreadCount,
    required bool isSelected,
    required bool isDark,
  }) {
    final isLastMessageFromMe = lastMessageSenderId == widget.currentUserId;
    final formattedTime = lastMessageTime != null
        ? DateFormat('HH:mm').format(lastMessageTime.toDate())
        : '';

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (value) {
          _toggleChatSelection(chatId);
        },
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              otherParticipantName,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          if (isLastMessageFromMe)
            Icon(
              Icons.check,
              size: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          if (isLastMessageFromMe) const SizedBox(width: 4),
          Expanded(
            child: Text(
              lastMessage.isEmpty ? 'Aucun message' : lastMessage,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _getParticipantInfo(String participantId) async {
    try {
      if (participantId.isEmpty) {
        return {'name': 'Utilisateur inconnu', 'photo': ''};
      }

      // Essayer d'abord de récupérer depuis UserDoctor
      final doctorDoc = await FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(participantId)
          .get();
      
      if (doctorDoc.exists) {
        final doctorData = doctorDoc.data() as Map<String, dynamic>;
        final doctorName = doctorData['name'] ?? 'Médecin';
        return {
          'name': 'Dr. $doctorName',
          'photo': doctorData['photoUrl'] ?? '',
        };
      }
      
      // Si ce n'est pas un médecin, essayer UserPatient
      final patientDoc = await FirebaseFirestore.instance
          .collection('UserPatient')
          .doc(participantId)
          .get();
      
      if (patientDoc.exists) {
        final patientData = patientDoc.data() as Map<String, dynamic>;
        final patientName = patientData['name'] ?? 'Patient';
        return {
          'name': patientName,
          'photo': patientData['profileImageUrl'] ?? '',
        };
      }
      
      // Si l'utilisateur n'est trouvé dans aucune collection, essayer de récupérer depuis les consultations
      if (widget.currentUserRole == 'doctor') {
        // Le médecin cherche le nom du patient
        final consultationQuery = await FirebaseFirestore.instance
            .collection('consultations')
            .where('patientId', isEqualTo: participantId)
            .where('doctorId', isEqualTo: widget.currentUserId)
            .limit(1)
            .get();
        
        if (consultationQuery.docs.isNotEmpty) {
          final consultationData = consultationQuery.docs.first.data();
          final patientName = consultationData['patientName']?.toString();
          if (patientName != null && patientName.isNotEmpty) {
            return {
              'name': patientName,
              'photo': consultationData['patientPhoto']?.toString() ?? '',
            };
          }
        }
      } else {
        // Le patient cherche le nom du médecin
        final consultationQuery = await FirebaseFirestore.instance
            .collection('consultations')
            .where('doctorId', isEqualTo: participantId)
            .where('patientId', isEqualTo: widget.currentUserId)
            .limit(1)
            .get();
        
        if (consultationQuery.docs.isNotEmpty) {
          final consultationData = consultationQuery.docs.first.data();
          final doctorName = consultationData['doctorName']?.toString();
          if (doctorName != null && doctorName.isNotEmpty) {
            return {
              'name': doctorName,
              'photo': consultationData['doctorPhoto']?.toString() ?? '',
            };
          }
        }
      }
      
      // Fallback final
      return {'name': 'Utilisateur inconnu', 'photo': ''};
    } catch (e) {
      print('Erreur lors de la récupération des informations du participant $participantId: $e');
      return {'name': 'Erreur de chargement', 'photo': ''};
    }
  }
} 