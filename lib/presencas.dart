//Cooperado registra sua presenca, entrada e saida
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/widgets/table_widgets.dart'; // Importa os widgets de tabela reutilizáveis
import 'package:infoeco3/xlsx_exporter.dart';

// Tela principal para exibir presenças
class Presencas extends StatefulWidget {
  const Presencas({Key? key}) : super(key: key);

    State<Presencas> createState() => _Presencas();
}

class _Presencas extends State<Presencas> {
  final GlobalKey<_WidgetTableState> _widgetTableKey = GlobalKey<_WidgetTableState>();

  
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tabela de Presença"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              _widgetTableKey.currentState?.exportCsv();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: WidgetTable(key: _widgetTableKey),
          ),
        ),
      ),
    );
  }
}

// Tela para exibir a tabela de presenças
class WidgetTable extends StatefulWidget {
  const WidgetTable({super.key});

  
  State<WidgetTable> createState() => _WidgetTableState();
}

class _WidgetTableState extends State<WidgetTable> {
  final UserProfileService _userProfileService = UserProfileService();
  List<QueryDocumentSnapshot> _docs = [];
  String? nomeCooperado;
  String? uid;
  String? cooperativaUid;
  String? prefeituraUid;
  DateTime? entrada;
  DateTime? saida;
  Duration? horasTrabalhadas;
  bool isCooperado = false;
  bool loading = true;
  int _limiteHistorico = 7; // Limite padrão de presenças exibidas

