import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/firebase/chat_service.dart';
import 'package:intl/intl.dart';
import '../../services/appointment_service.dart';
import '../../services/rating_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Payment/payment_methods.dart';

class Chat extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final String otherParticipantId;
  final String otherParticipantName;
  final String? otherParticipantPhoto;
  final String? consultationId;
  final String? patientEmail;
  final String? patientPhone;

  const Chat({
    Key? key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherParticipantId,
    required this.otherParticipantName,
    this.otherParticipantPhoto,
    this.consultationId,
    this.patientEmail,
    this.patientPhone,
  }) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _canSendMessage = true;
  bool _isDoctor = false;
  bool _consultationTerminee = false;
  final AppointmentService _appointmentService = AppointmentService();
  bool _showRatingModal = false;
  double _ratingValue = 0;
  String _comment = '';
  bool _neverShowRating = false;
  final RatingService _ratingService = RatingService();
  String? _consultationId;
  bool _hasRated = false;
  
  // Variables pour les informations des participants
  String? _otherParticipantName;
  String? _otherParticipantPhoto;
  String? _patientName;
  String? _doctorName;

  // Couleurs de l'application
  final Color _primaryColor = const Color(0xFF1976D2);
  final Color _accentColor = const Color(0xFF2196F3);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _errorColor = const Color(0xFFF44336);
  final Color _warningColor = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // D'abord détecter le rôle de l'utilisateur
    await _detectUserRole();
    
    // Ensuite charger les informations des participants
    await _loadParticipantInfo();

    if (widget.chatId.isNotEmpty) {
      _markMessagesAsRead();
      _markMessagesAsDelivered();
      _listenToTypingStatus();
      _fetchConsultationIdAndStatus();
      
      // Ajouter un listener pour marquer les messages comme lus lors du défilement
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Marquer les messages comme lus quand la page devient visible
    if (widget.chatId.isNotEmpty) {
      _markMessagesAsRead();
      _fetchConsultationIdAndStatus();
    }
    // Déclencher la modale d'évaluation si patient, consultation terminée, et pas encore évalué/refusé
    if (!_isDoctor && _consultationTerminee && !_neverShowRating) {
      _checkAndShowRatingModal();
    }
  }

  @override
  void dispose() {
    // Marquer les messages comme lus quand on quitte la page
    if (widget.chatId.isNotEmpty) {
      _markMessagesAsRead();
    }
    // Nettoyer le listener
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    if (widget.chatId.isEmpty) return;
    
    try {
      await _chatService.markMessagesAsRead(
        chatId: widget.chatId,
        userId: widget.currentUserId,
      );
    } catch (e) {
      print('Erreur lors du marquage des messages comme lus: $e');
    }
  }

  Future<void> _markMessagesAsReadWithDelay() async {
    if (widget.chatId.isEmpty) return;
    
    // Ajouter un délai pour éviter les appels trop fréquents
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      await _chatService.markMessagesAsRead(
        chatId: widget.chatId,
        userId: widget.currentUserId,
      );
    } catch (e) {
      print('Erreur lors du marquage des messages comme lus: $e');
    }
  }

  Future<void> _markMessagesAsDelivered() async {
    if (widget.chatId.isEmpty) return;
    
    try {
      // Marquer tous les messages envoyés par l'autre participant comme livrés
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: widget.currentUserId)
          .where('delivered', isEqualTo: false);

      final messages = await messagesRef.get();
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in messages.docs) {
        batch.update(doc.reference, {
          'delivered': true,
          'status': 'delivered',
        });
      }

      await batch.commit();
    } catch (e) {
      print('Erreur lors du marquage des messages comme livrés: $e');
    }
  }

  void _listenToTypingStatus() {
    // Écouter le statut de frappe de l'autre participant
    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final typingUsers = List<String>.from(data['typingUsers'] ?? []);
        final isOtherTyping = typingUsers.contains(widget.otherParticipantId);
        
        if (mounted && isOtherTyping) {
          // Afficher un indicateur "en train d'écrire"
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.otherParticipantName} est en train d\'écrire...'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.grey[600],
            ),
          );
        }
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || !_canSendMessage) return;

    try {
      setState(() => _isLoading = true);

      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        content: _messageController.text.trim(),
        senderName: widget.currentUserName,
        senderRole: widget.currentUserName.contains('Dr.') ? 'doctor' : 'patient',
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Erreur lors de l\'envoi du message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi du message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    // Marquer les messages comme lus quand l'utilisateur fait défiler vers le bas
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _markMessagesAsRead();
    }
  }

  Widget _buildMessageStatus(String status) {
    switch (status) {
      case 'sent':
        return Icon(Icons.check, size: 16, color: Colors.grey[400]);
      case 'delivered':
        return Icon(Icons.done_all, size: 16, color: Colors.grey[400]);
      case 'read':
        return Icon(Icons.done_all, size: 16, color: Colors.blue);
      default:
        return Icon(Icons.schedule, size: 16, color: Colors.grey[400]);
    }
  }

  Future<void> _fetchConsultationIdAndStatus() async {
    try {
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (chatDoc.exists) {
        final data = chatDoc.data() as Map<String, dynamic>;
        _consultationId = data['consultationId'];
        
        if (_consultationId != null) {
          final consultationDoc = await FirebaseFirestore.instance
              .collection('consultations')
              .doc(_consultationId)
              .get();
          
      if (consultationDoc.exists) {
            final consultationData = consultationDoc.data() as Map<String, dynamic>;
            final consultationStatus = consultationData['consultationStatus'];
            
        if (mounted) {
          setState(() {
                _consultationTerminee = consultationStatus == 'terminated';
                if (_consultationTerminee) {
                  _canSendMessage = false; // Empêcher l'envoi de messages
                }
              });
            }
          }
        }
        
        // Recharger les informations du participant une fois que l'ID de consultation est récupéré
        await _loadParticipantInfo();
      }
    } catch (e) {
      print('Erreur lors de la récupération du statut de consultation: $e');
    }
  }

  Future<void> _terminerConsultation() async {
    if (_consultationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de terminer la consultation : ID de consultation manquant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _appointmentService.endConsultation(_consultationId!);
      
      if (mounted) {
        setState(() {
          _consultationTerminee = true;
          _canSendMessage = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation terminée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la terminaison : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkAndShowRatingModal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _consultationId == null || _consultationId!.isEmpty) return;
    
    // Vérifier s'il existe déjà une évaluation pour ce patient et cette consultation
    final existingRating = await FirebaseFirestore.instance
        .collection('ratings')
        .where('patientId', isEqualTo: user.uid)
        .where('consultationId', isEqualTo: _consultationId)
        .get();

    if (existingRating.docs.isNotEmpty) {
      setState(() {
        _hasRated = true;
        _showRatingModal = false;
      });
      return;
    }
    setState(() {
      _showRatingModal = true;
    });
    _showRatingDialog();
  }

  void _showRatingDialog() async {
    if (_showRatingModal || _hasRated || _neverShowRating) return;

    setState(() {
      _showRatingModal = true;
    });

    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        doctorId: widget.otherParticipantId,
        patientId: widget.currentUserId,
        patientName: widget.currentUserName,
        consultationId: _consultationId!,
        onRatingSubmitted: () {
          setState(() {
            _hasRated = true;
            _showRatingModal = false;
            _neverShowRating = true;
          });
        },
      ),
    );

    if (mounted) {
      setState(() {
        _showRatingModal = false;
        if (result == true) { // Ne pas évaluer
          _neverShowRating = true;
        }
      });
    }
  }

  Future<void> _detectUserRole() async {
    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(widget.currentUserId)
          .get();
      final isDoctor = currentUserDoc.exists;
      if (mounted) {
        setState(() {
          _isDoctor = isDoctor;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDoctor = false;
        });
      }
    }
  }

  Future<void> _loadParticipantInfo() async {
    try {
      if (widget.chatId.isNotEmpty) {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .get();
        
        if (chatDoc.exists) {
          final data = chatDoc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          final otherParticipantId = participants.firstWhere(
            (id) => id != widget.currentUserId,
            orElse: () => '',
          );
          
          if (otherParticipantId.isNotEmpty) {
            // Utiliser la même logique que dans conversations_list.dart
            final participantInfo = await _getParticipantInfo(otherParticipantId);
            setState(() {
              _otherParticipantName = participantInfo['name'];
              _otherParticipantPhoto = participantInfo['photo'];
            });
          }
        }
      } else {
        // Si pas de chatId, utiliser les informations passées en paramètres
        setState(() {
          _otherParticipantName = widget.otherParticipantName;
          _otherParticipantPhoto = widget.otherParticipantPhoto;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des informations des participants: $e');
      // Fallback sur les informations passées en paramètres
      setState(() {
        _otherParticipantName = widget.otherParticipantName;
        _otherParticipantPhoto = widget.otherParticipantPhoto;
      });
    }
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
      if (_isDoctor) {
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





  @override
  Widget build(BuildContext context) {
    if (widget.chatId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.otherParticipantName),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Conversation introuvable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Cette conversation n\'existe pas ou a été supprimée',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _otherParticipantPhoto != null && _otherParticipantPhoto!.isNotEmpty
                  ? NetworkImage(_otherParticipantPhoto!)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherParticipantName ?? 'Chargement...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Afficher les informations du patient pour le médecin
                  if (_isDoctor && _consultationId != null)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('consultations')
                          .doc(_consultationId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final consultationData = snapshot.data!.data() as Map<String, dynamic>;
                          final patientName = consultationData['patientName'] ?? _otherParticipantName ?? 'Patient';
                          final consultationStatus = consultationData['consultationStatus'] ?? '';
                          final isActive = consultationStatus == 'active';
                          
                          return Row(
                            children: [
                              Icon(
                                isActive ? Icons.schedule : Icons.check_circle,
                                size: 12,
                                color: isActive ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Consultation avec $patientName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  // Afficher les informations du médecin pour le patient
                  if (!_isDoctor && _consultationId != null)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('consultations')
                          .doc(_consultationId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final consultationData = snapshot.data!.data() as Map<String, dynamic>;
                          final doctorName = consultationData['doctorName'] ?? _otherParticipantName ?? 'Médecin';
                          final consultationStatus = consultationData['consultationStatus'] ?? '';
                          final isActive = consultationStatus == 'active';
                          
                          return Row(
                            children: [
                              Icon(
                                isActive ? Icons.schedule : Icons.check_circle,
                                size: 12,
                                color: isActive ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Consultation avec $doctorName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isDoctor && !_consultationTerminee)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.red),
              tooltip: 'Terminer la consultation',
              onPressed: _isLoading ? null : _terminerConsultation,
            ),
          if (!_canSendMessage && !_isDoctor)
            IconButton(
              icon: Icon(Icons.payment, color: Colors.orange[700]),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                // Récupérer les infos du médecin
                final doctorDoc = await FirebaseFirestore.instance.collection('UserDoctor').doc(widget.otherParticipantId).get();
                final doctorData = doctorDoc.data() ?? {};
                // Récupérer les infos du patient
                final patientDoc = await FirebaseFirestore.instance.collection('UserPatient').doc(user.uid).get();
                final patientData = patientDoc.data() ?? {};
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentMethods(
                      doctorId: widget.otherParticipantId,
                      doctorName: doctorData['name'] ?? 'Médecin',
                      reason: '',
                      patientId: user.uid,
                      patientName: patientData['name'] ?? user.displayName ?? 'Patient',
                      patientPhoto: patientData['profileImageUrl'] ?? user.photoURL,
                      doctorPhoto: doctorData['photoUrl'],
                      onPaymentSuccess: () async {
                        await _fetchConsultationIdAndStatus();
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              tooltip: 'Effectuer un paiement',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildConsultationTerminatedBanner(),
          if (!_canSendMessage && !_isDoctor && !_consultationTerminee)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous devez effectuer un paiement pour pouvoir échanger avec ce médecin.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_consultationTerminee && _isDoctor)
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.all(16),
              child: const Text(
                'La consultation est terminée. Vous ne pouvez plus envoyer de messages.',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_consultationTerminee && !_isDoctor && _hasRated)
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Pour discuter à nouveau avec ce médecin, veuillez effectuer un nouveau paiement.',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_consultationTerminee && !_isDoctor && !_hasRated)
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: const EdgeInsets.all(16),
              child: const Text(
                'La consultation est terminée. Merci de bien vouloir évaluer votre médecin.',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
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
                          'Impossible de charger les messages',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                
                // Marquer les messages comme lus dès qu'ils sont affichés
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsReadWithDelay();
                });
                
                // Filtrer les messages système côté client
                final filteredMessages = messages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['senderId'] != 'system';
                }).toList();
                
                if (filteredMessages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucun message pour le moment',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Commencez la conversation en envoyant un message',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = filteredMessages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == widget.currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          if (_canSendMessage && !_consultationTerminee)
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.grey[700]),
                      onPressed: () {
                        // Non fonctionnel pour l'instant
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fonctionnalité à venir : envoi de fichiers')),
                        );
                      },
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Tapez votre message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoading ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final timestamp = message['timestamp'] as Timestamp?;
    final formattedTime = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
        : '';
    final status = message['status'] ?? 'sent';
    final delivered = message['delivered'] ?? false;
    final read = message['read'] ?? false;
    String actualStatus = status;
    if (isMe) {
      if (read) {
        actualStatus = 'read';
      } else if (delivered) {
        actualStatus = 'delivered';
      } else {
        actualStatus = 'sent';
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundImage: widget.otherParticipantPhoto?.isNotEmpty == true
                  ? NetworkImage(widget.otherParticipantPhoto!)
                  : null,
              child: widget.otherParticipantPhoto?.isEmpty != false
                  ? Icon(Icons.person, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildMessageStatus(actualStatus),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildConsultationTerminatedBanner() {
    if (!_consultationTerminee) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cette consultation est terminée. Vous ne pouvez plus envoyer de messages.',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RatingDialog extends StatefulWidget {
  final String doctorId;
  final String patientId;
  final String patientName;
  final String consultationId;
  final Function() onRatingSubmitted;

  const RatingDialog({
    Key? key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.consultationId,
    required this.onRatingSubmitted,
  }) : super(key: key);

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  double _rating = 0;
  String _comment = '';
  final RatingService _ratingService = RatingService();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Évaluer le médecin'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Merci de donner une note à votre consultation.'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  Icons.star,
                  color: index < _rating ? Colors.amber : Colors.grey[300],
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _rating = index + 1.0;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Commentaire (optionnel)',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            onChanged: (val) => _comment = val,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Plus tard'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Ne pas évaluer'),
        ),
        ElevatedButton(
          onPressed: _rating > 0 && !_isSubmitting ? () async {
            setState(() {
              _isSubmitting = true;
            });
            
            try {
              await _ratingService.createRating(
                patientId: widget.patientId,
                doctorId: widget.doctorId,
                patientInfo: {'name': widget.patientName},
                rating: _rating,
                comment: _comment,
                appointmentId: widget.consultationId,
              );
              
              if (mounted) {
                widget.onRatingSubmitted();
                Navigator.of(context).pop('submitted');
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors de l\'envoi de l\'évaluation: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isSubmitting = false;
                });
              }
            }
          } : null,
          child: _isSubmitting 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}