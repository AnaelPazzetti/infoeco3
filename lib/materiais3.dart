// Este arquivo implementa a funcionalidade de exibição de materiais separados
// por cooperativas. Ele exibe uma tabela com os materiais e suas quantidades.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/partilha_service.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/dialogs.dart';

class Materiais3 extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const Materiais3(
      {super.key,
      this.cooperativaUid,
      this.prefeituraUid,
      this.viewOnly = false});

  @override
  _Materiais3State createState() => _Materiais3State();
}

class _Materiais3State extends State<Materiais3> {
  final UserProfileService _userProfileService = UserProfileService();
  final PartilhaService _partilhaService = PartilhaService();
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
    if (cooperativaUid == null || prefeituraUid == null) return;

    final confirm = await showConfirmationDialog(
      context: context,
      title: 'Confirmação',
      content:
          'Tem certeza que deseja realizar a partilha parcial de "$material"?',
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      await _partilhaService.realizarPartilhaParcial(
        prefeituraUid: prefeituraUid!,
        cooperativaUid: cooperativaUid!,
        material: material,
        materiaisGerais: materiaisGerais,
        materiaisIndividuais: materiaisIndividuais,
      );
      await _carregarMateriaisQtd();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partilha parcial realizada para "$material"!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao realizar partilha parcial: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _partilhaTotal() async {
    if (cooperativaUid == null || prefeituraUid == null) return;

    final confirm = await showConfirmationDialog(
      context: context,
      title: 'Confirmação',
      content: 'Tem certeza que deseja realizar a partilha total?',
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      await _partilhaService.realizarPartilhaTotal(
        prefeituraUid: prefeituraUid!,
        cooperativaUid: cooperativaUid!,
        materiaisIndividuais: materiaisIndividuais,
      );
      await _carregarMateriaisQtd();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Partilha total realizada e materiais resetados!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao realizar partilha total: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
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
                          onPressed: viewOnly
                              ? null
                              : () => _partilhaParcial(entry.key),
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
                          onPressed: viewOnly
                              ? null
                              : () => _partilhaParcial(entry.key),
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
          onPressed: viewOnly ? null : _partilhaTotal,
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