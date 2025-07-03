// Este arquivo implementa a tela de perfil do usuário.
// Ele exibe informações básicas do perfil, como nome e CPF/CNPJ, em um layout estilizado.

import 'dart:io'; // Necessário para File
import 'package:flutter/material.dart';
import 'package:infoeco3/configuracoes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Para escolher imagens
import 'package:flutter/foundation.dart' show kIsWeb; // Para verificar se está na web
import 'package:firebase_storage/firebase_storage.dart'; // Para upload de arquivos
import 'user_profile_service.dart'; // Importa o serviço de perfil

// Classe que representa a tela de perfil do usuário
class Perfil extends StatefulWidget {
  const Perfil({super.key});

  @override
  State<Perfil> createState() => _Perfil();
}

class _Perfil extends State<Perfil> {
  final UserProfileService _userProfileService = UserProfileService();
  String? nome;
  String? documento;
  String? telefone;
  String? fotoUrl; // Novo campo para a URL da foto do perfil
  bool _isUploading = false; // Estado para controlar o upload da foto
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
  }

  // Busca os dados do usuário autenticado no Firestore e exibe na tela de perfil
  // Agora busca cooperado como subcoleção de cooperativas
  Future<void> _carregarDadosUsuario() async {
    setState(() { isLoading = true; });
    final profile = await _userProfileService.getUserProfileInfo();
    DocumentSnapshot? doc;

    if (profile.role == UserRole.cooperado && profile.prefeituraUid != null && profile.cooperativaUid != null && profile.cooperadoUid != null) {
      doc = await FirebaseFirestore.instance
          .collection('prefeituras').doc(profile.prefeituraUid)
          .collection('cooperativas').doc(profile.cooperativaUid)
          .collection('cooperados').doc(profile.cooperadoUid)
          .get();
    } else if (profile.role == UserRole.cooperativa && profile.prefeituraUid != null && profile.cooperativaUid != null) {
      doc = await FirebaseFirestore.instance
          .collection('prefeituras').doc(profile.prefeituraUid)
          .collection('cooperativas').doc(profile.cooperativaUid)
          .get();
    } else if (profile.role == UserRole.prefeitura && profile.prefeituraUid != null) {
      doc = await FirebaseFirestore.instance.collection('prefeituras').doc(profile.prefeituraUid).get();
    }

    if (doc != null && doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      setState(() {
        nome = data?['nome'] ?? 'Sem nome';
        documento = data?['cpf'] ?? data?['cnpj'] ?? '-';
        telefone = data?['telefone'] ?? '-';
        fotoUrl = data?['fotoUrl'];
        isLoading = false;
      });
    } else {
      setState(() {
        nome = 'Usuário não encontrado';
        documento = '-';
        telefone = '-';
        fotoUrl = null;
        isLoading = false;
      });
    }
  }

  Future<void> _escolherEAtualizarFotoPerfil() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alterar Foto de Perfil'),
          content: const Text('A sua foto de perfil atual será substituída. Deseja continuar?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Confirmar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return; // Usuário cancelou a operação
    }
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      // Usuário cancelou a seleção
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploading = true;
    });

    String? oldFotoUrl = fotoUrl; // Guarda a URL antiga para deletar depois

    try {
      // Upload para Firebase Storage
      String fileName = 'foto_perfil_${user.uid}.${image.name.split('.').last}';
      Reference storageRef = FirebaseStorage.instance.ref().child('fotos_perfil').child(fileName);
      
      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(await image.readAsBytes());
      } else {
        File imageFile = File(image.path);
        uploadTask = storageRef.putFile(imageFile);
      }
      
      TaskSnapshot snapshot = await uploadTask;
      String newFotoUrl = await snapshot.ref.getDownloadURL();

      // Atualizar Firestore
      final profile = await _userProfileService.getUserProfileInfo();
      DocumentReference? docRef;

      if (profile.role == UserRole.cooperado && profile.prefeituraUid != null && profile.cooperativaUid != null && profile.cooperadoUid != null) {
        docRef = FirebaseFirestore.instance
            .collection('prefeituras').doc(profile.prefeituraUid)
            .collection('cooperativas').doc(profile.cooperativaUid)
            .collection('cooperados').doc(profile.cooperadoUid);
      } else if (profile.role == UserRole.cooperativa && profile.prefeituraUid != null && profile.cooperativaUid != null) {
        docRef = FirebaseFirestore.instance
            .collection('prefeituras').doc(profile.prefeituraUid)
            .collection('cooperativas').doc(profile.cooperativaUid);
      } else if (profile.role == UserRole.prefeitura && profile.prefeituraUid != null) {
        docRef = FirebaseFirestore.instance.collection('prefeituras').doc(profile.prefeituraUid);
      }

      if (docRef != null) {
        await docRef.update({'fotoUrl': newFotoUrl});

        // Atualiza o estado da UI com a nova foto
        setState(() => fotoUrl = newFotoUrl);

        // Mostra a mensagem de sucesso
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de perfil atualizada!')));

        // Deleta a foto antiga do Firebase Storage, se ela existir
        if (oldFotoUrl != null && oldFotoUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(oldFotoUrl).delete();
          } catch (e) {
            // Não incomoda o usuário se a deleção falhar (ex: arquivo já não existia)
            print("Aviso: Não foi possível deletar a foto antiga. Erro: $e");
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar foto: ${e.toString()}')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              // mainAxisAlignment: MainAxisAlignment.center, // Removido para permitir rolagem se necessário
              children: <Widget>[
                Container(
                  margin: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: SizedBox(
                    // height: 400.0, // Altura pode ser flexível
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 50.0,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: (fotoUrl != null && fotoUrl!.isNotEmpty)
                                ? NetworkImage(fotoUrl!)
                                : null,
                            child: (fotoUrl == null || fotoUrl!.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 10.0),
                          // Nome real do usuário
                          Text(
                            nome ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const Padding(padding: EdgeInsets.all(10)),
                          Card(
                            margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                            clipBehavior: Clip.antiAlias,
                            color: Colors.white,
                            elevation: 5.0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 22.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  // CPF ou CNPJ real do usuário
                                  Text(
                                    'CPF/CNPJ: ${documento ?? '-'}',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Telefone do usuário
                                  Text(
                                    'Telefone: ${telefone ?? '-'}',
                                    style: TextStyle(
                                      color: Colors.green,
                                    ),
                                  ),                                                                 
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                           _isUploading
                              ? const CircularProgressIndicator()
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Alterar Foto de Perfil'),
                                  onPressed: _escolherEAtualizarFotoPerfil,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.green,
                                  ),
                                ),
                          const SizedBox(height: 20), // Espaço no final do card
                        ],
                      ),
                    ),
                  ),
                ),
                // Botão de Configurações (se existir, pode ser movido para cá ou para AppBar)
                // ElevatedButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => Configuracoes())); }, child: Text("Configurações"))
              ],
            ),
    );
  }
}
