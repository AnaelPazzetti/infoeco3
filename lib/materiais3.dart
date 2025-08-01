// Este arquivo implementa a funcionalidade de exibição de materiais separados
// por cooperativas. Ele exibe uma tabela com os materiais e suas quantidades 
//e permite a realizacao de partilhas.

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
  Map<String, dynamic> materiaisGQtd = {};
  Map<String, Map<String, dynamic>> materiais = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarMateriais();
  }

  Future<void> _carregarMateriais() async {
    if (widget.cooperativaUid != null && widget.prefeituraUid != null) {
      cooperativaUid = widget.cooperativaUid;
      prefeituraUid = widget.prefeituraUid;
    } else {
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
      if (data.containsKey('materiais')) {
        materiais = Map<String, Map<String, dynamic>>.from(data['materiais']);
      }
      if (data.containsKey('materiais_qtd')) {
        materiaisQtd = Map<String, dynamic>.from(data['materiais_qtd']);
      }
      if (data.containsKey('materiaisG_qtd')) {
        materiaisGQtd = Map<String, dynamic>.from(data['materiaisG_qtd']);
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _partilhaParcial(String material) async {
    // ... (implementação da partilha parcial precisa ser revista com a nova estrutura)
  }

  Future<void> _partilhaTotal() async {
    // ... (implementação da partilha total precisa ser revista com a nova estrutura)
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Materiais Separados')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth * 0.8;
          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Materiais Individuais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: tableWidth),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Quantidade (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Partilha Parcial', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: [
                            for (final entry in materiaisQtd.entries)
                              DataRow(cells: [
                                DataCell(Text(entry.key, style: const TextStyle(fontSize: 16))),
                                DataCell(Text(entry.value.toString(), style: const TextStyle(fontSize: 16))),
                                DataCell(Center(
                                  child: IconButton(
                                    icon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                                    tooltip: 'Partilha parcial',
                                    onPressed: viewOnly ? null : () async {
                                      await _partilhaParcial(entry.key);
                                    },
                                  ),
                                )),
                              ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Materiais Gerais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: tableWidth),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Quantidade (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: [
                            for (final entry in materiaisGQtd.entries)
                              DataRow(cells: [
                                DataCell(Text(entry.key, style: const TextStyle(fontSize: 16))),
                                DataCell(Text(entry.value.toString(), style: const TextStyle(fontSize: 16))),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  ),
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
              await _partilhaTotal();
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