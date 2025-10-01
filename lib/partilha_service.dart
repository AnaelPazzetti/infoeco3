// lib/partilha_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PartilhaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> realizarPartilhaParcial({
    required String prefeituraUid,
    required String cooperativaUid,
    required String material,
    required Map<String, dynamic> materiaisGerais,
    required Map<String, dynamic> materiaisIndividuais,
  }) async {
    final docCoopRef = _firestore
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid);

    await _firestore.runTransaction((transaction) async {
      final docCoopSnap = await transaction.get(docCoopRef);

      if (!docCoopSnap.exists) {
        throw Exception('Erro: Cooperativa não encontrada.');
      }

      final docCoopData = docCoopSnap.data()!;
      final materiais = docCoopData['materiais'] as Map<String, dynamic>? ?? {};
      final materialInfo = materiais[material] as Map<String, dynamic>?;

      if (materialInfo == null) {
        throw Exception('Erro: Dados para o material "$material" não encontrados.');
      }

      final preco = (materialInfo['preco'] ?? 0).toDouble();
      final tipoPartilha = (materialInfo['partilha'] as String?)?.toLowerCase() ?? 'individual';

      if (tipoPartilha == 'geral') {
        final quantidade = materiaisGerais[material];
        
        transaction.set(docCoopRef.collection('partilhas').doc(), {
          'materiaisG_qtd': {material: quantidade},
          'materiais': {material: materialInfo},
          'data': DateTime.now().toIso8601String(),
          'parcial': true,
        });

        Map<String, dynamic> currentMateriaisGQtd = Map<String, dynamic>.from(docCoopData['materiaisG_qtd'] ?? {});
        currentMateriaisGQtd[material] = 0;
        transaction.update(docCoopRef, {'materiaisG_qtd': currentMateriaisGQtd});

      } else { // 'individual'
        final quantidade = materiaisIndividuais[material];

        transaction.set(docCoopRef.collection('partilhas').doc(), {
          'materiais_qtd': {material: quantidade},
          'materiais': {material: materialInfo},
          'data': DateTime.now().toIso8601String(),
          'parcial': true,
        });

        final cooperadosSnapshot = await docCoopRef.collection('cooperados').get();
        
        List<Map<String, dynamic>> cooperadosDataForPartilha = [];

        for (final cooperadoDoc in cooperadosSnapshot.docs) {
          final cooperadoData = cooperadoDoc.data();
          Map<String, dynamic> materiaisQtdCoop = Map<String, dynamic>.from(cooperadoData['materiais_qtd'] ?? {});
          
          final qtdMaterialCooperado = (materiaisQtdCoop[material] ?? 0) as num;
          if (qtdMaterialCooperado > 0) {
              final valorPartilhaDoc = preco * qtdMaterialCooperado;
              materiaisQtdCoop[material] = 0;

              final nomeCooperado = cooperadoData['nome'] ?? 'Nome não encontrado';
              cooperadosDataForPartilha.add({
                "cooperado_uid": cooperadoDoc.id,
                "cooperado_nome": nomeCooperado,
                "valor_recebido": valorPartilhaDoc,
                "material_entregue": {
                  "nome": material,
                  "quantidade": qtdMaterialCooperado
                }
              });

              transaction.set(cooperadoDoc.reference.collection('partilhas').doc(), {
                  'materiais_qtd': {material: qtdMaterialCooperado},
                  'materiais': {material: materialInfo},
                  'data': DateTime.now().toIso8601String(),
                  'valor_partilha': valorPartilhaDoc,
                  'parcial': true,
              });

              transaction.update(cooperadoDoc.reference, {
                  'valor_partilha': FieldValue.increment(-valorPartilhaDoc),
                  'materiais_qtd': materiaisQtdCoop,
              });
          }
        }

        if (cooperadosDataForPartilha.isNotEmpty) {
          transaction.set(docCoopRef.collection('partilhas_realizadas').doc(), {
            'timestamp': FieldValue.serverTimestamp(),
            'parcial': true,
            'material_partilhado': material,
            'cooperados': cooperadosDataForPartilha,
          });
        }

        Map<String, dynamic> currentMateriaisQtd = Map<String, dynamic>.from(docCoopData['materiais_qtd'] ?? {});
        currentMateriaisQtd[material] = 0;
        transaction.update(docCoopRef, {'materiais_qtd': currentMateriaisQtd});
      }

      final coletasSnapshot = await docCoopRef
          .collection('coletas_materiais')
          .where('partilha_realizada', isEqualTo: false)
          .where('material.material_name', isEqualTo: material)
          .get();

      for (final doc in coletasSnapshot.docs) {
        transaction.update(doc.reference, {'partilha_realizada': true});
      }
    });
  }

  Future<void> realizarPartilhaTotal({
    required String prefeituraUid,
    required String cooperativaUid,
    required Map<String, dynamic> materiaisIndividuais,
  }) async {
    final docCoopRef = _firestore
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid);

    await _firestore.runTransaction((transaction) async {
      final docCoopSnap = await transaction.get(docCoopRef);
      if (!docCoopSnap.exists) {
        throw Exception('Cooperativa não encontrada.');
      }
      final docCoopData = docCoopSnap.data()!;
      final Map<String, dynamic> materiais = Map<String, dynamic>.from(docCoopData['materiais'] ?? {});

      transaction.set(docCoopRef.collection('partilhas').doc(), {
        'data': DateTime.now().toIso8601String(),
        'parcial': false,
        'materiais': materiais,
        'materiais_qtd': Map<String, dynamic>.from(materiaisIndividuais),
      });

      final resetMap = Map<String, dynamic>.from(
          materiaisIndividuais.map((k, v) => MapEntry(k, 0)));
      transaction.update(docCoopRef, {'materiais_qtd': resetMap});

      List<Map<String, dynamic>> cooperadosDataForPartilha = [];
      final cooperadosSnapshot = await docCoopRef.collection('cooperados').get();

      for (final cooperadoDoc in cooperadosSnapshot.docs) {
        final cooperadoData = cooperadoDoc.data();
        final valorPartilhaAtual = (cooperadoData['valor_partilha'] ?? 0).toDouble();
        final materiaisQtdCooperado = Map<String, dynamic>.from(cooperadoData['materiais_qtd'] ?? {});
        final nomeCooperado = cooperadoData['nome'] ?? 'Nome não encontrado';

        cooperadosDataForPartilha.add({
          "cooperado_uid": cooperadoDoc.id,
          "cooperado_nome": nomeCooperado,
          "valor_recebido": valorPartilhaAtual,
          "materiais_entregues": materiaisQtdCooperado,
        });

        transaction.set(cooperadoDoc.reference.collection('partilhas').doc(), {
          'data': DateTime.now().toIso8601String(),
          'parcial': false,
          'materiais': materiais,
          'materiais_qtd': materiaisQtdCooperado,
          'valor_partilha': valorPartilhaAtual,
        });

        final resetCoopMap = Map<String, dynamic>.from(
            materiaisQtdCooperado.map((k, v) => MapEntry(k, 0)));
        transaction.update(cooperadoDoc.reference, {
          'materiais_qtd': resetCoopMap,
          'valor_partilha': 0
        });
      }

      transaction.set(docCoopRef.collection('partilhas_realizadas').doc(), {
        'timestamp': FieldValue.serverTimestamp(),
        'cooperados': cooperadosDataForPartilha,
      });

      final coletasSnapshot = await docCoopRef
          .collection('coletas_materiais')
          .where('partilha_realizada', isEqualTo: false)
          .get();

      for (final doc in coletasSnapshot.docs) {
        transaction.update(doc.reference, {'partilha_realizada': true});
      }
    });
  }
}
