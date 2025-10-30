// Este arquivo implementa a tela de login.
// Ele permite que o usuário escolha entre diferentes tipos de login: Prefeitura, Cooperativa ou Cooperado.

import 'package:flutter/material.dart';
import 'cooperado_login_selection.dart';
import 'prefeitura.dart';
import 'cooperativa.dart'; // Correctly imports CooperativaLogin
import 'cooperado.dart';

// Classe principal para a tela de login
class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar com o título da página
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Login'), // Use a fixed title or pass it if needed
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
                  context, MaterialPageRoute(builder: (context) => const CooperadoLoginSelection())),
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