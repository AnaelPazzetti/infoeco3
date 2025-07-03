// Este arquivo implementa a tela de login principal.
// Ele permite que o usuário escolha entre diferentes tipos de login: Prefeitura, Cooperativa ou Cooperado.

import 'package:flutter/material.dart';
import 'prefeitura.dart';
import 'cooperativa.dart'; // Correctly imports CooperativaLogin
import 'cooperado.dart';

// Classe principal para a tela de login
class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login', // Título do aplicativo
      theme: ThemeData(
        primarySwatch: Colors.green, // Tema principal com cor verde
      ),
      home: const MyHomePage(title: 'InfoEco'), // Página inicial
    );
  }
}

// Página inicial do login
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar com o título da página
      appBar: AppBar(
        title: Text(widget.title),
      ),

      // Corpo da tela com botões de login
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // Botão para login da Prefeitura
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const Prefeitura()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 29, 145, 64),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('PREFEITURA', style: TextStyle(color: Colors.white)),
            ),
            const Padding(padding: EdgeInsets.all(10)),

            // Botão para login da Cooperativa
            ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CooperativaLogin())),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 129, 207, 45),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('COOPERATIVA', style: TextStyle(color: Colors.white)),
            ),
            const Padding(padding: EdgeInsets.all(10)),
            
            // Botão para login do Cooperado
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const Cooperado())),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 171, 228, 111),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('COOPERADO', style: TextStyle(color: Colors.white)),
            ),
            const Padding(padding: EdgeInsets.all(10)),
          ],
        ),
      ),
    );
  }
}
