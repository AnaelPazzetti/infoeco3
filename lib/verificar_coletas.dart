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
  Map<String, Map<String, dynamic>> materiais = {};

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
    await _carregarMateriais();
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

  Future<void> _carregarMateriais() async {
    if (prefeituraUid == null || cooperativaUid == null) {
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('materiais')) {
        setState(() {
          materiais = Map<String, Map<String, dynamic>>.from(data['materiais']);
        });
      }
    }
  }

  Future<void> _atualizarValorPartilha(String userUid) async {
    if (cooperativaUid == null || prefeituraUid == null) return;

    final docCooperado = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .doc(userUid)
        .get();

    if (docCooperado.exists && docCooperado.data() != null) {
      final materiaisQtd =
          Map<String, dynamic>.from(docCooperado['materiais_qtd'] ?? {});
      double novoValor = 0.0;
      materiaisQtd.forEach((material, qtd) {
        final preco = materiais[material]?['preco'] ?? 0.0;
        novoValor += (qtd as num) * preco;
      });

      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('cooperados')
          .doc(userUid)
          .update({'valor_partilha': novoValor});
    }
  }

  Future<void> _editarQuantidadeColeta(DocumentSnapshot coleta) async {
    final oldQty = (coleta['material'] as Map<String, dynamic>)['qtd'] as num;
    final materialName =
        (coleta['material'] as Map<String, dynamic>)['material_name'] as String;
    final userUid = coleta['user_uid'] as String;

    final newQtyController = TextEditingController(text: oldQty.toString());

    final newQty = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Quantidade'),
        content: TextField(
          controller: newQtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nova Quantidade'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(newQtyController.text);
              if (val != null) {
                Navigator.of(context).pop(val);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newQty != null && newQty != oldQty) {
      final difference = newQty - oldQty;

      final coletaRef = FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('coletas_materiais')
          .doc(coleta.id);

      final cooperadoRef = FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('cooperados')
          .doc(userUid);

      final cooperativaRef = FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final cooperadoDoc = await transaction.get(cooperadoRef);
        final cooperativaDoc = await transaction.get(cooperativaRef);

        if (cooperadoDoc.exists && cooperativaDoc.exists) {
          final oldMateriaisQtd = Map<String, dynamic>.from(
              cooperadoDoc.data()!['materiais_qtd'] ?? {});
          final currentQty =
              (oldMateriaisQtd[materialName] as num?)?.toDouble() ?? 0.0;
          final newCooperadoQty = currentQty + difference;

          oldMateriaisQtd[materialName] = newCooperadoQty;

          transaction.update(cooperadoRef, {'materiais_qtd': oldMateriaisQtd});

          final Map<String, dynamic> updateData = {
            'material.qtd': newQty,
            'alteradoAuditoria': true,
            'auditoriaData': FieldValue.serverTimestamp(),
            'valorPrevio': oldQty,
          };
          transaction.update(coletaRef, updateData);

          final partilha = materiais[materialName]?['partilha'];
          if (partilha == 'Individual') {
            final oldMateriaisQtdCooperativa = Map<String, dynamic>.from(
                cooperativaDoc.data()!['materiais_qtd'] ?? {});
            final currentQtyCooperativa =
                (oldMateriaisQtdCooperativa[materialName] as num?)?.toDouble() ??
                    0.0;
            final newCooperativaQty = currentQtyCooperativa + difference;
            oldMateriaisQtdCooperativa[materialName] = newCooperativaQty;
            transaction.update(cooperativaRef,
                {'materiais_qtd': oldMateriaisQtdCooperativa});
          } else if (partilha == 'Geral') {
            final oldMateriaisGQtdCooperativa = Map<String, dynamic>.from(
                cooperativaDoc.data()!['materiaisG_qtd'] ?? {});
            final currentQtyGCooperativa =
                (oldMateriaisGQtdCooperativa[materialName] as num?)?.toDouble() ??
                    0.0;
            final newCooperativaGQtd = currentQtyGCooperativa + difference;
            oldMateriaisGQtdCooperativa[materialName] = newCooperativaGQtd;
            transaction.update(cooperativaRef,
                {'materiaisG_qtd': oldMateriaisGQtdCooperativa});
          }
        }
      });

      await _atualizarValorPartilha(userUid);
    }
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
                  return const Center(
                      child: Text('Nenhuma coleta encontrada.'));
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
                      DataColumn(label: Text('Ações')),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final materialData = data.containsKey('material') &&
                              data['material'] is Map
                          ? data['material'] as Map<String, dynamic>
                          : {};
                      final timestamp = data['data'] as Timestamp?;
                      final date = timestamp?.toDate();
                      final formattedDate = date != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(date)
                          : '-';
                      final userUid = data['user_uid']?.toString() ?? 'N/A';
                      final userName = _cooperados[userUid] ?? userUid;

                      return DataRow(
                        cells: [
                          DataCell(Text(userName)),
                          DataCell(Text(
                              materialData['material_name']?.toString() ?? 'N/A')),
                          DataCell(
                              Text(materialData['qtd']?.toString() ?? 'N/A')),
                          DataCell(Text(formattedDate)),
                          DataCell(Text(
                              data['partilha_realizada']?.toString() ?? 'false')),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editarQuantidadeColeta(doc),
                            ),
                          ),
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
      query =
          query.where('partilha_realizada', isEqualTo: _partilhaFilter == 'true');
    }

    if (_limit != -1) {
      query = query.limit(_limit);
    }

    return query.snapshots();
  }
}
