// Este arquivo implementa a funcionalidade de exibição de materiais separados
// por cooperativas. Ele exibe uma tabela com os materiais e suas quantidades.


//TODO: BUG WHEN A MATERIAL_PRECO IS CHANGED, COOPERADO.VALOR.PARTILHA IS NOT UPDATED CAUSING INCONSISTENCIES
// On change of materiais_preco, recalculate valor_partilha for all cooperados;


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
  Map<String, dynamic> materiaisQtd = {};
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
    if (doc.exists && doc.data()!.containsKey('materiais_qtd')) {
      materiaisQtd = Map<String, dynamic>.from(doc['materiais_qtd']);
    }
    setState(() => isLoading = false);
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
    // Busca todos os cooperados da cooperativa
    final cooperadosSnapshot = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .get();
    // Busca o preço do material
    final docCoop = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .get();
    final materiaisPreco = docCoop.data()?['materiais_preco'] ?? {};
    final precoMaterial = (materiaisPreco[material] ?? 0).toDouble();
    // Monta o snapshot parcial de materiais_qtd
    final Map<String, dynamic> materiaisQtdParcial = { material: materiaisQtd[material] };
    // Cria documento em 'partilhas' da cooperativa (parcial)
    await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('partilhas')
        .add({
          'materiais_qtd': materiaisQtdParcial,
          'materiais_preco': { material: precoMaterial },
          'data': DateTime.now().toIso8601String(),
          'parcial': true,
        });
    // Para cada cooperado, subtrai valor_partilha do material, zera o material em materiais_qtd e cria doc em partilhas
    for (final doc in cooperadosSnapshot.docs) {
      final data = doc.data();
      Map<String, dynamic> materiaisQtdCoop = {};
      if (data.containsKey('materiais_qtd')) {
        materiaisQtdCoop = Map<String, dynamic>.from(data['materiais_qtd']);
      }
      final qtdMaterial = (materiaisQtdCoop[material] ?? 0) as num;
      // Zera o material para o cooperado
      materiaisQtdCoop[material] = 0; 
      // Cria documento em 'partilhas' do cooperado (parcial)
      final valorPartilhaDoc = precoMaterial * qtdMaterial;
      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('cooperados')
          .doc(doc.id)
          .collection('partilhas')
          .add({
            'materiais_qtd': { material: qtdMaterial },
            'materiais_preco': { material: precoMaterial },
            'data': DateTime.now().toIso8601String(),
            'valor_partilha': valorPartilhaDoc,
            'parcial': true,
          });
      // Atualiza valor_partilha decrementando pelo valorPartilhaDoc
      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('cooperados')
          .doc(doc.id)
          .update({
            'valor_partilha': FieldValue.increment(-valorPartilhaDoc),
            'materiais_qtd': materiaisQtdCoop
          });
    }
    // Zera o material também no map materiais_qtd da cooperativa
    final docCoopAtual = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .get();
    Map<String, dynamic> materiaisQtdCoop = {};
    if (docCoopAtual.exists && docCoopAtual.data() != null && docCoopAtual.data()!.containsKey('materiais_qtd')) {
      materiaisQtdCoop = Map<String, dynamic>.from(docCoopAtual['materiais_qtd']);
      materiaisQtdCoop[material] = 0;
      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .update({'materiais_qtd': materiaisQtdCoop});
    }
    // Zera o material também para o usuário autenticado (caso seja cooperado)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docCooperado = await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('cooperados')
          .doc(user.uid)
          .get();
      if (docCooperado.exists && docCooperado.data() != null && docCooperado.data()!.containsKey('materiais_qtd')) {
        Map<String, dynamic> materiaisQtdUser = Map<String, dynamic>.from(docCooperado['materiais_qtd']);
        materiaisQtdUser[material] = 0;
        await FirebaseFirestore.instance
            .collection('prefeituras')
            .doc(prefeituraUid)
            .collection('cooperativas')
            .doc(cooperativaUid)
            .collection('cooperados')
            .doc(user.uid)
            .update({'materiais_qtd': materiaisQtdUser});
      }
    }
    setState(() => isLoading = false);
    await _carregarMateriaisQtd(); // Recarrega os dados para atualizar a tabela
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
      appBar: AppBar(title: const Text('Materiais 3')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth * 0.8;
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tableWidth),
                      child: Table(
                        columnWidths: const <int, TableColumnWidth>{
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(1.5),
                        },
                        border: TableBorder.all(color: Colors.black),
                        children: [
                          TableRow(children: [
                            celulaHeader('Material'),
                            celulaHeader('Quantidade (kg)'),
                            celulaHeader('Partilha Parcial'),
                          ]),
                          for (final entry in materiaisQtd.entries)
                            TableRow(children: [
                              celula(entry.key),
                              celula(entry.value.toString()),
                              Center(
                                child: IconButton(
                                  icon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                                  tooltip: 'Partilha parcial',
                                  onPressed: viewOnly ? null : () async {
                                    await _partilhaParcial(entry.key);
                                  },
                                ),
                              ),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ElevatedButton(
          onPressed: viewOnly ? null : () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirmação'),
                content: const Text('Tem certeza que deseja realizar a partilha total?'),
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
            if (confirm == true) {
              // Busca materiais_preco
              final doc = await FirebaseFirestore.instance
                  .collection('prefeituras')
                  .doc(prefeituraUid)
                  .collection('cooperativas')
                  .doc(cooperativaUid)
                  .get();
              Map<String, dynamic> materiaisPreco = {};
              if (doc.exists && doc.data() != null && doc.data()!.containsKey('materiais_preco')) {
                materiaisPreco = Map<String, dynamic>.from(doc['materiais_preco']);
              }
              // Cria documento em 'partilhas' da cooperativa
              await FirebaseFirestore.instance
                  .collection('prefeituras')
                  .doc(prefeituraUid)
                  .collection('cooperativas')
                  .doc(cooperativaUid)
                  .collection('partilhas')
                  .add({
                    'materiais_qtd': Map<String, dynamic>.from(materiaisQtd),
                    'materiais_preco': materiaisPreco,
                    'data': DateTime.now().toIso8601String(),
                  });
              // Reseta materiais_qtd da cooperativa para 0
              final resetMap = Map<String, dynamic>.from(materiaisQtd.map((k, v) => MapEntry(k, 0)));
              await FirebaseFirestore.instance
                  .collection('prefeituras')
                  .doc(prefeituraUid)
                  .collection('cooperativas')
                  .doc(cooperativaUid)
                  .update({'materiais_qtd': resetMap});
              // Para cada cooperado, reseta materiais_qtd e salva em subcoleção 'partilhas'
              final cooperadosSnapshot = await FirebaseFirestore.instance
                  .collection('prefeituras')
                  .doc(prefeituraUid)
                  .collection('cooperativas')
                  .doc(cooperativaUid)
                  .collection('cooperados')
                  .get();
              for (final cooperadoDoc in cooperadosSnapshot.docs) {
                final cooperadoData = cooperadoDoc.data();
                final materiaisQtdCooperado = Map<String, dynamic>.from(cooperadoData['materiais_qtd'] ?? {});
                // Usa o valor da partilha já calculado e armazenado no documento do cooperado.
                // Isso garante consistência, mesmo que os preços dos materiais tenham mudado.
                final double valorPartilhaExistente = (cooperadoData['valor_partilha'] as num? ?? 0.0).toDouble();

                // Cria documento em 'partilhas' do cooperado
                final partilhaRef = await FirebaseFirestore.instance
                    .collection('prefeituras')
                    .doc(prefeituraUid)
                    .collection('cooperativas')
                    .doc(cooperativaUid)
                    .collection('cooperados')
                    .doc(cooperadoDoc.id)
                    .collection('partilhas')
                    .add({
                      'materiais_qtd': materiaisQtdCooperado,
                      'materiais_preco': materiaisPreco,
                      'data': DateTime.now().toIso8601String(),
                      'valor_partilha': valorPartilhaExistente,
                    });
                // Salva o UID da partilha da cooperativa no documento do cooperado
                await partilhaRef.update({
                  'cooperativa_partilha_uid': partilhaRef.id,
                });
                // Reseta materiais_qtd e valor_partilha do cooperado para 0
                final resetCoopMap = Map<String, dynamic>.from(materiaisQtdCooperado.map((k, v) => MapEntry(k, 0)));
                await FirebaseFirestore.instance
                    .collection('prefeituras')
                    .doc(prefeituraUid)
                    .collection('cooperativas')
                    .doc(cooperativaUid)
                    .collection('cooperados')
                    .doc(cooperadoDoc.id)
                    .update({'materiais_qtd': resetCoopMap, 'valor_partilha': 0});
              }
              setState(() {
                materiaisQtd = resetMap;
                isLoading = false;
              });
              await _carregarMateriaisQtd(); // Recarrega os dados para atualizar a tabela
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partilha total realizada e materiais resetados!')),
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
          child: const Text('Realizar partilha total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
