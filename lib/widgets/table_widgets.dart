// lib/widgets/table_widgets.dart
// Este arquivo centraliza os widgets reutilizáveis para a criação de células de tabela,
// seguindo a diretriz 'code_reuse' para evitar duplicação de código.

import 'package:flutter/material.dart';

// Widget para envolver uma tabela em um card estilizado, com sombra e cantos arredondados.
Widget tableContainer({required Widget child}) {
  return Card(
    elevation: 3,
    margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8.0),
      child: child,
    ),
  );
}

// Widget para criar uma célula de cabeçalho de tabela com estilo padronizado.
Widget celulaHeader(String texto) {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.grey[300]!),
        right: BorderSide(color: Colors.grey[300]!),
      ),
    ),
    child: Text(
      texto,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
    ),
  );
}

// Widget para criar uma célula de dados de tabela com estilo padronizado.
// Aceita um 'dynamic' para poder exibir tanto Widgets quanto texto.
Widget celula(dynamic conteudo) {
  return Container(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
    decoration: BoxDecoration(
      border: Border(
        right: BorderSide(color: Colors.grey[300]!),
      ),
    ),
    child: conteudo is Widget
        ? conteudo
        : Text(conteudo.toString(), style: const TextStyle(fontSize: 15.0)),
  );
}