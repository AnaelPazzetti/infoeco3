// Este arquivo implementa a tela de verificação das cooperativas para prefeituras.
// Exibe uma tabela listando todas as cooperativas vinculadas à prefeitura autenticada.
// Permite aprovar cooperativas (campo 'aprovacao_prefeitura' em true).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerificarCooperativas extends StatefulWidget {
  const VerificarCooperativas({super.key});

  @override
  State<VerificarCooperativas> createState() => _VerificarCooperativasState();
}

class _VerificarCooperativasState extends State<VerificarCooperativas> {
  String? prefeituraUid;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _carregarPrefeituraUid();
  }

  // Carrega o UID da prefeitura autenticada
  Future<void> _carregarPrefeituraUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        prefeituraUid = user.uid;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Cooperativas vinculadas'),
      ),
      body: prefeituraUid == null
          ? const Center(child: Text('Usuário não autenticado.'))
          : Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 800,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: prefeituraUid == null
                              ? null
                              : FirebaseFirestore.instance
                                  .collection('prefeituras')
                                  .doc(prefeituraUid)
                                  .collection('cooperativas')
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(child: Text('Nenhuma cooperativa vinculada.'));
                            }
                            return DataTable(
                              columns: const [
                                DataColumn(label: Text('NOME')),
                                DataColumn(label: Text('CNPJ')),
                                DataColumn(label: Text('APROVAR')),
                              ],
                              rows: docs.map((doc) {
                                final aprovado = (doc.data() as Map<String, dynamic>)['aprovacao_prefeitura'] == true;
                                return DataRow(cells: [
                                  DataCell(Text(doc['nome'] ?? '-')),
                                  DataCell(Text(doc['cnpj'] ?? '-')),
                                  DataCell(
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        aprovado
                                            ? const Icon(Icons.check, color: Colors.green)
                                            : ElevatedButton(
                                                onPressed: () async {
                                                  await FirebaseFirestore.instance
                                                      .collection('prefeituras')
                                                      .doc(prefeituraUid)
                                                      .collection('cooperativas')
                                                      .doc(doc.id)
                                                      .update({'aprovacao_prefeitura': true});
                                                  // Também atualiza o campo de aprovação no registro do usuário cooperativa
                                                  await FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(doc.id)
                                                      .update({'isAprovado': true});
                                                  setState(() {});
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  minimumSize: const Size(36, 36),
                                                  padding: EdgeInsets.zero,
                                                  shape: const CircleBorder(),
                                                ),
                                                child: const Icon(Icons.check, color: Colors.white, size: 18),
                                              ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
