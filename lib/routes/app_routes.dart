import 'package:flutter/material.dart';
import 'package:carenet/Pages/Page_Patient/home.dart';
import 'package:carenet/Pages/Page_Patient/doctorPage.dart';
import 'package:carenet/Pages/Page_Doctor/HomeDoctor.dart';
import 'package:carenet/Pages/Chat/conversations_list.dart';
import 'package:carenet/Pages/Authentification/login.dart';
import 'package:carenet/Pages/Authentification/signup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Pages/Page_Doctor/PatientList.dart';
import '../Pages/Page_Doctor/PatientPage.dart';
import '../Pages/Page_Doctor/appointment_requests.dart';
import '../Pages/Page_Patient/doctor_list.dart';
import '../Pages/Page_Patient/my_appointments.dart';
import '../Pages/Page_Patient/appointment.dart';
import '../Pages/Page_Patient/reminders.dart';
import '../Pages/ParametreDoctor/ProfilDoctor.dart';
import '../Pages/ParametreDoctor/settingsDoctor.dart';
import '../Pages/ParametreDoctor/change_password_doctor.dart';
import '../Pages/ParametrePatient/change_password.dart';
import '../Pages/ParametrePatient/favorites.dart';
import '../Pages/ParametrePatient/myprofil.dart';
import '../Pages/ParametrePatient/notifications.dart';
import '../Pages/ParametrePatient/patient_settings.dart';
import '../services/firebase/firestore.dart';
import '../Pages/Page_Patient/appointment_success.dart';
import '../Pages/Chat/chat.dart';
import '../services/appointment_service.dart';
import '../services/firebase/auth.dart';
import '../Pages/Page_Admin/HomeAdmin.dart';
import '../Pages/Page_Admin/settings_admin.dart';
import '../Pages/Page_Admin/users_admin.dart';
import '../Pages/Page_Doctor/doctor_consultations_history.dart';


class AppRoutes {
  // Routes principales
  static const String home = '/home';
  static const String homeDoctor = '/homeDoctor';
  static const String chat = '/chat';
  static const String doctorList = '/doctorList';
  static const String patientList = '/patient-list';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String myProfile = '/myProfile';
  static const String myAppointments = '/myAppointments';
  static const String doctorPage = '/doctorPage';
  static const String conversations = '/conversations';
  static const String appointment = 'appointment';
  static const String reminders = '/reminders';
  static const String admin = '/admin';

  // Routes des paramètres patient
  static const String settingsRoute = '/settings';
  static const String changePassword = '/changePassword';
  static const String profil = '/profil';
  static const String notifications = '/notifications';
  static const String favorites = '/favorites';

  // Routes des paramètres docteur
  static const String settingsDoctor = '/settings-doctor';
  static const String changePasswordDoctor = '/change-password-doctor';
  static const String profilDoctor = '/profil-doctor';
  static const String patientPage = '/patient-page';
  static const String appointmentRequests = '/appointment-requests';

  static const String appointmentSuccess = 'appointment-success';

