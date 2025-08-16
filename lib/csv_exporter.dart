
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

class CsvExporter {
  static Future<void> exportData(
    BuildContext context, {
    required List<String> headers,
    required List<List<String>> rows,
    required String fileName,
  }) async {
    try {
      List<List<dynamic>> allRows = [headers, ...rows];
      String csv = const ListToCsvConverter().convert(allRows);

      // Convert to Uint8List
      final Uint8List bytes = Uint8List.fromList(csv.codeUnits);

      // Save the file
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Arquivo CSV "$fileName.csv" salvo com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar CSV: $e')),
      );
    }
  }
}
