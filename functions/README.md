# Cloud Functions pour CareNet

Ce dossier contient les fonctions Cloud Functions pour gérer Firebase Auth côté serveur.

## Fonctions disponibles

### 1. `disableUser`
- **Description**: Désactive un utilisateur dans Firebase Auth
- **Paramètres**: `{ uid: string }`
- **Retour**: `{ success: boolean, message: string }`

### 2. `enableUser`
- **Description**: Active un utilisateur dans Firebase Auth
- **Paramètres**: `{ uid: string }`
- **Retour**: `{ success: boolean, message: string }`

### 3. `deleteUser`
- **Description**: Supprime un utilisateur de Firebase Auth
- **Paramètres**: `{ uid: string }`
- **Retour**: `{ success: boolean, message: string }`

### 4. `getUserByEmail`
- **Description**: Obtient l'UID d'un utilisateur par email
- **Paramètres**: `{ email: string }`
- **Retour**: `{ success: boolean, uid: string, email: string, disabled: boolean }`

## Installation et déploiement

### Prérequis
1. Node.js 18 ou supérieur
2. Firebase CLI installé globalement
3. Projet Firebase configuré

### Installation des dépendances
```bash
cd functions
npm install
```

### Déploiement
```bash
# Déployer toutes les fonctions
firebase deploy --only functions

# Ou déployer une fonction spécifique
firebase deploy --only functions:disableUser
```

### Test local
```bash
# Démarrer l'émulateur Firebase
firebase emulators:start --only functions

# Tester les fonctions
npm run serve
```

## Sécurité

Toutes les fonctions vérifient que l'utilisateur appelant est un administrateur en vérifiant le token d'authentification.

## Utilisation dans l'application Flutter

Les fonctions sont appelées via le service `AdminAuthService` dans `lib/services/firebase/admin_auth_service.dart`.

## Notes importantes

- Les fonctions nécessitent des permissions d'administrateur Firebase
- Assurez-vous que les règles Firestore permettent l'accès aux collections d'utilisateurs
- Les fonctions sont sécurisées et ne peuvent être appelées que par des administrateurs authentifiés 