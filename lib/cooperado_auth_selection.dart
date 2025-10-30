
import 'package:flutter/material.dart';
import 'cooperadoC.dart';
import 'cooperado_email_cadastro.dart';

class CooperadoAuthSelection extends StatelessWidget {
  const CooperadoAuthSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Cooperado'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Como você gostaria de se cadastrar?',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Cooperado()),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 29, 145, 64),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('CADASTRAR COM TELEFONE', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CooperadoEmailCadastro()),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 129, 207, 45),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('CADASTRAR COM EMAIL', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
