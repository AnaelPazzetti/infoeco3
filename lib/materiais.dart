// Tela onde o cooperado registra os materiais coletados

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'materiais4.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis
import 'user_profile_service.dart'; // Importa o serviço de perfil de usuário

class Materiais extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const Materiais({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});
  @override
  State<Materiais> createState() => _MateriaisState();
}

class _MateriaisState extends State<Materiais> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? _prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  Map<String, Map<String, dynamic>> materiais = {};
  List<MaterialRow> materiaisRows = [];
  bool isLoading = true;
  double valorPartilha = 0.0; // Valor total da partilha do cooperado

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    _prefeituraUid = widget.prefeituraUid;
    _carregarMateriais();
    _carregarValorPartilha();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carregarValorPartilha();
  }

  Future<void> _carregarMateriais() async {
    if (cooperativaUid != null && _prefeituraUid != null) {
      // ...existing code...
    } else {
      final profile = await _userProfileService.getUserProfileInfo();
      if (profile.role == UserRole.cooperado || profile.role == UserRole.cooperativa) {
        cooperativaUid = profile.cooperativaUid;
        _prefeituraUid = profile.prefeituraUid;
      }
    }
    if (_prefeituraUid == null || cooperativaUid == null) {
      setState(() => isLoading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('materiais')) {
        materiais = Map<String, Map<String, dynamic>>.from(data['materiais']);
        if (materiais.isNotEmpty) {
          materiaisRows = [MaterialRow(nome: materiais.keys.first, quantidade: 0)];
        }
      }
    }
    setState(() => isLoading = false);
    await _carregarValorPartilha();
  }

  Future<void> _carregarValorPartilha() async {
    final user = FirebaseAuth.instance.currentUser;
    if (cooperativaUid == null || _prefeituraUid == null || user == null) return;

    final docCooperado = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .doc(user.uid)
        .get();

    if (docCooperado.exists && docCooperado.data() != null) {
      setState(() {
        valorPartilha = (docCooperado['valor_partilha'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  Future<void> _atualizarValorPartilha() async {
    final user = FirebaseAuth.instance.currentUser;
    if (cooperativaUid == null || _prefeituraUid == null || user == null) return;

    final docCooperado = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .doc(user.uid)
        .get();

    if (docCooperado.exists && docCooperado.data() != null) {
      final materiaisQtd = Map<String, dynamic>.from(docCooperado['materiais_qtd'] ?? {});
      double novoValor = 0.0;
      materiaisQtd.forEach((material, qtd) {
        final preco = materiais[material]?['preco'] ?? 0.0;
        novoValor += (qtd as num) * preco;
      });

      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(_prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .collection('cooperados')
          .doc(user.uid)
          .update({'valor_partilha': novoValor});

      setState(() {
        valorPartilha = novoValor;
      });
    }
  }

  double _calcularValor(String nome, double quantidade) {
    return (materiais[nome]?['preco'] ?? 0) * quantidade;
  }

  Future<void> _enviarDadosMaterial(int rowIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (cooperativaUid == null || _prefeituraUid == null || user == null) return;

    final materialNome = materiaisRows[rowIndex].nome;
    final quantidade = materiaisRows[rowIndex].quantidade;
    final partilha = materiais[materialNome]?['partilha'];

    if (quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida!')),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final cooperadoRef = firestore
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .doc(user.uid);

    final cooperativaRef = firestore
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid);

    if (partilha == 'Individual') {
      await firestore.runTransaction((transaction) async {
        final cooperadoDoc = await transaction.get(cooperadoRef);
        final cooperativaDoc = await transaction.get(cooperativaRef);

        final materiaisQtdCooperado = Map<String, dynamic>.from(cooperadoDoc.data()?['materiais_qtd'] ?? {});
        materiaisQtdCooperado[materialNome] = (materiaisQtdCooperado[materialNome] ?? 0) + quantidade;

        final materiaisQtdCooperativa = Map<String, dynamic>.from(cooperativaDoc.data()?['materiais_qtd'] ?? {});
        materiaisQtdCooperativa[materialNome] = (materiaisQtdCooperativa[materialNome] ?? 0) + quantidade;

        transaction.update(cooperadoRef, {'materiais_qtd': materiaisQtdCooperado});
        transaction.update(cooperativaRef, {'materiais_qtd': materiaisQtdCooperativa});
      });
    } else if (partilha == 'Geral') {
      await firestore.runTransaction((transaction) async {
        final cooperativaDoc = await transaction.get(cooperativaRef);

        final materiaisQtdGeral = Map<String, dynamic>.from(cooperativaDoc.data()?['materiaisG_qtd'] ?? {});
        materiaisQtdGeral[materialNome] = (materiaisQtdGeral[materialNome] ?? 0) + quantidade;

        transaction.update(cooperativaRef, {'materiaisG_qtd': materiaisQtdGeral});
      });
    }

    await _atualizarValorPartilha();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material enviado com sucesso!')),
    );
    setState(() {
      materiaisRows[rowIndex].quantidade = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Materiais')),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Valor/kg', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Quantidade', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Enviar', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      for (int i = 0; i < materiaisRows.length; i++)
                        DataRow(cells: [
                          DataCell(
                            Row(
                              children: [
                                Flexible(
                                  child: DropdownButton<String>(
                                    value: materiaisRows[i].nome,
                                    isExpanded: true,
                                    items: materiais.keys.map((nome) {
                                      return DropdownMenuItem(
                                        value: nome,
                                        child: Tooltip(
                                          message: nome,
                                          child: Text(
                                            nome,
                                            overflow: TextOverflow.visible,
                                            softWrap: false,
                                            maxLines: 1,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    selectedItemBuilder: (context) {
                                      return materiais.keys.map((nome) {
                                        return Tooltip(
                                          message: nome,
                                          child: Text(
                                            nome,
                                            overflow: TextOverflow.visible,
                                            softWrap: false,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList();
                                    },
                                    onChanged: viewOnly
                                        ? null
                                        : (value) {
                                            if (value != null) {
                                              setState(() {
                                                materiaisRows[i].nome = value;
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text((materiais[materiaisRows[i].nome]?['preco'] ?? 0).toStringAsFixed(2))),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: materiaisRows[i].quantidade == 0 ? '' : materiaisRows[i].quantidade.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: viewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          materiaisRows[i].quantidade = double.tryParse(value) ?? 0;
                                        });
                                      },
                                enabled: !viewOnly,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(_calcularValor(materiaisRows[i].nome, materiaisRows[i].quantidade).toStringAsFixed(2))),
                          DataCell(
                            ElevatedButton(
                              onPressed: viewOnly ? null : () => _enviarDadosMaterial(i),
                              child: const Text('Enviar'),
                            ),
                          ),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Materiais4()),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Conferir materiais coletados'),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.green[100],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Text(
                        'Valor aproximado da partilha: R\$ ${valorPartilha.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MaterialRow {
  String nome;
  double quantidade;
  MaterialRow({required this.nome, required this.quantidade});
}