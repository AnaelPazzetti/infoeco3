import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis
// Tela para cooperativa gerenciar a lista de materiais e valores
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
  Map<String, double> materiaisPreco = {};
  Map<String, dynamic> materiaisQtd = {};
  bool isLoading = true;
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarMateriais();
  }

  // Carrega os materiais e preços da cooperativa logada
  Future<void> _carregarMateriais() async {
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
    if (doc.exists && doc.data()?.containsKey('materiais_preco') == true) {
      materiaisPreco = Map<String, double>.from(doc['materiais_preco']);
    }
    if (doc.exists && doc.data()?.containsKey('materiais_qtd') == true) {
      materiaisQtd = Map<String, dynamic>.from(doc['materiais_qtd']);
    }
    setState(() => isLoading = false);
  }

  // Recalcula valor_partilha de todos os cooperados após alteração de materiais_preco
  Future<void> _recalcularValorPartilhaParaTodosCooperados() async {
    if (cooperativaUid == null || prefeituraUid == null) return;
    // Busca o preço atualizado dos materiais
    final docCoop = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .get();
    final materiaisPreco = Map<String, dynamic>.from(docCoop.data()?['materiais_preco'] ?? {});
    // Busca todos os cooperados
    final cooperadosSnapshot = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .get();
    for (final doc in cooperadosSnapshot.docs) {
      final data = doc.data();
      final materiaisQtd = Map<String, dynamic>.from(data['materiais_qtd'] ?? {});
      double novoValorPartilha = 0;
      materiaisQtd.forEach((material, qtd) {
        final preco = (materiaisPreco[material] ?? 0).toDouble();
        novoValorPartilha += (qtd is num ? qtd.toDouble() : 0) * preco;
      });
      await doc.reference.update({'valor_partilha': novoValorPartilha});
    }
  }

  // Adiciona novo material ao Firestore
  Future<void> _adicionarMaterial() async {
    final nome = _nomeController.text.trim();
    final valor = double.tryParse(_valorController.text.trim());
    if (nome.isEmpty || valor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e valor corretamente!')),
      );
      return;
    }
    setState(() => isLoading = true);
    materiaisPreco[nome] = valor;
    await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .update({'materiais_preco': materiaisPreco});
    await _recalcularValorPartilhaParaTodosCooperados();
    _nomeController.clear();
    _valorController.clear();
    await _carregarMateriais();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Materiais 2')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth * 0.8;
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tableWidth),
                      child: Table(
                        columnWidths: const <int, TableColumnWidth>{
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                          4: FlexColumnWidth(1.5),
                        },
                        border: TableBorder.all(color: Colors.black),
                        children: [
                          TableRow(children: [
                            celulaHeader('Material'),
                            celulaHeader('Valor/kg'),
                            celulaHeader('Quantidade'),
                            celulaHeader('Valor'),
                            celulaHeader('Enviar'),
                          ]),
                          // Exibe os materiais em ordem alfabética
                          for (final entry in (materiaisPreco.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
                            TableRow(children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(entry.key, style: const TextStyle(fontSize: 16)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(entry.value.toStringAsFixed(2), style: const TextStyle(fontSize: 16)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text((materiaisQtd[entry.key] ?? 0).toString(), style: const TextStyle(fontSize: 16)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text((entry.value * (materiaisQtd[entry.key] ?? 0)).toStringAsFixed(2), style: const TextStyle(fontSize: 16)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: 'Editar valor',
                                      onPressed: viewOnly
                                          ? null
                                          : () async {
                                              final controller = TextEditingController(text: entry.value.toString());
                                              final result = await showDialog<double>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('Editar valor de ${entry.key}'),
                                                  content: TextField(
                                                    controller: controller,
                                                    keyboardType: TextInputType.number,
                                                    decoration: const InputDecoration(labelText: 'Novo valor (kg)'),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Cancelar'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        final novoValor = double.tryParse(controller.text.trim());
                                                        if (novoValor != null) {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text('Confirmação'),
                                                              content: const Text('Tem certeza que deseja realizar essa ação?'),
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
                                                            Navigator.pop(context, novoValor);
                                                          }
                                                        }
                                                      },
                                                      child: const Text('Salvar'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (result != null) {
                                                setState(() => isLoading = true);
                                                materiaisPreco[entry.key] = result;
                                                await FirebaseFirestore.instance
                                                    .collection('prefeituras')
                                                    .doc(prefeituraUid)
                                                    .collection('cooperativas')
                                                    .doc(cooperativaUid)
                                                    .update({'materiais_preco': materiaisPreco});
                                                await _recalcularValorPartilhaParaTodosCooperados();
                                                await _carregarMateriais();
                                                setState(() => isLoading = false);
                                              }
                                            },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Excluir material',
                                      onPressed: viewOnly
                                          ? null
                                          : () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Confirmação'),
                                                  content: const Text('Tem certeza que deseja realizar essa ação?'),
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
                                                materiaisPreco.remove(entry.key);
                                                await FirebaseFirestore.instance
                                                    .collection('prefeituras')
                                                    .doc(prefeituraUid)
                                                    .collection('cooperativas')
                                                    .doc(cooperativaUid)
                                                    .update({'materiais_preco': materiaisPreco});
                                                await _recalcularValorPartilhaParaTodosCooperados();
                                                await _carregarMateriais();
                                                setState(() => isLoading = false);
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!viewOnly) ...{
                      const Text('Adicionar novo material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _nomeController,
                              decoration: const InputDecoration(
                                labelText: 'Nome do material',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
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
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _adicionarMaterial,
                            child: const Text('Adicionar'),
                          ),
                        ],
                      ),
                    } else ...{
                      const Text('Modo somente leitura', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    },
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
