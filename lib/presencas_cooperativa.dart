// presencas_cooperativa.dart
// Tela para cooperativa/presidente visualizar, aprovar, editar e excluir presenças de todos os cooperados
// Comentado em pt-br

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis

class PresencasCooperativa extends StatefulWidget {
  final String? cooperativaUid;
  final String? prefeituraUid;
  final bool viewOnly;
  const PresencasCooperativa({super.key, this.cooperativaUid, this.prefeituraUid, this.viewOnly = false});

  @override
  State<PresencasCooperativa> createState() => _PresencasCooperativaState();
}

class _PresencasCooperativaState extends State<PresencasCooperativa> {
  final UserProfileService _userProfileService = UserProfileService();
  String? cooperativaUid;
  String? prefeituraUid;
  bool get viewOnly => widget.viewOnly;
  bool loading = true;
  int _limiteHistorico = 30;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cooperativaUid = widget.cooperativaUid;
    prefeituraUid = widget.prefeituraUid;
    _carregarCooperativaUid();
  }

  // Busca o UID da cooperativa logada
  Future<void> _carregarCooperativaUid() async {
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
    setState(() { loading = false; });
  }

  // Formata duração para HH:mm:ss
  String _formatarDuracaoCompleta(String? duracao) {
    if (duracao == null) return '-';
    return duracao;
  }

  String _formatarHora(String? dataIso) {
    if (dataIso == null) return '-';
    final data = DateTime.tryParse(dataIso);
    if (data == null) return '-';
    return "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenças da Cooperativa'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth * 0.95;
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Presenças Registradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Mostrar:'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _limiteHistorico,
                        items: [
                          DropdownMenuItem(value: 7, child: Text('7')),
                          DropdownMenuItem(value: 30, child: Text('30')),
                          DropdownMenuItem(value: 60, child: Text('60')),
                          DropdownMenuItem(value: -1, child: Text('Todas')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _limiteHistorico = value);
                        },
                      ),
                      const SizedBox(width: 24),
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
                    ],
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
                          .collection('presencas')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        List docs = snapshot.data?.docs ?? [];
                        String search = _searchController.text.trim();
                        // Filtro por nome
                        if (search.isNotEmpty) {
                          docs = docs.where((doc) {
                            final nome = (doc['nome'] ?? '').toString().toLowerCase();
                            return nome.contains(search.toLowerCase());
                          }).toList();
                        }
                        if (docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Nenhum registro encontrado.'),
                          );
                        }
                        // Ordena por data de entrada decrescente
                        docs.sort((a, b) {
                          final ea = a['entrada'];
                          final eb = b['entrada'];
                          if (ea == null || eb == null) return 0;
                          return eb.compareTo(ea);
                        });
                        final limitedDocs = _limiteHistorico == -1 ? docs : docs.take(_limiteHistorico).toList();
                        List<TableRow> linhas = [
                          TableRow(children: [
                            celulaHeader('NOME'),
                            celulaHeader('DATA'),
                            celulaHeader('ENTRADA'),
                            celulaHeader('SAÍDA'),
                            celulaHeader('HORAS TRABALHADAS'),
                            celulaHeader('APROVADO'),
                            celulaHeader('AÇÃO'),
                          ]),
                        ];
                        for (var doc in limitedDocs) {
                          final data = doc['data'] ?? '';
                          final entradaHist = doc['entrada'] != null ? _formatarHora(doc['entrada']) : '-';
                          final saidaHist = doc['saida'] != null ? _formatarHora(doc['saida']) : '-';
                          final horas = doc['horas_trabalhadas'] ?? '-';
                          final aprovado = (doc.data() as Map<String, dynamic>).containsKey('aprovado pelo presidente') && doc['aprovado pelo presidente'] == true ? 'Sim' : 'Não';
                          List<Widget> cells = [
                            celula(doc['nome'] ?? ''),
                            celula(data),
                            celula(entradaHist),
                            celula(saidaHist),
                            celula(horas),
                            celula(aprovado),
                          ];
                          // Botões de ação: aprovar, editar, excluir
                          cells.add(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  if (aprovado == 'Não')
                                    SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: ElevatedButton(
                                        onPressed: viewOnly ? null : () async {
                                          await FirebaseFirestore.instance
                                              .collection('prefeituras')
                                              .doc(prefeituraUid)
                                              .collection('cooperativas')
                                              .doc(cooperativaUid)
                                              .collection('presencas')
                                              .doc(doc.id)
                                              .update({'aprovado pelo presidente': true});
                                          setState(() {});
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: EdgeInsets.zero,
                                          shape: const CircleBorder(),
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      tooltip: 'Editar Entrada/Saída',
                                      onPressed: viewOnly ? null : () async {
                                        DateTime? novaEntrada = doc['entrada'] != null ? DateTime.tryParse(doc['entrada']) : null;
                                        DateTime? novaSaida = doc['saida'] != null ? DateTime.tryParse(doc['saida']) : null;
                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            DateTime? tempEntrada = novaEntrada;
                                            DateTime? tempSaida = novaSaida;
                                            return AlertDialog(
                                              title: const Text('Editar Entrada/Saída'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ListTile(
                                                    title: const Text('Entrada'),
                                                    subtitle: Text(tempEntrada != null ? tempEntrada.toString() : '-'),
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.edit),
                                                      onPressed: () async {
                                                        final picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: tempEntrada ?? DateTime.now(),
                                                          firstDate: DateTime(2020),
                                                          lastDate: DateTime(2100),
                                                        );
                                                        if (picked != null) {
                                                          final pickedTime = await showTimePicker(
                                                            context: context,
                                                            initialTime: TimeOfDay.fromDateTime(tempEntrada ?? DateTime.now()),
                                                          );
                                                          if (pickedTime != null) {
                                                            setState(() {
                                                              tempEntrada = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute);
                                                            });
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  ListTile(
                                                    title: const Text('Saída'),
                                                    subtitle: Text(tempSaida != null ? tempSaida.toString() : '-'),
                                                    trailing: IconButton(
                                                      icon: const Icon(Icons.edit),
                                                      onPressed: () async {
                                                        final picked = await showDatePicker(
                                                          context: context,
                                                          initialDate: tempSaida ?? DateTime.now(),
                                                          firstDate: DateTime(2020),
                                                          lastDate: DateTime(2100),
                                                        );
                                                        if (picked != null) {
                                                          final pickedTime = await showTimePicker(
                                                            context: context,
                                                            initialTime: TimeOfDay.fromDateTime(tempSaida ?? DateTime.now()),
                                                          );
                                                          if (pickedTime != null) {
                                                            setState(() {
                                                              tempSaida = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute);
                                                            });
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: const Text('Cancelar'),
                                                  onPressed: () => Navigator.of(context).pop(),
                                                ),
                                                ElevatedButton(
                                                  child: const Text('Salvar'),
                                                  onPressed: () async {
                                                    // Atualiza entrada/saida e recalcula horas_trabalhadas
                                                    await FirebaseFirestore.instance
                                                        .collection('prefeituras')
                                                        .doc(prefeituraUid)
                                                        .collection('cooperativas')
                                                        .doc(cooperativaUid)
                                                        .collection('presencas')
                                                        .doc(doc.id)
                                                        .update({
                                                      'entrada': tempEntrada?.toIso8601String(),
                                                      'saida': tempSaida?.toIso8601String(),
                                                      'horas_trabalhadas': (tempEntrada != null && tempSaida != null)
                                                          ? _formatarDuracaoCompleta(tempSaida!.difference(tempEntrada!).toString().split('.').first)
                                                          : null,
                                                    });
                                                    Navigator.of(context).pop();
                                                    setState(() {});
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      tooltip: 'Excluir presença',
                                      onPressed: viewOnly ? null : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Excluir presença'),
                                            content: const Text('Tem certeza que deseja excluir este registro?'),
                                            actions: [
                                              TextButton(
                                                child: const Text('Cancelar'),
                                                onPressed: () => Navigator.of(context).pop(false),
                                              ),
                                              ElevatedButton(
                                                child: const Text('Excluir'),
                                                onPressed: () => Navigator.of(context).pop(true),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await FirebaseFirestore.instance
                                              .collection('prefeituras')
                                              .doc(prefeituraUid)
                                              .collection('cooperativas')
                                              .doc(cooperativaUid)
                                              .collection('presencas')
                                              .doc(doc.id)
                                              .delete();
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          linhas.add(TableRow(children: cells));
                        }
                        return Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: 900), // Ensures table is always wide enough for all columns
                              child: Table(
                                defaultColumnWidth: const FixedColumnWidth(140.0),
                                border: TableBorder.all(
                                  color: Colors.black,
                                ),
                                children: linhas,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const Padding(padding: EdgeInsets.all(10)),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Menu(),
                        ),
                      );
                    },
                    style: ButtonStyle(
                      minimumSize: MaterialStateProperty.all(const Size(150, 75)),
                      backgroundColor: MaterialStateProperty.all(Colors.orange),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    child: const Text('Voltar', style: TextStyle(color: Colors.white)),
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
