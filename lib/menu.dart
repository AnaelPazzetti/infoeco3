// Este arquivo implementa o menu principal do aplicativo.
// Ele contém botões que redirecionam para diferentes telas, como perfil, documentos, histórico, materiais, etc.

import 'package:flutter/material.dart';
import 'package:infoeco3/calendario.dart';
import 'package:infoeco3/configuracoes.dart';
import 'package:infoeco3/documentos.dart';
import 'package:infoeco3/historico.dart';
import 'package:infoeco3/historico_cooperativa.dart'; // Importa a tela de histórico da cooperativa
// import 'package:infoeco/historico2.dart';
import 'package:infoeco3/materiais.dart';
import 'package:infoeco3/materiais2.dart';
import 'package:infoeco3/materiais3.dart';
import 'package:infoeco3/perfil.dart';
import 'package:infoeco3/presencas.dart';
import 'package:infoeco3/presencas_cooperativa.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoeco3/verificarCooperados.dart';
import 'package:infoeco3/user_profile_service.dart'; // Importa o serviço de perfil
import 'package:infoeco3/verificarCooperativas.dart';
import 'package:infoeco3/verificarDocumentos.dart';
import 'package:infoeco3/widgets/large_menu_button.dart';
import 'package:infoeco3/main.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final UserProfileService _userProfileService = UserProfileService();
  UserProfileInfo? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userProfileService.getUserProfileInfo();
    setState(() {
      _userProfile = profile;
      _isLoading = false;
    });
  }

  Future<void> _abrirComoCooperativa(BuildContext context, Widget Function(String cooperativaUid, String prefeituraUid) builder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefeituraUid = user.uid;
    final cooperativasSnapshot = await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(prefeituraUid)
        .collection('cooperativas')
        .get();
    final cooperativas = cooperativasSnapshot.docs;
    if (cooperativas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma cooperativa vinculada.')),
      );
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecione uma Cooperativa'),
        children: cooperativas.map((doc) => SimpleDialogOption(
          child: Text(doc['nome'] ?? doc.id),
          onPressed: () => Navigator.pop(context, doc.id),
        )).toList(),
      ),
    );
    if (selected != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => builder(selected, prefeituraUid),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menu')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Checagem correta de aprovação
    final isPrefeitura = _userProfile?.role == UserRole.prefeitura;
    final isCooperativa = _userProfile?.role == UserRole.cooperativa;
    final isCooperado = _userProfile?.role == UserRole.cooperado;
    final dynamic aprovadoValue = _userProfile?.isAprovado;
    final bool isAprovado = aprovadoValue == true;

    // Cooperado não aprovado
    if (isCooperado && !isAprovado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Menu'),
        ),
        body: const Center(
          child: Text(
            'Aguardando aprovacao da cooperativa',
            style: TextStyle(fontSize: 20, color: Colors.orange, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Cooperativa não aprovada
    if (isCooperativa && !isAprovado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Menu'),
        ),
        body: const Center(
          child: Text(
            'Aguardando aprovacao da prefeitura',
            style: TextStyle(fontSize: 20, color: Colors.orange, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Wrap Scaffold with PopScope to handle back button
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (didPop) async {
        if (didPop) return; // If system already popped, do nothing
        final bool confirmLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Saída'),
            content: const Text('Você tem certeza que deseja sair do aplicativo?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sair'),
              ),
            ],
          ),
        ) ?? false; // Handle null if dialog dismissed

        if (confirmLogout) {
          // Perform logout actions and navigate to the initial login/home screen
          await FirebaseAuth.instance.signOut();
          // Navigate to the initial login/home screen and clear stack
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MyApp()),
              (Route<dynamic> route) => false,
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Menu'),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Botão PERFIL
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                            context, MaterialPageRoute(builder: (context) => const Perfil()));
                      },
                      style: ButtonStyle(
                        minimumSize: MaterialStateProperty.all(const Size(300, 75)),
                        backgroundColor: MaterialStateProperty.all(
                          const Color.fromARGB(255, 255, 179, 65)),
                        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          )),
                      ),
                      child: const Text('PERFIL', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    // Se prefeitura, mostra só os botões viewOnly e configurações
                    if (isPrefeitura)
                      // Botões para Prefeitura
                      ..._buildPrefeituraButtons(context)
                    else if (isCooperativa)
                      // Botões para Cooperativa
                      ..._buildCooperativaButtons(context)
                    else if (isCooperado)
                      // Botões para Cooperado
                      ..._buildCooperadoButtons(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Constrói os botões para o perfil de Prefeitura
  List<Widget> _buildPrefeituraButtons(BuildContext context) {
    return [
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VerificarCooperativas())),
        child: Text('VERIFICAR COOPERATIVAS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => _abrirComoCooperativa(context, (coopUid, prefUid) => VerificarCooperados(cooperativaUid: coopUid, prefeituraUid: prefUid, viewOnly: true)),
        child: Text('VER COOPERADOS (visualização)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => _abrirComoCooperativa(context, (coopUid, prefUid) => Materiais2Screen(cooperativaUid: coopUid, prefeituraUid: prefUid, viewOnly: true)),
        child: Text('LISTA DE MATERIAIS (visualização)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => _abrirComoCooperativa(context, (coopUid, prefUid) => Materiais3(cooperativaUid: coopUid, prefeituraUid: prefUid, viewOnly: true)),
        child: Text('MATERIAIS SEPARADOS (visualização)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => _abrirComoCooperativa(context, (coopUid, prefUid) => HistoricoCooperativa(cooperativaUid: coopUid, prefeituraUid: prefUid, viewOnly: true)),
        child: Text('HISTÓRICO COOPERATIVA (visualização)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => _abrirComoCooperativa(context, (coopUid, prefUid) => PresencasCooperativa(cooperativaUid: coopUid, prefeituraUid: prefUid, viewOnly: true)),
        child: Text('PRESENÇAS (visualização)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 196, 0),
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Configuracoes())),
        child: Text('CONFIGURAÇÕES', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 179, 65),
      ),
    ];
  }

  // Constrói os botões para o perfil de Cooperativa
  List<Widget> _buildCooperativaButtons(BuildContext context) {
    return [
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VerificarCooperados())),
        child: Text('VERIFICAR COOPERADOS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Materiais2Screen())),
        child: Text('Lista de Materiais', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Materiais3())),
        child: Text('MATERIAIS SEPARADOS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoricoCooperativa())),
        child: Text('HISTÓRICO COOPERATIVA', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PresencasCooperativa())),
        child: Text('PRESENÇAS', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 196, 0),
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Calendario())),
        child: Text('CALENDÁRIO', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Documentos1())),
        child: Text('DOCUMENTOS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VerificarDocumentos())),
        child: Text('VERIFICAR DOCUMENTOS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Configuracoes())),
        child: Text('CONFIGURAÇÕES', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 179, 65),
      ),
    ];
  }

  // Constrói os botões para o perfil de Cooperado
  List<Widget> _buildCooperadoButtons(BuildContext context) {
    return [
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Historico())),
        child: const Text('HISTÓRICO', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 29, 145, 64),
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Materiais())),
        child: Text('MATERIAIS', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 179, 65),
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Presencas())),
        child: Text('PRESENÇAS', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 196, 0),
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Calendario())),
        child: Text('CALENDÁRIO', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Documentos1())),
        child: Text('DOCUMENTOS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VerificarDocumentos())),
        child: Text('VERIFICAR DOCUMENTOS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
      ),
      SizedBox(height: 10),
      LargeMenuButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Configuracoes())),
        child: Text('CONFIGURAÇÕES', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 255, 179, 65),
      ),
    ];
  }
}
