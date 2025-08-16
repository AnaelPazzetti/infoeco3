// historico_cooperativa.dart
// Tela para exibir o histórico de partilhas da cooperativa
// Mostra tabela: Material | Preço | Quantidade, filtrando por data da partilha

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis
import 'package:infoeco3/csv_exporter.dart';

class HistoricoCooperativa extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const HistoricoCooperativa({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});

  @override
  State<HistoricoCooperativa> createState() => _HistoricoCooperativaState();
}

class _HistoricoCooperativaState extends State<HistoricoCooperativa> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  List<Map<String, dynamic>> partilhas = [];
  int selectedPartilhaIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    // Se vierem via widget (modo prefeitura), usa diretamente
    if (widget.cooperativaUid != null && widget.prefeituraUid != null) {
      cooperativaUid = widget.cooperativaUid;
      prefeituraUid = widget.prefeituraUid;
    } else {
      final profile = await _userProfileService.getUserProfileInfo();
      if (profile.role == UserRole.cooperativa) {
        cooperativaUid = profile.cooperativaUid;
        prefeituraUid = profile.prefeituraUid;
      } else {
        setState(() => isLoading = false);
        return;
      }
    }
    if (cooperativaUid == null || prefeituraUid == null) {
      setState(() => isLoading = false);
      return;
    }
    // Busca partilhas
    final partilhasSnap = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('partilhas')
        .orderBy('data', descending: true)
        .get();
    partilhas = partilhasSnap.docs.map((d) => d.data()).toList();
    setState(() => isLoading = false);
  }

  void _exportToCsv(Map<String, dynamic> allMaterials, Map<String, dynamic> materiaisInfo) {
    final headers = ['Material', 'Preço (Reais)', 'Quantidade (kg)'];
    final rows = allMaterials.entries.map((entry) {
      final material = entry.key;
      final precoRaw = materiaisInfo[entry.key]?['preco'];
      final preco = (precoRaw is num) ? precoRaw.toStringAsFixed(2) : '-';
      final quantidade = entry.value.toString();
      return [material, preco, quantidade];
    }).toList();

    CsvExporter.exportData(
      context,
      headers: headers,
      rows: rows,
      fileName: 'historico_partilhas',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (partilhas.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Histórico de Partilhas')),
        body: const Center(child: Text('Nenhuma partilha encontrada.')),
      );
    }
    final partilhaSelecionada = partilhas[selectedPartilhaIndex];
    final materiaisInfo = partilhaSelecionada['materiais'] as Map<String, dynamic>? ?? {};
    final materiaisIndividuais = partilhaSelecionada['materiais_qtd'] as Map<String, dynamic>? ?? {};
    final materiaisGerais = partilhaSelecionada['materiaisG_qtd'] as Map<String, dynamic>? ?? {};
    final allMaterials = {...materiaisIndividuais, ...materiaisGerais};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Partilhas'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportToCsv(allMaterials, materiaisInfo),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Histórico de Partilhas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Selecionar data: ', style: TextStyle(fontSize: 16)),
                    DropdownButton<int>(
                      value: selectedPartilhaIndex,
                      items: [
                        for (int i = 0; i < partilhas.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(_formatarData(partilhas[i]['data'])),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => selectedPartilhaIndex = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                tableContainer(
                  child: allMaterials.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                                'Nenhum material registrado para esta partilha.'),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: Table(
                                  columnWidths: const <int, TableColumnWidth>{
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(1.5),
                                    2: FlexColumnWidth(1.5),
                                  },
                                  border: TableBorder.all(
                                      color: Colors.grey[300]!, width: 1),
                                  children: [
                                    TableRow(children: [
                                      celulaHeader('Material'),
                                      celulaHeader('Preço (R\$)'),
                                      celulaHeader('Quantidade (kg)'),
                                    ]),
                                    for (final entry in allMaterials.entries)
                                      TableRow(children: [
                                        celula(entry.key),
                                        celula((materiaisInfo[entry.key]?['preco'] as num?)
                                                ?.toStringAsFixed(2) ??
                                            '-'),
                                        celula(entry.value.toString()),
                                      ]),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (e) {
      return data.toString();
    }
  }
}