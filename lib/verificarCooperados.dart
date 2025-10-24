// Este arquivo implementa a tela de verificação dos cooperados para cooperativas.
// Exibe uma tabela semelhante à de presenças, listando todos os cooperados vinculados à cooperativa autenticada.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:flutter/material.dart';

class VerificarCooperados extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const VerificarCooperados({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});

  @override
  State<VerificarCooperados> createState() => _VerificarCooperadosState();
}

class _VerificarCooperadosState extends State<VerificarCooperados> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    if (cooperativaUid == null || prefeituraUid == null) {
      _carregarCooperativaUid();
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  // Carrega o UID da cooperativa autenticada
  Future<void> _carregarCooperativaUid() async {
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
    setState(() {
      loading = false;
    });
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
        title: const Text('Cooperados vinculados'),
      ),
      body: cooperativaUid == null
          ? const Center(child: Text('Usuário não autenticado.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final double tableWidth = constraints.maxWidth * 0.95;
                return Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('prefeituras')
                              .doc(prefeituraUid)
                              .collection('cooperativas')
                              .doc(cooperativaUid)
                              .collection('cooperados')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(child: Text('Nenhum cooperado cadastrado.'));
                            }
                            return DataTable(
                              columns: const [
                                DataColumn(label: Text('NOME')),
                                DataColumn(label: Text('CPF')),
                                DataColumn(label: Text('APROVAR')),
                              ],
                              rows: docs.map((doc) {
                                final aprovado = doc['aprovacao_cooperativa'] == true;
                                return DataRow(cells: [
                                  DataCell(Text(doc['nome'] ?? '-')),
                                  DataCell(Text(doc['cpf'] ?? '-')),
                                  DataCell(
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        aprovado
                                            ? const Icon(Icons.check, color: Colors.green)
                                            : ElevatedButton(
                                                onPressed: viewOnly
                                                    ? null
                                                    : () async {
                                                        // Aprova no subdocumento do cooperado
                                                        await FirebaseFirestore.instance
                                                            .collection('prefeituras')
                                                            .doc(prefeituraUid)
                                                            .collection('cooperativas')
                                                            .doc(cooperativaUid)
                                                            .collection('cooperados')
                                                            .doc(doc.id)
                                                            .update({'aprovacao_cooperativa': true});
                                                        // Também atualiza o campo isAprovado no registro do usuário
                                                        await FirebaseFirestore.instance
                                                            .collection('users')
                                                            .doc(doc.id)
                                                            .update({'isAprovado': true});
                                                        setState(() {});
                                                      },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange,
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
                );
              },
            ),
    );
  }
}
