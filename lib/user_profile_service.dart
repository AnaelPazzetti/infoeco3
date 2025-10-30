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

    // Tenta primeiro consultar na coleção users
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
          if (data['prefeituraUid'] == null) {        
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

    // Checar por cooperado
    final prefeiturasSnapshot = await _firestore.collection('prefeituras').get();
    for (final prefeituraDoc in prefeiturasSnapshot.docs) {
      final cooperativasSnapshot = await prefeituraDoc.reference.collection('cooperativas').get();
      for (final coopDoc in cooperativasSnapshot.docs) {
        final cooperadoDoc = await coopDoc.reference.collection('cooperados').doc(userId).get();
        if (cooperadoDoc.exists) {
          final data = cooperadoDoc.data() as Map<String, dynamic>;          
          final bool isAprovado = data.containsKey('aprovacao_cooperativa')
              ? (data['aprovacao_cooperativa'] as bool? ?? false)
              : true;          


          //Adiciona à coleção users
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

    // Checa por cooperativa
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

          //adiciona à coleção users
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

    // Checa por prefeitura
    final docPrefeitura = await _firestore.collection('prefeituras').doc(userId).get();
    if (docPrefeitura.exists) {
      // Adiciona à coleção users
      await _firestore.collection('users').doc(userId).set({
        'role': UserRole.prefeitura.toString().split('.').last,
      });
      return UserProfileInfo(role: UserRole.prefeitura, prefeituraUid: userId);
    }

    //Sem cargo
    return UserProfileInfo(role: UserRole.unknown);
  }
}