  // Routes des paramètres admin
  static const String settingsAdmin = '/settings_admin';
  static const String usersAdmin = '/users_admin';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;
    final firestoreService = FirestoreService();

    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (context) => Home(
            userName: args?['userName'] ?? '',
            userPhoto: args?['userPhoto'] ?? '',
            userId: args?['userId'] ?? '',
            firestoreService: args?['firestoreService'] ?? FirestoreService(),
          ),
        );
      case homeDoctor:
        return MaterialPageRoute(
          builder: (_) => HomeDoctor(
            firestoreService: args?['firestoreService'] ?? FirestoreService(),
          ),
        );
      case login:
        return MaterialPageRoute(builder: (_) => const Login());
      case signup:
        return MaterialPageRoute(builder: (_) => const Signup());
      case myProfile:
        return MaterialPageRoute(
          builder: (_) => MyProfile(
            firestoreService: firestoreService,
          ),
        );
      case chat:
        return MaterialPageRoute(
          builder: (_) => Chat(
            chatId: args?['chatId'] ?? '',
            currentUserId: args?['currentUserId'] ?? '',
            currentUserName: args?['currentUserName'] ?? '',
            otherParticipantId: args?['otherParticipantId'] ?? '',
            otherParticipantName: args?['otherParticipantName'] ?? '',
            otherParticipantPhoto: args?['otherParticipantPhoto'],
            consultationId: args?['consultationId'],
            patientEmail: args?['patientEmail'],
            patientPhone: args?['patientPhone'],
          ),
        );
      case doctorList:
        return MaterialPageRoute(builder: (_) => const DoctorList());
      case settingsRoute:
        return MaterialPageRoute(
          builder: (_) => PatientSettings(
            firestoreService: firestoreService,
          ),
        );
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePassword());
      case profil:
        return MaterialPageRoute(
          builder: (_) => MyProfile(
            firestoreService: firestoreService,
          ),
        );
      case notifications:
        return MaterialPageRoute(builder: (_) => const Notifications());
      case favorites:
        return MaterialPageRoute(builder: (_) => const Favorites());
      case settingsDoctor:
        return MaterialPageRoute(
          builder: (_) => SettingsDoctor(
            firestoreService: firestoreService,
          ),
        );
      case changePasswordDoctor:
        return MaterialPageRoute(builder: (_) => const ChangePasswordDoctor());
      case profilDoctor:
        return MaterialPageRoute(
          builder: (_) => ProfilDoctor(
            firestoreService: firestoreService,
          ),
        );
      case patientList:
        return MaterialPageRoute(builder: (_) => const PatientList());
      case patientPage:
        return MaterialPageRoute(
          builder: (_) => PatientPage(
            patientId: args?['patientId'] ?? '',
          ),
        );
      case appointmentRequests:
        return MaterialPageRoute(builder: (_) => const AppointmentRequests());
      case myAppointments:
        return MaterialPageRoute(
          builder: (_) => MyAppointments(
            appointmentService: AppointmentService(),
          ),
        );
      case doctorPage:
        return MaterialPageRoute(
          builder: (_) => DoctorPage(
            doctorId: args?['doctorId'] ?? '',
          ),
        );
      case conversations:
        return MaterialPageRoute(
          builder: (_) => ConversationsList(
            currentUserId: args?['currentUserId'] ?? '',
            currentUserName: args?['currentUserName'] ?? '',
            currentUserRole: args?['currentUserRole'] ?? 'patient',
          ),
        );
      case appointmentSuccess:
        return MaterialPageRoute(
          builder: (_) => AppointmentSuccess(
            appointmentId: args?['appointmentId'] ?? '',
            doctorName: args?['doctorName'] ?? '',
          ),
        );
      case appointment:
        return MaterialPageRoute(
          builder: (_) => Appointment(
            doctorId: args?['doctorId'] ?? '',
          ),
        );
      case reminders:
        return MaterialPageRoute(builder: (_) => const Reminders());
      case admin:
        return MaterialPageRoute(
          builder: (_) => const HomeAdmin(),
        );
      case settingsAdmin:
        return MaterialPageRoute(builder: (_) => const SettingsAdmin());
      case usersAdmin:
        return MaterialPageRoute(builder: (_) => const UsersAdmin());
      case '/doctor_consultations_history':
        return MaterialPageRoute(builder: (_) => const DoctorConsultationsHistory());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route non trouvée: ${settings.name}'),
            ),
          ),
        );
    }
  }

  // Méthodes de navigation pour les patients
  static Future<void> navigateToHome(
    BuildContext context, {
    required String userName,
    required String userPhoto,
    required String userId,
    FirestoreService? firestoreService,
  }) async {
    await Navigator.pushNamed(
      context,
      home,
      arguments: {
        'userName': userName,
        'userPhoto': userPhoto,
        'userId': userId,
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToHomeDoctor(
    BuildContext context, {
    required String doctorName,
    required String doctorEmail,
    required String phone,
    required FirestoreService firestoreService,
  }) {
    Navigator.pushNamed(
      context,
      homeDoctor,
      arguments: {
        'doctorName': doctorName,
        'doctorEmail': doctorEmail,
        'phone': phone,
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.pushNamed(context, login);
  }

  static void navigateToSignup(BuildContext context) {
    Navigator.pushNamed(context, signup);
  }

  static void navigateToMyProfile(BuildContext context, {required FirestoreService firestoreService}) {
    Navigator.pushNamed(
      context,
      myProfile,
      arguments: {
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToChat(
    BuildContext context, {
    required String currentUserId,
    required String currentUserName,
    required String currentUserRole,
    required String recipientId,
    required String recipientName,
    required String recipientRole,
    String? recipientPhoto,
    String? consultationId,
    String? patientEmail,
    String? patientPhone,
  }) {
    Navigator.pushNamed(
      context,
      chat,
      arguments: {
        'currentUserId': currentUserId,
        'currentUserName': currentUserName,
        'currentUserRole': currentUserRole,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientRole': recipientRole,
        'recipientPhoto': recipientPhoto,
        'consultationId': consultationId,
        'patientEmail': patientEmail,
        'patientPhone': patientPhone,
      },
    );
  }

  static void navigateToSettings(BuildContext context, {required FirestoreService firestoreService}) {
    Navigator.pushNamed(
      context,
      settingsRoute,
      arguments: {
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToChangePassword(BuildContext context) {
    Navigator.pushNamed(context, changePassword);
  }

  static void navigateToProfil(BuildContext context, {required FirestoreService firestoreService}) {
    Navigator.pushNamed(
      context,
      profil,
      arguments: {
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToNotifications(BuildContext context) {
    Navigator.pushNamed(context, notifications);
  }

  static void navigateToFavorites(BuildContext context) {
    Navigator.pushNamed(context, favorites);
  }

  // Méthodes de navigation pour les docteurs
  static void navigateToSettingsDoctor(BuildContext context, {required FirestoreService firestoreService}) {
    Navigator.pushNamed(
      context,
      settingsDoctor,
      arguments: {
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToChangePasswordDoctor(BuildContext context) {
    Navigator.pushNamed(context, changePasswordDoctor);
  }

  static void navigateToProfilDoctor(BuildContext context, {required FirestoreService firestoreService}) {
    Navigator.pushNamed(
      context,
      profilDoctor,
      arguments: {
        'firestoreService': firestoreService,
      },
    );
  }

  static void navigateToPatientList(BuildContext context) {
    Navigator.pushNamed(context, patientList);
  }

  static void navigateToPatientPage(BuildContext context, String patientId) {
    Navigator.pushNamed(
      context,
      patientPage,
      arguments: {
        'patientId': patientId,
      },
    );
  }

  static void navigateToDoctorList(BuildContext context) {
    Navigator.pushNamed(context, doctorList);
  }

  static void navigateToDoctorPage(BuildContext context, String doctorId) {
    Navigator.pushNamed(
      context,
      doctorPage,
      arguments: {
        'doctorId': doctorId,
      },
    );
  }

  static void navigateToAppointmentRequests(BuildContext context) {
    Navigator.pushNamed(context, appointmentRequests);
  }

  static void navigateToMyAppointments(BuildContext context) {
    Navigator.pushNamed(context, myAppointments);
  }

  static void navigateToReminders(BuildContext context) {
    Navigator.pushNamed(context, reminders);
  }

  // Méthodes de navigation sécurisées
  static Future<void> navigateToHomeSecurely(
    BuildContext context, {
    required String userName,
    required String userPhoto,
    required String userId,
    FirestoreService? firestoreService,
  }) async {
    final authService = AuthService();
    if (authService.isLoggedIn) {
      await Navigator.pushReplacementNamed(
        context,
        home,
        arguments: {
          'userName': userName,
          'userPhoto': userPhoto,
          'userId': userId,
          'firestoreService': firestoreService,
        },
      );
    } else {
      await Navigator.pushReplacementNamed(context, login);
    }
  }

  static Future<void> navigateToHomeDoctorSecurely(
    BuildContext context, {
    required String doctorName,
    required String doctorEmail,
    required String phone,
    required FirestoreService firestoreService,
  }) async {
    final authService = AuthService();
    if (authService.isLoggedIn) {
      await Navigator.pushReplacementNamed(
        context,
        homeDoctor,
        arguments: {
          'doctorName': doctorName,
          'doctorEmail': doctorEmail,
          'phone': phone,
          'firestoreService': firestoreService,
        },
      );
    } else {
      await Navigator.pushReplacementNamed(context, login);
    }
  }

  static Future<void> navigateToLoginSecurely(BuildContext context) async {
    final authService = AuthService();
    if (!authService.isLoggedIn) {
      await Navigator.pushReplacementNamed(context, login);
    }
  }

  static Future<void> navigateToSignupSecurely(BuildContext context) async {
    final authService = AuthService();
    if (!authService.isLoggedIn) {
      await Navigator.pushReplacementNamed(context, signup);
    }
  }

  // Méthode pour vérifier l'authentification avant navigation
  static Future<bool> checkAuthBeforeNavigation(BuildContext context) async {
    final authService = AuthService();
    if (!authService.isLoggedIn) {
      await Navigator.pushReplacementNamed(context, login);
      return false;
    }
    return true;
  }
}

// Widget de protection des routes
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectRoute;

  const AuthGuard({
    Key? key,
    required this.child,
    this.redirectRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return child;
        }

        // Rediriger vers la page de connexion
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(
            context,
            redirectRoute ?? AppRoutes.login,
          );
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
} 