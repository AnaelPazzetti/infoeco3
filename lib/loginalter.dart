// Este arquivo implementa uma tela de login estilizada.
// Ele contém campos de entrada para email e senha, além de botões para ações como "Entrar" e "Criar Conta".

import 'package:flutter/material.dart';
/* import 'package:google_fonts/google_fonts.dart';
import 'package:lms/widgets/app_text.dart'; 
import 'package:lms/widgets/app_title.dart';
import 'package:lms/widgets/input_text.dart'; */

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
      body: SafeArea(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500, maxHeight: 500),
            child: Container(
              width: double.infinity,
              height: 410,
              padding: EdgeInsets.all(48),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.all(Radius.circular(50))),
              child: Wrap(
                runSpacing: 20,
                children: [
                  // AppTitle('Login'),
                  SizedBox(height: 20),
                  // InputText(placeholder: 'Email'),
                  SizedBox(height: 20),
                  // InputText(placeholder: 'Senha'),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    // child: AppText('Esqueceu a sua senha?',
                    // textAlign: TextAlign.end,
                    // color: Colors.white.withOpacity(0.05)
                    // ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        // primary: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        textStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                      ),
                      child: Text('Entrar'),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // AppTitle('Não tem uma conta?'),
                      SizedBox(width: 6),
                      // AppTitle('Criar Conta',
                      // color: Colors.blue),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }
}
