import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/xlsx_exporter.dart';

class VerificarPartilhas extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;

  const VerificarPartilhas({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});

  @override
  State<VerificarPartilhas> createState() => _VerificarPartilhasState();
}

class _VerificarPartilhasState extends State<VerificarPartilhas> {
  final UserProfileService _userProfileService = UserProfileService();
  List<QueryDocumentSnapshot> _docs = [];
  String? cooperativaUid;
  String? prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  bool loading = true;
  final TextEditingController _searchController = TextEditingController();

  // New state variables for history
  List<QueryDocumentSnapshot> _partilhasDocs = [];
  QueryDocumentSnapshot? _selectedPartilha;
  bool _isHistoryLoading = true;

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarCooperativaUid().then((_) {
      _carregarHistoricoPartilhas();
    });
  }

  Future<void> _carregarCooperativaUid() async {
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
    setState(() {
      loading = false;
    });
  }

  Future<void> _carregarHistoricoPartilhas() async {
    if (cooperativaUid == null || prefeituraUid == null) return;
    setState(() {
      _isHistoryLoading = true;
    });
    final partilhasSnap = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('partilhas_cooperados')
        .orderBy('timestamp', descending: true)
        .get();
    setState(() {
      _partilhasDocs = partilhasSnap.docs;
      _isHistoryLoading = false;
    });
  }

  String _formatarData(dynamic data) {
    if (data == null) return 'Sem data';
    try {
      DateTime dt;
      if (data is Timestamp) {
        dt = data.toDate();
      } else if (data is String) {
        dt = DateTime.parse(data);
      } else if (data is DateTime) {
        dt = data;
      } else {
        return data.toString();
      }
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return data.toString();
    }
  }

  void _showMaterialDetailsDialog(BuildContext context, Map<String, dynamic> materiais) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detalhes dos Materiais'),
          content: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Material')),
                DataColumn(label: Text('Quantidade')),
              ],
              rows: materiais.entries.map((entry) {
                return DataRow(cells: [
                  DataCell(Text(entry.key)),
                  DataCell(Text(entry.value.toString())),
                ]);
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Partilhas dos Cooperados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              final headers = ['NOME', 'VALOR DA PARTILHA'];
              final rows = _docs.map((doc) {
                final nome = doc['nome'] ?? '';
                final valorPartilha = doc['valor_partilha'] ?? '0';
                return [nome, valorPartilha];
              }).toList();

              XlsxExporter.exportData(
                context,
                headers: headers,
                rows: rows.map((row) => row.map((e) => e.toString()).toList()).toList(),
                fileName: 'partilhas_cooperados',
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Partilha Atual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar por nome',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (cooperativaUid == null)
                    const Center(child: Text('Cooperativa não encontrada.'))
                  else
                    StreamBuilder<QuerySnapshot>(
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
                        List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];
                        String search = _searchController.text.trim();

                        if (search.isNotEmpty) {
                          docs = docs.where((doc) {
                            final nome = (doc['nome'] ?? '').toString().toLowerCase();
                            return nome.contains(search.toLowerCase());
                          }).toList();
                        }

                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Nenhum cooperado encontrado.'),
                          );
                        }
                        
                        _docs = docs;

                        return Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 600),
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('NOME', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('VALOR DA PARTILHA', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('DETALHES', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: [
                                  for (var doc in _docs)
                                    DataRow(cells: [
                                      DataCell(Text(doc['nome'] ?? '', style: const TextStyle(fontSize: 16))),
                                      DataCell(Text('R\$ ${doc['valor_partilha'] ?? '0'}', style: const TextStyle(fontSize: 16))),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.more_horiz),
                                          onPressed: () {
                                            final materiais = doc['materiais_qtd'] as Map<String, dynamic>?;
                                            if (materiais != null && materiais.isNotEmpty) {
                                              _showMaterialDetailsDialog(context, materiais);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Nenhum material encontrado para este cooperado.')),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ]),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('Histórico de Partilhas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 16),
                    if (_isHistoryLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_partilhasDocs.isEmpty)
                      const Center(child: Text('Nenhum histórico de partilha encontrado.'))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Selecionar data: ', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 200,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: DropdownButton<QueryDocumentSnapshot>(
                                value: _selectedPartilha,
                                hint: const Text('Selecione uma data'),
                                underline: const SizedBox(),
                                items: _partilhasDocs.map((doc) {
                                  return DropdownMenuItem<QueryDocumentSnapshot>(
                                    value: doc,
                                    child: Text(_formatarData(doc['timestamp'])),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPartilha = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_selectedPartilha != null)
                      Builder(
                        builder: (context) {
                          final data = _selectedPartilha!.data() as Map<String, dynamic>;
                          final cooperados = List<Map<String, dynamic>>.from(data['cooperados'] ?? []);
                          if (cooperados.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Nenhum dado de cooperado para esta partilha.'),
                            );
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 600),
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('NOME', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('VALOR RECEBIDO', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('DETALHES', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: [
                                  for (var cooperado in cooperados)
                                    DataRow(cells: [
                                      DataCell(Text(cooperado['cooperado_nome'] ?? '', style: const TextStyle(fontSize: 16))),
                                      DataCell(Text('R\$ ${cooperado['valor_recebido']?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 16))),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.more_horiz),
                                          onPressed: () {
                                            final materiais = cooperado['materiais_entregues'] as Map<String, dynamic>?;
                                            if (materiais != null && materiais.isNotEmpty) {
                                              _showMaterialDetailsDialog(context, materiais);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Nenhum material encontrado para este cooperado.')),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ]),
                                ],
                              ),
                            ),
                          );
                        }
                      )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
