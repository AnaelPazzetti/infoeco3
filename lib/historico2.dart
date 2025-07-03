// Este arquivo implementa a tabela de histórico.
// Ele exibe informações como nome, material, classe, peso (kg) e valor.

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
          final double tableWidth = constraints.maxWidth * 0.95;
          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tableWidth),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Table(
                          columnWidths: const <int, TableColumnWidth>{
                            0: FixedColumnWidth(150.0),
                            1: FixedColumnWidth(150.0),
                            2: FixedColumnWidth(150.0),
                          },
                          border: TableBorder.all(color: Colors.black),
                          children: [
                            TableRow(children: [
                              celulaHeader('Data'),
                              celulaHeader('Evento'),
                              celulaHeader('Valor'),
                            ]),
                            // ...adicione as linhas da tabela aqui...
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  celulaHeader(String texto) {
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
