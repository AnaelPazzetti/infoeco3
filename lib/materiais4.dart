// Tela para exibir os materiais coletados pelo cooperado (materiais_qtd)
// Comentado em pt-br

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis

class Materiais4 extends StatefulWidget {
  const Materiais4({super.key});

  @override
  State<Materiais4> createState() => _Materiais4State();
}

class _Materiais4State extends State<Materiais4> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  Map<String, dynamic> materiaisQtd = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarMateriaisQtd();
  }

  // Carrega o UID da cooperativa e os materiais_qtd do cooperado logado
  Future<void> _carregarMateriaisQtd() async {
    final profile = await _userProfileService.getUserProfileInfo();

    if (profile.role != UserRole.cooperado || profile.cooperadoUid == null || profile.cooperativaUid == null || profile.prefeituraUid == null) {
      setState(() => isLoading = false);
      return;
    }

    final docCooperado = await FirebaseFirestore.instance
        .collection('prefeituras').doc(profile.prefeituraUid)
        .collection('cooperativas').doc(profile.cooperativaUid)
        .collection('cooperados').doc(profile.cooperadoUid)
        .get();

    if (docCooperado.exists && docCooperado.data() != null && docCooperado.data()!.containsKey('materiais_qtd')) {
      materiaisQtd = Map<String, dynamic>.from(docCooperado['materiais_qtd']);
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Materiais Coletados')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Quantidade (kg)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  for (final entry in materiaisQtd.entries)
                    DataRow(cells: [
                      DataCell(Text(entry.key, style: const TextStyle(fontSize: 16))),
                      DataCell(Text(entry.value.toString(), style: const TextStyle(fontSize: 16))),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}