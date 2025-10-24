// Este arquivo implementa a tela de histórico de partilhas do cooperado;

import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'historico2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_service.dart'; // Importa o serviço de perfil de usuário
import 'package:infoeco3/xlsx_exporter.dart';

class Historico extends StatefulWidget {
  const Historico({super.key});

  @override
  State<Historico> createState() => _HistoricoState();
}

class _HistoricoState extends State<Historico> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  String? userUid;
  List<Map<String, dynamic>> partilhas = [];
  int selectedPartilhaIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final profile = await _userProfileService.getUserProfileInfo();

    if (profile.role != UserRole.cooperado || profile.cooperadoUid == null || profile.cooperativaUid == null || profile.prefeituraUid == null) {
      setState(() => isLoading = false);
      return;
    }

    userUid = profile.cooperadoUid;
    cooperativaUid = profile.cooperativaUid;
    prefeituraUid = profile.prefeituraUid;

    // Busca partilhas do cooperado
    final partilhasSnap = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .doc(cooperativaUid)
        .collection('cooperados')
        .doc(userUid)
        .collection('partilhas')
        .orderBy('data', descending: true)
        .get();
    partilhas = partilhasSnap.docs.map((d) => d.data()).toList();
    setState(() => isLoading = false);
  }

  void _exportToCsv(Map<String, dynamic> materiaisQtd, Map<String, dynamic> materiaisInfo) {
    final headers = ['Material', 'Preço (Reais)', 'Quantidade (kg)'];
    final rows = materiaisQtd.entries.map((entry) {
      final material = entry.key;
      final precoRaw = materiaisInfo[entry.key]?['preco'];
      final preco = (precoRaw is num) ? precoRaw.toStringAsFixed(2) : '-';
      final quantidade = entry.value.toString();
      return [material, preco, quantidade];
    }).toList();

    XlsxExporter.exportData(
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
        appBar: AppBar(title: const Text('Histórico de Partilhas'), backgroundColor: Colors.green),
        body: const Center(child: Text('Nenhuma partilha encontrada.')),
      );
    }
    final partilhaSelecionada = partilhas[selectedPartilhaIndex];
    final materiaisQtd = partilhaSelecionada['materiais_qtd'] as Map<String, dynamic>? ?? {};
    final materiaisInfo = partilhaSelecionada['materiais'] as Map<String, dynamic>? ?? {};
    final valorPartilha = partilhaSelecionada['valor_partilha'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Partilhas'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportToCsv(materiaisQtd, materiaisInfo),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Histórico de Partilhas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Selecionar data: '),
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
            DataTable(
              dividerThickness: 1,
              headingRowColor: MaterialStateColor.resolveWith((states) => Colors.green.shade200),
              columns: const [
                DataColumn(label: Text('Material')),
                DataColumn(label: Text('Preço (R\$)')),
                DataColumn(label: Text('Quantidade (kg)')),
              ],
              rows: [
                for (final entry in materiaisQtd.entries)
                  DataRow(cells: [
                    DataCell(Text(entry.key)),
                    DataCell(Text((materiaisInfo[entry.key]?['preco'] as num?)?.toStringAsFixed(2) ?? '-')),
                    DataCell(Text(entry.value.toString())),
                  ]),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Valor da partilha nesta data: R\$ ${valorPartilha is num ? valorPartilha.toStringAsFixed(2) : valorPartilha}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
            ),
          ],
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
