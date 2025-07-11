const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Fonction pour désactiver un utilisateur dans Firebase Auth
exports.disableUser = functions.https.onCall(async (data, context) => {
  // Vérifier que l'utilisateur est admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Accès refusé');
  }

  try {
    const { uid } = data;
    
    // Désactiver l'utilisateur dans Firebase Auth
    await admin.auth().updateUser(uid, {
      disabled: true
    });

    return { success: true, message: 'Utilisateur désactivé' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Fonction pour activer un utilisateur dans Firebase Auth
exports.enableUser = functions.https.onCall(async (data, context) => {
  // Vérifier que l'utilisateur est admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Accès refusé');
  }

  try {
    const { uid } = data;
    
    // Activer l'utilisateur dans Firebase Auth
    await admin.auth().updateUser(uid, {
      disabled: false
    });

    return { success: true, message: 'Utilisateur activé' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Fonction pour supprimer un utilisateur de Firebase Auth
exports.deleteUser = functions.https.onCall(async (data, context) => {
  // Vérifier que l'utilisateur est admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Accès refusé');
  }

  try {
    const { uid } = data;
    
    // Supprimer l'utilisateur de Firebase Auth
    await admin.auth().deleteUser(uid);

    return { success: true, message: 'Utilisateur supprimé' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Fonction pour obtenir l'UID d'un utilisateur par email
exports.getUserByEmail = functions.https.onCall(async (data, context) => {
  // Vérifier que l'utilisateur est admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Accès refusé');
  }

  try {
    const { email } = data;
    
    // Obtenir l'utilisateur par email
    const userRecord = await admin.auth().getUserByEmail(email);

    return { 
      success: true, 
      uid: userRecord.uid,
      email: userRecord.email,
      disabled: userRecord.disabled
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
}); 