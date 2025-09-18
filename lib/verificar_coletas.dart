import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:intl/intl.dart';

class VerificarColetas extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;

  const VerificarColetas({super.key, this.cooperativaUid, this.prefeituraUid});

  @override
  State<VerificarColetas> createState() => _VerificarColetasState();
}

class _VerificarColetasState extends State<VerificarColetas> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  bool loading = true;
  int _limit = 10;
  String _partilhaFilter = 'any'; // any, true, false
  Map<String, String> _cooperados = {};

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (widget.cooperativaUid == null || widget.prefeituraUid == null) {
      final profile = await _userProfileService.getUserProfileInfo();
      setState(() {
        cooperativaUid = profile.cooperativaUid;
        prefeituraUid = profile.prefeituraUid;
      });
    }
    await _loadCooperados();
    setState(() {
      loading = false;
    });
  }

  Future<void> _loadCooperados() async {
    if (prefeituraUid == null || cooperativaUid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .get();

    final cooperados = <String, String>{};
    for (var doc in snapshot.docs) {
      cooperados[doc.id] = doc.data()['nome'] ?? 'Nome não encontrado';
    }
    setState(() {
      _cooperados = cooperados;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coletas de Materiais'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<int>(
                  value: _limit,
                  items: [10, 25, 50, 100, -1].map((limit) {
                    return DropdownMenuItem<int>(
                      value: limit,
                      child: Text(limit == -1 ? 'Todos' : limit.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _limit = value;
                      });
                    }
                  },
                ),
                DropdownButton<String>(
                  value: _partilhaFilter,
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('Qualquer')),
                    DropdownMenuItem(value: 'true', child: Text('Realizada')),
                    DropdownMenuItem(value: 'false', child: Text('Não Realizada')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _partilhaFilter = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getColetasStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhuma coleta encontrada.'));
                }

                var docs = snapshot.data!.docs;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Usuário')),
                      DataColumn(label: Text('Material')),
                      DataColumn(label: Text('Quantidade')),                     
                      DataColumn(label: Text('Data')),
                      DataColumn(label: Text('Partilha Realizada')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final materialData = data.containsKey('material') && data['material'] is Map ? data['material'] as Map<String, dynamic> : {};
                      final timestamp = data['data'] as Timestamp?;
                      final date = timestamp?.toDate();
                      final formattedDate = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '-';            
                      final userUid = data['user_uid']?.toString() ?? 'N/A';
                      final userName = _cooperados[userUid] ?? userUid;

                      return DataRow(
                        cells: [
                          DataCell(Text(userName)),
                          DataCell(Text(materialData['material_name']?.toString() ?? 'N/A')),
                          DataCell(Text(materialData['qtd']?.toString() ?? 'N/A')), 
                          DataCell(Text(formattedDate)),
                          DataCell(Text(data['partilha_realizada']?.toString() ?? 'false')),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getColetasStream() {
    Query query = FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('coletas_materiais')
        .orderBy('data', descending: true);

    if (_partilhaFilter != 'any') {
      query = query.where('partilha_realizada', isEqualTo: _partilhaFilter == 'true');
    }

    if (_limit != -1) {
      query = query.limit(_limit);
    }

    return query.snapshots();
  }
}