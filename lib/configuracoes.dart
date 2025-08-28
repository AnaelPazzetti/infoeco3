// Este arquivo implementa a tela de configurações.
// Ele contém botões para acessar funcionalidades como troca de senha, notificações, ajuda e sair.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa o Firebase Auth
import 'package:infoeco3/main.dart'; // Importa a tela principal para redirecionamento
import 'ajuda.dart';
import 'troca_senha.dart';

class Configuracoes extends StatefulWidget {
  const Configuracoes({super.key});

  @override
  State<StatefulWidget> createState() => _Configuracoes();
}

class _Configuracoes extends State<Configuracoes> {
  // Função para realizar o logout do usuário
  Future<void> _sair() async {
    // Mostra um diálogo de confirmação antes de sair
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Você tem certeza que deseja sair?'),
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
        );
      },
    );

    // Se o usuário confirmou, realiza o logout
    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();

      // Navega para a tela inicial (MyHomePage em main.dart) e remove todas as telas anteriores da pilha
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MyHomePage(title: 'InfoEco'),
          ),
          (Route<dynamic> route) => false, // Predicado que remove todas as rotas
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const TrocaSenha()));
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(300, 60),
                  backgroundColor: const Color.fromARGB(255, 29, 145, 64)),
              child:
                  Text('Trocar Senha', style: TextStyle(color: Colors.white)),
            ),
            // const Padding(padding: EdgeInsets.all(10)),
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.push(context,
            //         MaterialPageRoute(builder: (context) => Notificacoes()));
            //   },
            //   style: ButtonStyle(
            //       minimumSize: MaterialStateProperty.all(const Size(300, 60)),
            //       backgroundColor: MaterialStateProperty.all(
            //           const Color.fromARGB(255, 129, 207, 45)),
            //       shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            //           RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(10.0),
            //       ))),
            //   child:
            //       Text('Notificações', style: TextStyle(color: Colors.white)),
            // ),
            // const Padding(padding: EdgeInsets.all(10)),
            // ElevatedButton(
            //   onPressed: () {
            //     Navigator.push(
            //         context, MaterialPageRoute(builder: (context) => Ajuda()));
            //   },
            //   style: ButtonStyle(
            //       minimumSize: MaterialStateProperty.all(const Size(300, 60)),
            //       backgroundColor: MaterialStateProperty.all(
            //           const Color.fromARGB(255, 171, 228, 111)),
            //       shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            //           RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(10.0),
            //       ))),
            //   child: Text('Ajuda', style: TextStyle(color: Colors.white)),
            // ),
            const Padding(padding: EdgeInsets.all(10)),
            ElevatedButton(
              onPressed: _sair, // Chama a função de logout
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(300, 60),
                  backgroundColor: const Color.fromARGB(255, 29, 145, 64)),
              child: const Text('Sair', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
