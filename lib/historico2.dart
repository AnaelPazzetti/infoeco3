//Historico de partilha da cooeprativa

import 'package:flutter/material.dart';
import 'menu.dart';

class WidgetTable extends StatefulWidget {
  const WidgetTable({super.key});

  @override
  State<WidgetTable> createState() => _WidgetTable();
}

class _WidgetTable extends State<WidgetTable> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simula um carregamento de dados
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico 2')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth * 0.9;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: tableWidth,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    DataColumn(label: celulaHeader('Data')),
                    DataColumn(label: celulaHeader('Evento')),
                    DataColumn(label: celulaHeader('Valor')),
                  ],
                  rows: const [
                    // Adicione as linhas da tabela aqui, exemplo:
                    // DataRow(cells: [
                    //   DataCell(Text('01/01/2025')),
                    //   DataCell(Text('Partilha')),
                    //   DataCell(Text('R$ 100,00')),
                    // ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget celulaHeader(String texto) {
    return Container(
      color: Colors.orange,
      padding: const EdgeInsets.all(8.0),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 15.0, color: Colors.white),
      ),
    );
  }
}
