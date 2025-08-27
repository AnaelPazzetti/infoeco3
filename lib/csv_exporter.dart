
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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

      if (kIsWeb) {
        // Save the file for web
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      } else {
        // Save the file for mobile
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName.csv';
        final file = File(path);
        await file.writeAsBytes(bytes);

        final result = await OpenFile.open(path);
        if (result.type != ResultType.done) {
          throw Exception('Could not open file');
        }
      }

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
