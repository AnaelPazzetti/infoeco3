
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

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarCooperativaUid();
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
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
                    child: Text('Partilhas Registradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome',
                        border: OutlineInputBorder(),
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
                                ],
                                rows: [
                                  for (var doc in _docs)
                                    DataRow(cells: [
                                      DataCell(Text(doc['nome'] ?? '', style: const TextStyle(fontSize: 16))),
                                      DataCell(Text('R\$ ${doc['valor_partilha'] ?? '0'}', style: const TextStyle(fontSize: 16))),
                                    ]),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
