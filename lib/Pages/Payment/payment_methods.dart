import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carenet/routes/app_routes.dart';
import 'package:carenet/services/firebase/chat_service.dart';
import 'package:carenet/services/firebase/firestore.dart';

class PaymentMethods extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String reason;
  final String patientId;
  final String patientName;
  final String? patientPhoto;
  final String? doctorPhoto;
  final VoidCallback? onPaymentSuccess;

  const PaymentMethods({
    Key? key,
    required this.doctorId,
    required this.doctorName,
    required this.reason,
    required this.patientId,
    required this.patientName,
    this.patientPhoto,
    this.doctorPhoto,
    this.onPaymentSuccess,
  }) : super(key: key);

  @override
  _PaymentMethodsState createState() => _PaymentMethodsState();
}

class _PaymentMethodsState extends State<PaymentMethods> with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedPaymentMethod = 'Orange Money';
  bool _isProcessing = false;
  bool _isPasswordVisible = false;
  late String _doctorName;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color backgroundColor = Color(0xFFF6F8FA);
  static const Color cardColor = Colors.white;
  static const Color successColor = Colors.green;
  static const Color errorColor = Colors.red;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'MTN Mobile Money',
      'icon': Icons.phone_android,
      'color': Color(0xFFFFD700),
      'image': 'assets/MTN.jpg',
      'prefix': '67',
    },
    {
      'name': 'Orange Money',
      'icon': Icons.phone_iphone,
      'color': Color(0xFFFF8C00),
      'image': 'assets/Orange.png',
      'prefix': '69',
    },
  ];

  double? _tarif;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _doctorName = widget.doctorName;
    _loadTarif();
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final doctorDoc = await FirebaseFirestore.instance
          .collection('UserDoctor')
          .doc(widget.doctorId)
          .get();

      if (doctorDoc.exists && mounted) {
        setState(() {
          _doctorName = doctorDoc.data()?['name'] as String? ?? 'Médecin';
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des informations du médecin: $e');
    }
  }

  Future<void> _loadTarif() async {
    final tarif = await _firestoreService.getGlobalTarif();
    if (mounted) setState(() => _tarif = tarif);
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String? _getSelectedMethodPrefix() {
    final method = _paymentMethods.firstWhere(
      (m) => m['name'] == _selectedPaymentMethod,
      orElse: () => {'prefix': null},
    );
    return method['prefix'];
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod.isEmpty) {
      _showSnackBar('Veuillez sélectionner une méthode de paiement', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      final currentUserId = currentUser.uid;
      if (currentUserId.isEmpty) {
        throw Exception('ID utilisateur manquant');
      }

      // VÉRIFICATION : Empêcher les paiements multiples au même médecin
      final existingActiveConsultation = await FirebaseFirestore.instance
          .collection('consultations')
          .where('patientId', isEqualTo: currentUserId)
          .where('doctorId', isEqualTo: widget.doctorId)
          .where('consultationStatus', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingActiveConsultation.docs.isNotEmpty) {
        _showSnackBar(
          'Vous avez déjà une consultation en cours avec ce médecin. Veuillez terminer la consultation actuelle avant d\'en commencer une nouvelle.',
          isError: true,
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Créer une nouvelle consultation seulement s'il n'y en a pas d'active
      final newConsultationRef = await FirebaseFirestore.instance.collection('consultations').add({
        'patientId': currentUserId,
        'doctorId': widget.doctorId,
        'patientName': widget.patientName,
        'doctorName': widget.doctorName,
        'reason': widget.reason,
        'createdAt': FieldValue.serverTimestamp(),
        'paymentMethod': _selectedPaymentMethod,
        'amount': _tarif ?? 0,
        'patientPhoto': widget.patientPhoto ?? '',
        'doctorPhoto': widget.doctorPhoto ?? '',
        'paymentStatus': 'completed',
        'consultationStatus': 'active', // Statut de consultation actif
      });
      final consultationId = newConsultationRef.id;

      // Créer le chat associé à cette nouvelle consultation
      final chatService = ChatService();
      final chatId = await chatService.createConversation(
        patientId: widget.patientId ?? '',
        doctorId: widget.doctorId ?? '',
        patientName: widget.patientName ?? '',
        doctorName: _doctorName ?? '',
        patientPhoto: widget.patientPhoto ?? '',
        doctorPhoto: widget.doctorPhoto ?? '',
        consultationId: consultationId,
      );

      if (widget.onPaymentSuccess != null) {
        widget.onPaymentSuccess!();
      }

      // Afficher le message de succès et rediriger
      if (mounted) {
        _showSnackBar('Paiement réussi ! Consultation créée avec succès.', isError: false);
        
        // Rediriger vers le menu principal avec l'onglet Messages sélectionné
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
          arguments: {
            'userName': _auth.currentUser?.displayName ?? 'Patient',
            'userPhoto': _auth.currentUser?.photoURL ?? '',
            'userId': _auth.currentUser?.uid ?? '',
            'firestoreService': null,
            'selectedIndex': 2, // Index de l'onglet Messages (ConversationsList)
          },
        );
      }
    } catch (e) {
      _showSnackBar('Erreur lors du paiement : $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showPaymentSuccessDialog() async {
    try {
      // Créer la conversation
      final chatService = ChatService();
      final chatId = await chatService.createConversation(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        patientName: widget.patientName,
        doctorName: _doctorName,
        patientPhoto: widget.patientPhoto,
        doctorPhoto: widget.doctorPhoto,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: successColor, size: 32),
              const SizedBox(width: 8),
              const Text('Paiement Réussi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Médecin: Dr. $_doctorName'),
              const SizedBox(height: 8),
              Text('Motif: ${widget.reason}'),
              const SizedBox(height: 8),
              Text('Montant: ${_tarif?.toStringAsFixed(0) ?? "-"} FCFA'),
              const SizedBox(height: 8),
              Text('Méthode: $_selectedPaymentMethod'),
              const SizedBox(height: 16),
              const Text(
                'Vous allez être redirigé vers la page de chat pour commencer votre consultation.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                // Naviguer vers la conversation
                Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {
                    'chatId': chatId,
                    'currentUserId': widget.patientId,
                    'currentUserName': widget.patientName,
                    'otherParticipantId': widget.doctorId,
                    'otherParticipantName': 'Dr. $_doctorName',
                    'otherParticipantPhoto': widget.doctorPhoto,
                  },
                );
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Erreur lors de la création de la conversation: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création de la conversation: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPaymentOption(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['name'];

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = method['name'];
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset(
                  method['image'],
                  height: 60,
                  width: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  method['name'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? primaryBlue : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: primaryBlue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Médecin: Dr. $_doctorName'),
                const SizedBox(height: 8),
                Text('Motif: ${widget.reason}'),
                const SizedBox(height: 8),
                Text('Montant: ${_tarif?.toStringAsFixed(0) ?? "-"} FCFA'),
                const SizedBox(height: 8),
                Text('Méthode: $_selectedPaymentMethod'),
                const SizedBox(height: 24),
                const Text(
                  'Choisissez votre méthode de paiement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: _paymentMethods.map(_buildPaymentOption).toList(),
                ),
                const SizedBox(height: 24),
                if (_selectedPaymentMethod != null) ...[
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: 'Ex: ${_getSelectedMethodPrefix()}XXXXXXXX',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre numéro de téléphone';
                      }
                      if (value.length != 9) {
                        return 'Le numéro doit contenir 9 chiffres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Code PIN / Mot de passe',
                      hintText: 'Votre code PIN',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre code PIN';
                      }
                      if (value.length < 4) {
                        return 'Code PIN trop court';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Effectuer le paiement',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}