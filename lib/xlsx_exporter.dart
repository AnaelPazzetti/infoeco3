import 'dart:typed_data';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class XlsxExporter {
  static Future<void> exportData(
    BuildContext context, {
    required List<String> headers,
    required List<List<String>> rows,
    required String fileName,
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Add headers
      sheetObject.appendRow(headers.map((header) => TextCellValue(header)).toList());

      // Add data rows
      for (var row in rows) {
        sheetObject.appendRow(row.map((cell) => TextCellValue(cell)).toList());
      }

      var fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Error encoding Excel file.');
      }

      if (kIsWeb) {
        // WEB: EXPORT AS XLSX (EXCEL)
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arquivo Excel "$fileName.xlsx" salvo com sucesso!')),
        );
      } else {
        // MOBILE: EXPORT AS XLSX (EXCEL)
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName.xlsx';
        final file = File(path);

        await file.writeAsBytes(fileBytes);
        final result = await OpenFile.open(path, type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        if (result.type != ResultType.done) {
          throw Exception('Could not open file: ${result.message}');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arquivo Excel "$fileName.xlsx" salvo com sucesso!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar arquivo: $e')),
      );
    }
  }
}