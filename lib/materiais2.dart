// Tela para cooperativa gerenciar a lista de materiais e valores
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis
import 'package:infoeco3/xlsx_exporter.dart';

class Materiais2Screen extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const Materiais2Screen({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});

  @override
  State<Materiais2Screen> createState() => _Materiais2ScreenState();
}

class _Materiais2ScreenState extends State<Materiais2Screen> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  Map<String, Map<String, dynamic>> materiais = {};
  bool isLoading = true;
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  String? _tipoPartilha;

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarMateriais();
  }

  Future<void> _exportMateriaisCsv() async {
    List<String> headers = ['Material', 'Valor/kg', 'Tipo de Partilha'];
    List<List<String>> rows = [];

    materiais.forEach((nome, dados) {
      rows.add([
        nome,
        dados['preco'].toStringAsFixed(2),
        dados['partilha'],
      ]);
    });

    await XlsxExporter.exportData(
      context,
      headers: headers,
      rows: rows,
      fileName: 'materiais_cooperativa',
    );
  }

  // Carrega os materiais e preços da cooperativa logada
  Future<void> _carregarMateriais() async {
    final profile = await _userProfileService.getUserProfileInfo();
    DocumentSnapshot<Map<String, dynamic>>? doc;

    if (profile.role == UserRole.cooperativa) {
      cooperativaUid = profile.cooperativaUid;
      prefeituraUid = profile.prefeituraUid;
      doc = await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(profile.prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .get();
    } else if (widget.cooperativaUid != null && widget.prefeituraUid != null) {
      cooperativaUid = widget.cooperativaUid;
      prefeituraUid = widget.prefeituraUid;
      doc = await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .get();
    }

    if (doc != null && doc.exists) {
      final data = doc.data();
      if (data != null) {
        if (data.containsKey('materiais')) {
          materiais = Map<String, Map<String, dynamic>>.from(data['materiais']);
        } else if (data.containsKey('materiais_preco')) {
          // Converte do formato antigo para o novo
          final precos = Map<String, double>.from(data['materiais_preco']);
          materiais = precos.map((key, value) => MapEntry(key, {'preco': value, 'partilha': 'Individual'}));
        }
      }
    }

    setState(() => isLoading = false);
  }

  // Adiciona novo material ao Firestore
  Future<void> _adicionarMaterial() async {
    final nome = _nomeController.text.trim();
    final valor = double.tryParse(_valorController.text.trim());
    if (nome.isEmpty || valor == null || _tipoPartilha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }
    setState(() => isLoading = true);
    materiais[nome] = {
      'preco': valor,
      'partilha': _tipoPartilha,
    };
    await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .update({'materiais': materiais});
    _nomeController.clear();
    _valorController.clear();
    _tipoPartilha = null;
    await _carregarMateriais();
    setState(() => isLoading = false);
  }

  // Edita um material existente
  Future<void> _editarMaterial(String oldName, double oldPreco, String oldPartilha) async {
    final TextEditingController nomeController = TextEditingController(text: oldName);
    final TextEditingController valorController = TextEditingController(text: oldPreco.toString());
    String? tipoPartilha = oldPartilha;

    final result = await showDialog<Map<String, dynamic>> (
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Material'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome do Material'),
                  ),
                  TextField(
                    controller: valorController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor/kg'),
                  ),
                  DropdownButton<String>(
                    hint: const Text('Tipo de Partilha'),
                    value: tipoPartilha,
                    items: <String>['Individual', 'Geral'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        tipoPartilha = newValue;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nome = nomeController.text.trim();
                    final valor = double.tryParse(valorController.text.trim());
                    if (nome.isNotEmpty && valor != null && tipoPartilha != null) {
                      Navigator.pop(context, {'nome': nome, 'valor': valor, 'partilha': tipoPartilha});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preencha todos os campos!')),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => isLoading = true);
      final newName = result['nome'];
      final newValor = result['valor'];
      final newPartilha = result['partilha'];

      // Se o nome do material mudou, remova o antigo
      if (oldName != newName) {
        materiais.remove(oldName);
      }
      
      materiais[newName] = {
        'preco': newValor,
        'partilha': newPartilha,
      };

      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(prefeituraUid)
          .collection('cooperativas')
          .doc(cooperativaUid)
          .update({'materiais': materiais});
      
      await _atualizarPartilhasCooperados();
      await _carregarMateriais();
      setState(() => isLoading = false);
    }
  }

  // Adicionado para recalcular o valor da partilha de todos os cooperados após a alteração de um preço
  Future<void> _atualizarPartilhasCooperados() async {
    final cooperadosSnapshot = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .get();

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final cooperadoDoc in cooperadosSnapshot.docs) {
      final cooperadoData = cooperadoDoc.data();
      final materiaisQtdCoop = Map<String, dynamic>.from(cooperadoData['materiais_qtd'] ?? {});
      
      double novoValorPartilha = 0.0;
      materiaisQtdCoop.forEach((material, quantidade) {
        if (materiais.containsKey(material)) {
          final preco = materiais[material]!['preco'] ?? 0.0;
          novoValorPartilha += (quantidade as num) * preco;
        }
      });

      batch.update(cooperadoDoc.reference, {'valor_partilha': novoValorPartilha});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Materiais'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              _exportMateriaisCsv();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Valor/kg', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Tipo de Partilha', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: [
                        for (final entry in (materiais.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
                          DataRow(cells: [
                            DataCell(Text(entry.key, style: const TextStyle(fontSize: 16))),
                            DataCell(Text(entry.value['preco'].toStringAsFixed(2), style: const TextStyle(fontSize: 16))),
                            DataCell(Text(entry.value['partilha'], style: const TextStyle(fontSize: 16))),
                            DataCell(Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Editar',
                                  onPressed: viewOnly ? null : () => _editarMaterial(entry.key, entry.value['preco'], entry.value['partilha']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Excluir',
                                  onPressed: viewOnly ? null : () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Confirmação'),
                                        content: const Text('Tem certeza que deseja excluir este material?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Confirmar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      setState(() => isLoading = true);
                                      materiais.remove(entry.key);
                                      await FirebaseFirestore.instance
                                          .collection('prefeituras')
                                          .doc(prefeituraUid)
                                          .collection('cooperativas')
                                          .doc(cooperativaUid)
                                          .update({'materiais': materiais});
                                      await _carregarMateriais();
                                      setState(() => isLoading = false);
                                    }
                                  },
                                ),
                              ],
                            )),
                          ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!viewOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Text('Adicionar Novo Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16.0,
                      runSpacing: 16.0,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                              labelText: 'Nome do Material',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _valorController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Valor/kg',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        DropdownButton<String>(
                          hint: const Text('Tipo de Partilha'),
                          value: _tipoPartilha,
                          items: <String>['Individual', 'Geral'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _tipoPartilha = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _adicionarMaterial,
                    child: const Text('Adicionar'),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Modo somente leitura', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
