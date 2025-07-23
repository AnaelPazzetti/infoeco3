// Este arquivo implementa a funcionalidade de envio de documentos.
// Ele permite que o usuário selecione um arquivo e envie-o.

import 'dart:io'; // Necessário para File em mobile/desktop
import 'dart:typed_data'; // Necessário para Uint8List (web)
import 'package:firebase_storage/firebase_storage.dart'; // Importa Firebase Storage
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth para obter o UID do usuário
import 'package:file_picker/file_picker.dart';
// import 'package:infoeco/menu.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Para verificar se está na web
import 'user_profile_service.dart'; // Import the new service


class Documentos1 extends StatefulWidget {
  const Documentos1({super.key});

  @override
  _DocumentosState createState() => _DocumentosState();
}

class _DocumentosState extends State<Documentos1> {
  String _fileName = ''; // Para armazenar o nome do arquivo
  File? _selectedFile; // Para mobile/desktop
  Uint8List? _selectedFileBytes; // Para web
  bool _isImage = false;
  final UserProfileService _userProfileService = UserProfileService();

  void _selectDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Ser explícito sobre o tipo de arquivo
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        PlatformFile fileDetails = result.files.single;
        setState(() {
          _fileName = fileDetails.name;
          if (kIsWeb) {
            _selectedFileBytes = fileDetails.bytes;
            _selectedFile = null;
          } else {
            if (fileDetails.path == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Erro ao obter o caminho do arquivo.')),
              );
              _fileName = '';
              _selectedFile = null;
              _selectedFileBytes = null;
              _isImage = false;
              return;
            }
            _selectedFile = File(fileDetails.path!);
            _selectedFileBytes = null;
          }
          // Verifica se é uma imagem comum pela extensão
          String? extension = fileDetails.extension?.toLowerCase() ?? (_fileName.contains('.') ? _fileName.split('.').last.toLowerCase() : null);
          if (extension == 'jpg' || extension == 'jpeg' || extension == 'png' || extension == 'gif') {
            _isImage = true;
          } else {
            _isImage = false;
          }
        });
      } else {
        // Usuário cancelou a seleção
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleção de arquivo cancelada.')),
        );
        setState(() {
          _fileName = '';
          _selectedFile = null;
          _selectedFileBytes = null;
          _isImage = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar documento: ${e.toString()}')),
      );
      setState(() {
        _fileName = '';
        _selectedFile = null;
        _selectedFileBytes = null;
        _isImage = false;
      });
    }
  }

  void _sendDocument() async {
    // Verifica se um arquivo foi selecionado
    if (_fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum arquivo selecionado. Por favor, selecione um arquivo primeiro.')),
      );
      print('Nenhum arquivo selecionado.');
      return;
    }

    // Verifica se os dados do arquivo estão disponíveis para a plataforma correta
    if (kIsWeb && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Dados do arquivo não encontrados para upload (web).')),
      );
      print('Erro: Dados do arquivo não encontrados para upload (web).');
      return;
    }

    if (!kIsWeb && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Arquivo não encontrado para upload (mobile/desktop).')),
      );
      print('Erro: Arquivo não encontrado para upload (mobile/desktop).');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado. Faça login para enviar documentos.')),
      );
      print('Erro: Usuário não autenticado.');
      return;
    }
    UserProfileInfo userProfile;
    try {
      userProfile = await _userProfileService.getUserProfileInfo();
    } catch (e) {
      print('Erro ao buscar perfil do usuário: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao determinar o perfil do usuário: ${e.toString()}')),
      );
      return;
    }

    if (userProfile.role == UserRole.unknown || (userProfile.role != UserRole.prefeitura && userProfile.cooperativaUid == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Não foi possível identificar a cooperativa ou perfil para o upload.')),
      );
      print('Erro: Não foi possível identificar a cooperativa ou perfil para o upload. Role: ${userProfile.role}, CooperativaUID: ${userProfile.cooperativaUid}');
      return;
    }

    String storagePath;
    if (userProfile.role == UserRole.cooperado && userProfile.cooperadoUid != null && userProfile.cooperativaUid != null) {
      storagePath = 'Documentos/${userProfile.cooperativaUid}/${userProfile.cooperadoUid}/$_fileName';
    } else if (userProfile.role == UserRole.cooperativa && userProfile.cooperativaUid != null) {
      storagePath = 'Documentos/${userProfile.cooperativaUid}/$_fileName';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Perfil de usuário não permite upload (ex: Prefeitura ou perfil desconhecido).')),
      );
      print('Erro: Perfil de usuário não configurado para este tipo de upload. Role: ${userProfile.role}');
      return;
    }

    try {
      print('Iniciando upload para Firebase Storage: $storagePath');
      Reference storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enviando $_fileName...')),
      );

      if (kIsWeb) {
        print('Usando putData para upload na web.');
        uploadTask = storageRef.putData(_selectedFileBytes!);
      } else {
        print('Usando putFile para upload em mobile/desktop.');
        uploadTask = storageRef.putFile(_selectedFile!);
      }

      TaskSnapshot snapshot = await uploadTask;
      print('Upload concluído. Caminho: ${snapshot.ref.fullPath}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Documento "$_fileName" enviado com sucesso!')),
      );

      setState(() {
        _fileName = '';
        _selectedFile = null;
        _selectedFileBytes = null;
        _isImage = false;
      });
    } on FirebaseException catch (e) {
      print('Erro FirebaseException: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar documento: ${e.code} - ${e.message}')),
      );
    } catch (e) {
      print('Erro inesperado: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro inesperado durante o envio: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enviar Documento'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _selectDocument,
              style: ButtonStyle(
                minimumSize: WidgetStateProperty.all(Size(300, 75)),
                backgroundColor: WidgetStateProperty.all(Colors.orange),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0))),
              ),
              child: Text('Selecionar Documento', style: TextStyle(color: Colors.white),),
            ),

            SizedBox(height: 20),
            // Exibe a miniatura ou o nome do arquivo
             if ((kIsWeb && _selectedFileBytes != null) || (!kIsWeb && _selectedFile != null))
              _isImage
                  ? (kIsWeb
                    ? Image.memory( // Usa Image.memory para bytes na web
                          _selectedFileBytes!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        )
                      : Image.file( // Usa Image.file para File em mobile/desktop
                          _selectedFile!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ))
                  : Column(
                      children: [
                        Icon(Icons.insert_drive_file, size: 50, color: Colors.grey[700]),
                        SizedBox(height: 8),
                        Text(
                          _fileName, // Mostra o nome do arquivo
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      )
            else if (_fileName.isNotEmpty) // Caso o picker tenha sido cancelado mas um nome ainda exista (raro, mas para consistência)
              Text("Nenhum arquivo selecionado para visualização.", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendDocument,
              style: ButtonStyle(
                minimumSize: WidgetStateProperty.all(Size(300, 75)),
                backgroundColor: WidgetStateProperty.all(Colors.orange),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0))),
              ),
              child: Text('Enviar Documento', style: TextStyle(color: Colors.white),),
            ),
          ],
        ),
      ),
    );
  }
}
