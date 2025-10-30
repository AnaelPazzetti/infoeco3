// Este arquivo implementa a tela de cadastro.
// Ele permite que o usuário escolha entre cadastrar uma Prefeitura, Cooperativa ou Cooperado.

import 'package:flutter/material.dart';
import 'cooperado_auth_selection.dart';
import 'prefeituraC.dart';
import 'cooperativaC.dart';
import 'cooperadoC.dart';

//Código para o cadastro de cooperados, cooperativas e prefeituras
class Cadastro extends StatelessWidget {
  const Cadastro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro',
      theme: ThemeData( 
        primarySwatch: Colors.green,
      ),
      home: const MyHomePage(title: 'InfoEco'),
    );
  }
}

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
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(widget.title),
      ),
     body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                 Navigator.push(
                    context, MaterialPageRoute(builder: (context) => const PrefeituraC()));
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
            Padding(padding: EdgeInsets.all(10)),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const Cooperativa()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 129, 207, 45),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('COOPERATIVA', style: TextStyle(color: Colors.white)),
            ),
            Padding(padding: EdgeInsets.all(10)),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const CooperadoAuthSelection()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 171, 228, 111),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('COOPERADO', style: TextStyle(color: Colors.white)),
            ),
            Padding(padding: EdgeInsets.all(10)),
          ],
        ),
      ),
    );
  }
}