  void exportCsv() {
    final headers = ['NOME', 'DATA', 'ENTRADA', 'SAÍDA', 'HORAS TRABALHADAS'];
    final rows = _docs.map((doc) {
      final nome = (doc['nome'] ?? '').toString();
      final data = (doc['data'] ?? '').toString();
      final entrada = (doc['entrada'] != null ? _formatarHora(DateTime.parse(doc['entrada'])) : '-').toString();
      final saida = (doc['saida'] != null ? _formatarHora(DateTime.parse(doc['saida'])) : '-').toString();
      final horas = (doc['horas_trabalhadas'] ?? '-').toString();
      return [nome, data, entrada, saida, horas];
    }).toList();

    XlsxExporter.exportData(
      context,
      headers: headers,
      rows: rows,
      fileName: 'presencas',
    );
  }

  
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _carregarEntradaLocal();
  }

  // Busca o cooperado em todas as prefeituras/cooperativas e salva o cooperativa_uid correto
  Future<void> _carregarDadosUsuario() async {
    final profile = await _userProfileService.getUserProfileInfo();
    if (profile.role == UserRole.cooperado && profile.cooperadoUid != null) {
      final docCooperado = await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(profile.prefeituraUid)
          .collection('cooperativas')
          .doc(profile.cooperativaUid)
          .collection('cooperados')
          .doc(profile.cooperadoUid)
          .get();

      nomeCooperado = docCooperado.data()?['nome'] ?? '';
      uid = profile.cooperadoUid;
      cooperativaUid = profile.cooperativaUid;
      prefeituraUid = profile.prefeituraUid;
      isCooperado = true;
    }

    setState(() {
      loading = false;
    });
  }

  // Carrega a entrada salva localmente (caso o usuário saia da tela)
  Future<void> _carregarEntradaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final entradaStr = prefs.getString('entrada_presenca');
    if (entradaStr != null) {
      entrada = DateTime.tryParse(entradaStr);
      setState(() {});
    }
  }

  // Salva a entrada localmente
  Future<void> _salvarEntradaLocal(DateTime entradaHora) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entrada_presenca', entradaHora.toIso8601String());
  }

  // Limpa a entrada salva localmente
  Future<void> _limparEntradaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('entrada_presenca');
  }

  Future<void> _registrarPresenca({required bool isEntrada}) async {
    final agora = DateTime.now();
    if (isEntrada) {
      entrada = agora;
      saida = null;
      horasTrabalhadas = null;
      await _salvarEntradaLocal(entrada!); // Salva localmente
    } else {
      saida = agora;
      if (entrada != null && cooperativaUid != null) {
        horasTrabalhadas = saida!.difference(entrada!);
        // Salva cada presença como um novo documento na subcoleção correta
        await FirebaseFirestore.instance
            .collection('prefeituras')
            .doc(prefeituraUid)
            .collection('cooperativas')
            .doc(cooperativaUid)
            .collection('presencas')
            .add({
          'cooperado_uid': uid,
          'nome': nomeCooperado,
          'entrada': entrada?.toIso8601String(),
          'saida': saida?.toIso8601String(),
          'horas_trabalhadas': horasTrabalhadas != null ? _formatarDuracaoCompleta(horasTrabalhadas!) : null,
          'data': _formatarData(DateTime.now()),
          'aprovado pelo presidente': false, // Novo campo booleano
          'cooperativa_uid': cooperativaUid, // Salva o cooperativa_uid junto
        });
        // Limpa os horários para novo registro
        entrada = null;
        saida = null;
        horasTrabalhadas = null;
        await _limparEntradaLocal(); // Limpa localmente
      }
    }
    setState(() {});
  }

  // Formata duração para HH:mm:ss
  String _formatarDuracaoCompleta(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    final segundos = d.inSeconds % 60;
    return "${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
  }

  String _formatarData(DateTime data) {
    return "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
  }

  String _formatarHora(DateTime data) {
    return "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}";
  }

  // Adiciona parâmetro opcional para não exibir o título/filtro se já estiverem centralizados fora
  Widget _tabelaHistoricoPresencas({bool semTitulo = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!semTitulo) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text('Presenças Registradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text('Mostrar:'),
              ),
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
              const SizedBox(width: 16),
            ],
          ),
        ],
        StreamBuilder<QuerySnapshot>(
          // Consulta presenças do cooperado na subcoleção da cooperativa correta
          stream: cooperativaUid == null
              ? null
              : FirebaseFirestore.instance
                  .collection('prefeituras')
                  .doc(prefeituraUid)
                  .collection('cooperativas')
                  .doc(cooperativaUid)
                  .collection('presencas')
                  .where('cooperado_uid', isEqualTo: uid)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nenhum registro de presença encontrado.'),
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
            _docs = limitedDocs;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('NOME', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ENTRADA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SAÍDA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('HORAS TRABALHADAS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  for (var doc in limitedDocs)
                    DataRow(cells: [
                      DataCell(Text(doc['nome'] ?? '')),
                      DataCell(Text(doc['data'] ?? '')),
                      DataCell(Text(doc['entrada'] != null ? _formatarHora(DateTime.parse(doc['entrada'])) : '-')),
                      DataCell(Text(doc['saida'] != null ? _formatarHora(DateTime.parse(doc['saida'])) : '-')),
                      DataCell(Text(doc['horas_trabalhadas'] ?? '')),
                    ]),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        tableContainer(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 600),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('NOME', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('DATA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ENTRADA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SAÍDA', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('HORAS TRABALHADAS', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  DataRow(cells: [
                    DataCell(Text(nomeCooperado ?? '')),
                    DataCell(Text(_formatarData(DateTime.now()))),
                    DataCell(
                      entrada == null
                          ? ElevatedButton(
                              onPressed: () => _registrarPresenca(isEntrada: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                minimumSize: const Size(100, 40),
                              ),
                              child: const Text('Registrar', style: TextStyle(color: Colors.white)),
                            )
                          : Text(_formatarHora(entrada!)),
                    ),
                    DataCell(
                      entrada != null && saida == null
                          ? ElevatedButton(
                              onPressed: () => _registrarPresenca(isEntrada: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                minimumSize: const Size(100, 40),
                              ),
                              child: const Text('Registrar', style: TextStyle(color: Colors.white)),
                            )
                          : (saida != null ? Text(_formatarHora(saida!)) : const Text('-')),
                    ),
                    DataCell(
                      (entrada != null && saida != null && horasTrabalhadas != null)
                          ? Text(_formatarDuracaoCompleta(horasTrabalhadas!))
                          : const Text('-'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Centraliza título, filtro e tabela de histórico, removendo título duplicado
        Center(
          child: Column(
            children: [
              // Título e filtro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Text('Presenças Registradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 16),
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
                ],
              ),
              const SizedBox(height: 8),
              // Centraliza a tabela de histórico
              Align(
                alignment: Alignment.center,
                child: tableContainer(
                  child: _tabelaHistoricoPresencas(semTitulo: true),
                ),
              ),
            ],
          ),
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
            minimumSize: WidgetStateProperty.all(const Size(150, 75)),
            backgroundColor: WidgetStateProperty.all(Colors.orange),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          child: const Text('Voltar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}