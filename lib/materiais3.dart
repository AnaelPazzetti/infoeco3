// Este arquivo implementa a funcionalidade de exibição de materiais separados
// por cooperativas. Ele exibe uma tabela com os materiais e suas quantidades.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis

class Materiais3 extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const Materiais3({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});

  @override
  _Materiais3State createState() => _Materiais3State();
}

class _Materiais3State extends State<Materiais3> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  Map<String, dynamic> materiaisGerais = {};
  Map<String, dynamic> materiaisIndividuais = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarMateriaisQtd();
  }

  // Carrega o UID da cooperativa logada e os materiais_qtd
  Future<void> _carregarMateriaisQtd() async {
    setState(() => isLoading = true);
    // Se os UIDs foram passados pelo widget (modo prefeitura), use-os diretamente.
    if (widget.cooperativaUid != null && widget.prefeituraUid != null) {
      cooperativaUid = widget.cooperativaUid;
      prefeituraUid = widget.prefeituraUid;
    } else {
      // Caso contrário, busca as informações do perfil do usuário logado.
      final profile = await _userProfileService.getUserProfileInfo();
      if (profile.role == UserRole.cooperativa) {
        cooperativaUid = profile.cooperativaUid;
        prefeituraUid = profile.prefeituraUid;
      }
    }

    if (cooperativaUid == null || prefeituraUid == null) {
      setState(() => isLoading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final individuais = data.containsKey('materiais_qtd')
          ? Map<String, dynamic>.from(data['materiais_qtd'])
          : <String, dynamic>{};
      final gerais = data.containsKey('materiaisG_qtd')
          ? Map<String, dynamic>.from(data['materiaisG_qtd'])
          : <String, dynamic>{};

      setState(() {
        materiaisIndividuais = individuais;
        materiaisGerais = gerais;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  // Função para realizar a partilha parcial de um material
  Future<void> _partilhaParcial(String material) async {
    if (cooperativaUid == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmação'),
        content: Text('Tem certeza que deseja realizar a partilha parcial de "$material"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => isLoading = true);

    final docCoopRef = FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid);
    
    final docCoopSnap = await docCoopRef.get();
    
    if (!docCoopSnap.exists) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Cooperativa não encontrada.')),
        );
        return;
    }

    final docCoopData = docCoopSnap.data()!;
    final materiais = docCoopData['materiais'] as Map<String, dynamic>? ?? {};
    final materialInfo = materiais[material] as Map<String, dynamic>?;

    if (materialInfo == null) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: Dados para o material "$material" não encontrados.')),
        );
        return;
    }

    final preco = (materialInfo['preco'] ?? 0).toDouble();
    final tipoPartilha = (materialInfo['partilha'] as String?)?.toLowerCase() ?? 'individual';

    if (tipoPartilha == 'geral') {
      // Partilha Parcial for "Geral" material
      final quantidade = materiaisGerais[material];
      
      // 1. Create partilha document for cooperativa
      await docCoopRef.collection('partilhas').add({
        'materiaisG_qtd': {material: quantidade},
        'materiais': {material: materialInfo},
        'data': DateTime.now().toIso8601String(),
        'parcial': true,
      });

      // 2. Reset material in cooperativa's materiaisG_qtd
      Map<String, dynamic> currentMateriaisGQtd = Map<String, dynamic>.from(docCoopData['materiaisG_qtd'] ?? {});
      currentMateriaisGQtd[material] = 0;
      await docCoopRef.update({'materiaisG_qtd': currentMateriaisGQtd});

    } else { // 'individual'
      // Partilha Parcial for "Individual" material
      final quantidade = materiaisIndividuais[material];

      // 1. Create partilha document for cooperativa
      await docCoopRef.collection('partilhas').add({
        'materiais_qtd': {material: quantidade},
        'materiais': {material: materialInfo},
        'data': DateTime.now().toIso8601String(),
        'parcial': true,
      });

      // 2. Loop through cooperados and update their data
      final cooperadosSnapshot = await docCoopRef.collection('cooperados').get();
      
      List<Map<String, dynamic>> cooperadosDataForPartilha = [];

      for (final cooperadoDoc in cooperadosSnapshot.docs) {
        final cooperadoData = cooperadoDoc.data();
        Map<String, dynamic> materiaisQtdCoop = Map<String, dynamic>.from(cooperadoData['materiais_qtd'] ?? {});
        
        final qtdMaterialCooperado = (materiaisQtdCoop[material] ?? 0) as num;
        if (qtdMaterialCooperado > 0) {
            final valorPartilhaDoc = preco * qtdMaterialCooperado;
            materiaisQtdCoop[material] = 0;

            // Gather data for summary doc
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

            // Create partilha for cooperado
            await cooperadoDoc.reference.collection('partilhas').add({
                'materiais_qtd': {material: qtdMaterialCooperado},
                'materiais': {material: materialInfo},
                'data': DateTime.now().toIso8601String(),
                'valor_partilha': valorPartilhaDoc,
                'parcial': true,
            });

            // Update cooperado's valor_partilha and materiais_qtd
            await cooperadoDoc.reference.update({
                'valor_partilha': FieldValue.increment(-valorPartilhaDoc),
                'materiais_qtd': materiaisQtdCoop,
            });
        }
      }

      // Create the summary document for partial share
      if (cooperadosDataForPartilha.isNotEmpty) {
        await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('partilhas_cooperados')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'parcial': true,
            'material_partilhado': material,
            'cooperados': cooperadosDataForPartilha,
          });
      }

      // 3. Reset material in cooperativa's materiais_qtd
      Map<String, dynamic> currentMateriaisQtd = Map<String, dynamic>.from(docCoopData['materiais_qtd'] ?? {});
      currentMateriaisQtd[material] = 0;
      await docCoopRef.update({'materiais_qtd': currentMateriaisQtd});
    }

    // Set partilha_realizada to true for the specific material
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    final coletasSnapshot = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('coletas_materiais')
        .where('partilha_realizada', isEqualTo: false)
        .where('material.material_name', isEqualTo: material)
        .get();

    for (final doc in coletasSnapshot.docs) {
      batch.update(doc.reference, {'partilha_realizada': true});
    }
    await batch.commit();

    await _carregarMateriaisQtd();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Partilha parcial realizada para "$material"!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materiais Separados'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Materiais Gerais',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Material')),
                    DataColumn(label: Text('Quantidade (kg)')),
                    DataColumn(label: Text('Partilha Parcial')),
                  ],
                  rows: materiaisGerais.entries.map((entry) {
                    return DataRow(cells: [
                      DataCell(Text(entry.key)),
                      DataCell(Text(entry.value.toString())),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.account_balance_wallet,
                              color: Colors.orange),
                          tooltip: 'Partilha parcial',
                          onPressed:
                              viewOnly ? null : () => _partilhaParcial(entry.key),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Materiais Individuais',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                DataTable(
                  columns: const [
                    DataColumn(label: Text('Material')),
                    DataColumn(label: Text('Quantidade (kg)')),
                    DataColumn(label: Text('Partilha Parcial')),
                  ],
                  rows: materiaisIndividuais.entries.map((entry) {
                    return DataRow(cells: [
                      DataCell(Text(entry.key)),
                      DataCell(Text(entry.value.toString())),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.account_balance_wallet,
                              color: Colors.orange),
                          tooltip: 'Partilha parcial',
                          onPressed:
                              viewOnly ? null : () => _partilhaParcial(entry.key),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ElevatedButton(
          onPressed: viewOnly
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmação'),
                      content: const Text(
                          'Tem certeza que deseja realizar a partilha total?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          child: const Text('Confirmar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Get materials data which includes prices
                    final doc = await FirebaseFirestore.instance
                        .collection('prefeituras')
                        .doc(prefeituraUid)
                        .collection('cooperativas')
                        .doc(cooperativaUid)
                        .get();
                    final Map<String, dynamic> materiais = doc.exists ? Map<String, dynamic>.from(doc.data()!['materiais'] ?? {}) : {};
                    
                    // Create cooperative's partilha document
                    await FirebaseFirestore.instance
                        .collection('prefeituras')
                        .doc(prefeituraUid)
                        .collection('cooperativas')
                        .doc(cooperativaUid)
                        .collection('partilhas')
                        .add({
                      'data': DateTime.now().toIso8601String(),
                      'parcial': false,
                      'materiais': materiais,
                      'materiais_qtd': Map<String, dynamic>.from(materiaisIndividuais),
                    });

                    // Reset cooperative's materiais_qtd
                    final resetMap = Map<String, dynamic>.from(
                        materiaisIndividuais.map((k, v) => MapEntry(k, 0)));
                    await FirebaseFirestore.instance
                        .collection('prefeituras')
                        .doc(prefeituraUid)
                        .collection('cooperativas')
                        .doc(cooperativaUid)
                        .update({'materiais_qtd': resetMap});
                    
                    // Process each cooperado
                    List<Map<String, dynamic>> cooperadosDataForPartilha = [];
                    final cooperadosSnapshot = await FirebaseFirestore
                        .instance
                        .collection('prefeituras')
                        .doc(prefeituraUid)
                        .collection('cooperativas')
                        .doc(cooperativaUid)
                        .collection('cooperados')
                        .get();
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

                      // Create cooperado's partilha document
                      await FirebaseFirestore.instance
                          .collection('prefeituras')
                          .doc(prefeituraUid)
                          .collection('cooperativas')
                          .doc(cooperativaUid)
                          .collection('cooperados')
                          .doc(cooperadoDoc.id)
                          .collection('partilhas')
                          .add({
                            'data': DateTime.now().toIso8601String(),
                            'parcial': false,
                            'materiais': materiais,
                            'materiais_qtd': materiaisQtdCooperado,
                          });

                      // Reset cooperado's materiais_qtd and valor_partilha
                      final resetCoopMap = Map<String, dynamic>.from(
                          materiaisQtdCooperado.map((k, v) => MapEntry(k, 0)));
                      await FirebaseFirestore.instance
                          .collection('prefeituras')
                          .doc(prefeituraUid)
                          .collection('cooperativas')
                          .doc(cooperativaUid)
                          .collection('cooperados')
                          .doc(cooperadoDoc.id)
                          .update({
                        'materiais_qtd': resetCoopMap,
                        'valor_partilha': 0
                      });
                    }

                    // Create the summary document in 'partilhas_realizadas'
                    await FirebaseFirestore.instance
                        .collection('prefeituras')
                        .doc(prefeituraUid)
                        .collection('cooperativas')
                        .doc(cooperativaUid)
                        .collection('partilhas_cooperados')
                        .add({
                          'timestamp': FieldValue.serverTimestamp(),
                          'cooperados': cooperadosDataForPartilha,
                        });

                    // Set partilha_realizada to true for all relevant coletas
                    final WriteBatch batch = FirebaseFirestore.instance.batch();
                    final coletasSnapshot = await FirebaseFirestore.instance
                        .collection('prefeituras')
                        .doc(prefeituraUid)
                        .collection('cooperativas')
                        .doc(cooperativaUid)
                        .collection('coletas_materiais')
                        .where('partilha_realizada', isEqualTo: false)
                        .get();

                    for (final doc in coletasSnapshot.docs) {
                      batch.update(doc.reference, {'partilha_realizada': true});
                    }
                    await batch.commit();

                    await _carregarMateriaisQtd(); // Recarrega os dados para atualizar a tabela
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Partilha total realizada e materiais resetados!')),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            minimumSize: const Size(250, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          child: const Text('Realizar partilha total',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}