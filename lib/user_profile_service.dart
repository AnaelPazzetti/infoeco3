import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { cooperado, cooperativa, prefeitura, unknown }

class UserProfileInfo {
  final String? cooperativaUid;
  final String? cooperadoUid; // This will be the current user's UID if they are a cooperado
  final String? prefeituraUid;
  final bool isAprovado;
  final UserRole role;

  UserProfileInfo({
    this.cooperativaUid,
    this.cooperadoUid,
    this.prefeituraUid,
    this.isAprovado = true, // Padrão como true para perfis que não são cooperados
    required this.role,
  });
}

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserProfileInfo> getUserProfileInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      return UserProfileInfo(role: UserRole.unknown);
    }
    final userId = user.uid;

    // NEW: Try to get user profile from the dedicated 'users' collection first
    final userDoc = await _firestore.collection('users').doc(userId).get();

    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null) {
        final roleString = data['role'] as String?;
        final userRole = UserRole.values.firstWhere(
          (e) => e.toString().split('.').last == roleString,
          orElse: () => UserRole.unknown,
        );

        if (userRole == UserRole.cooperado) {
          return UserProfileInfo(
            cooperativaUid: data['cooperativaUid'] as String?,
            cooperadoUid: userId,
            prefeituraUid: data['prefeituraUid'] as String?,
            isAprovado: data['isAprovado'] as bool? ?? false,
            role: userRole,
          );
        } else if (userRole == UserRole.cooperativa) {
          // Always try to get prefeituraUid from the user doc, but if missing, migrate from Firestore
          if (data['prefeituraUid'] == null) {
            // Try to find the correct prefeituraUid from Firestore and update the user doc
            final prefeiturasSnapshot = await _firestore.collection('prefeituras').get();
            for (final prefeituraDoc in prefeiturasSnapshot.docs) {
              final cooperativasSnapshot = await prefeituraDoc.reference.collection('cooperativas').get();
              for (final coopDoc in cooperativasSnapshot.docs) {
                if (coopDoc.id == userId) {
                  final coopData = coopDoc.data();
                  String? prefeituraUidFromDoc;
                  if (coopData != null && coopData.containsKey('prefeitura_uid')) {
                    prefeituraUidFromDoc = coopData['prefeitura_uid'];
                  } else {
                    prefeituraUidFromDoc = prefeituraDoc.id;
                  }
                  await _firestore.collection('users').doc(userId).update({
                    'prefeituraUid': prefeituraUidFromDoc,
                  });
                  return UserProfileInfo(
                      cooperativaUid: userId,
                      prefeituraUid: prefeituraUidFromDoc,
                      role: userRole,
                      isAprovado: data['isAprovado'] as bool? ?? false);
                }
              }
            }
            // If not found, fallback
            return UserProfileInfo(cooperativaUid: userId, role: userRole, isAprovado: data['isAprovado'] as bool? ?? false);
          }
          return UserProfileInfo(
              cooperativaUid: userId,
              prefeituraUid: data['prefeituraUid'] as String?,
              role: userRole,
              isAprovado: data['isAprovado'] as bool? ?? false);
        } else if (userRole == UserRole.prefeitura) {
          return UserProfileInfo(prefeituraUid: userId, role: userRole);
        }
      }
    }

    // Phase 1: Check for Cooperado role
    final prefeiturasSnapshot = await _firestore.collection('prefeituras').get();
    for (final prefeituraDoc in prefeiturasSnapshot.docs) {
      final cooperativasSnapshot = await prefeituraDoc.reference.collection('cooperativas').get();
      for (final coopDoc in cooperativasSnapshot.docs) {
        final cooperadoDoc = await coopDoc.reference.collection('cooperados').doc(userId).get();
        if (cooperadoDoc.exists) {
          final data = cooperadoDoc.data() as Map<String, dynamic>;
          // Check for the approval flag. If the flag doesn't exist at all,
          // we assume this is a legacy user who is already approved.
          // If the flag exists, we respect its value (true/false).
          final bool isAprovado = data.containsKey('aprovacao_cooperativa')
              ? (data['aprovacao_cooperativa'] as bool? ?? false)
              : true; // Default to TRUE for legacy users without the flag

          // Also migrate this user to the new 'users' collection for future faster lookups
          await _firestore.collection('users').doc(userId).set({
            'role': UserRole.cooperado.toString().split('.').last,
            'cooperativaUid': coopDoc.id,
            'prefeituraUid': prefeituraDoc.id,
            'isAprovado': isAprovado,
          });

          return UserProfileInfo(
            cooperativaUid: coopDoc.id,
            cooperadoUid: userId,
            prefeituraUid: prefeituraDoc.id,
            isAprovado: isAprovado,
            role: UserRole.cooperado,
          );
        }
      }
    }

    // Phase 2: Check for Cooperativa role (if not found as Cooperado)
    // Re-iterate or assume prefeiturasSnapshot is still valid if this logic is acceptable
    // For simplicity, we re-iterate here. In a performance-critical app, you might optimize.
    for (final prefeituraDoc in prefeiturasSnapshot.docs) {
      final cooperativasSnapshot = await prefeituraDoc.reference.collection('cooperativas').get();
      for (final coopDoc in cooperativasSnapshot.docs) {
        if (coopDoc.id == userId) {
          // Busca prefeitura_uid do doc da cooperativa
          final coopData = coopDoc.data();
          final bool isAprovado = coopData['isAprovado'] as bool? ?? false;
          String? prefeituraUidFromDoc;
          if (coopData != null && coopData.containsKey('prefeitura_uid')) {
            prefeituraUidFromDoc = coopData['prefeitura_uid'];
          } else {
            prefeituraUidFromDoc = prefeituraDoc.id;
          }
          // Migrate this user
          await _firestore.collection('users').doc(userId).set({
            'role': UserRole.cooperativa.toString().split('.').last,
            'prefeituraUid': prefeituraUidFromDoc,
            'isAprovado': isAprovado,
          });
          return UserProfileInfo(
            cooperativaUid: userId,
            prefeituraUid: prefeituraUidFromDoc,
            isAprovado: isAprovado,
            role: UserRole.cooperativa,
          );
        }
      }
    }

    // Phase 3: Check for Prefeitura role (if not found as Cooperado or Cooperativa)
    final docPrefeitura = await _firestore.collection('prefeituras').doc(userId).get();
    if (docPrefeitura.exists) {
      // Migrate this user
      await _firestore.collection('users').doc(userId).set({
        'role': UserRole.prefeitura.toString().split('.').last,
      });
      return UserProfileInfo(role: UserRole.prefeitura, prefeituraUid: userId);
    }

    // Phase 4: Unknown role
    return UserProfileInfo(role: UserRole.unknown);
  }
}
