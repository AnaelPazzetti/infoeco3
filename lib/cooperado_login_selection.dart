
import 'package:flutter/material.dart';
import 'cooperado.dart';
import 'cooperado_email_login.dart';

class CooperadoLoginSelection extends StatelessWidget {
  const CooperadoLoginSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login de Cooperado'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Como você gostaria de fazer o login?',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Assuming Cooperado() is the phone login screen
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
              child: const Text('LOGIN COM TELEFONE', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CooperadoEmailLogin()),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 129, 207, 45),
                  minimumSize: const Size(300, 75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
              ),
              child: const Text('LOGIN COM EMAIL', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
