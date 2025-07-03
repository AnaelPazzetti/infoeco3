import 'package:flutter/material.dart';
// import 'package:infoeco/main.dart';
import 'package:infoeco3/menu.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:infoeco3/form_fields.dart'; // Importa campo de formulário reutilizável
import 'package:firebase_core/firebase_core.dart'; // Importa o Firebase Core
import 'package:cloud_firestore/cloud_firestore.dart'; // (Opcional, se for usar Firestore)

class Prefeitura extends StatefulWidget {
  const Prefeitura({super.key});

  @override
  State<Prefeitura> createState() => _Prefeitura();
}

class _Prefeitura extends State<Prefeitura> {
  final keyform_ = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool visivel = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    if (!keyform_.currentState!.validate()) return;
    final senha = _senhaController.text;
    final email = _emailController.text.trim();
    try {
      // Autentica pelo Firebase Auth usando o e-mail informado
      await _auth.signInWithEmailAndPassword(email: email, password: senha);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => Menu()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('E-mail ou senha inválidos!')),
      );
    }
  }

  // Função para exibir o diálogo de recuperação de senha
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailResetController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Usuário deve tocar no botão para fechar
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Redefinir Senha'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Por favor, insira seu e-mail para redefinir a senha.'),
                const SizedBox(height: 16),
                TextField(
                  controller: emailResetController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Fecha o diálogo
              },
            ),
            TextButton(
              child: const Text('Enviar'),
              onPressed: () {
                _sendPasswordResetEmail(emailResetController.text.trim());
                Navigator.of(dialogContext).pop(); // Fecha o diálogo
              },
            ),
          ],
        );
      },
    );
  }

  // Função para enviar o e-mail de redefinição de senha
  Future<void> _sendPasswordResetEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um e-mail válido.')),
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link de redefinição de senha enviado para o seu e-mail.')),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'Nenhum usuário encontrado para esse e-mail.';
      } else {
        message = 'Erro ao enviar e-mail de redefinição: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: keyform_,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.person,
                  size: 100,
                  color: Color.fromARGB(255, 29, 145, 64),
                ),
                const SizedBox(height: 20),
                // Campo E-mail
                CustomTextFormField(
                  label: 'E-mail',
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'E-mail inválido!';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Campo Senha
                CustomTextFormField(
                  label: 'Senha',
                  controller: _senhaController,
                  obscureText: visivel,
                  suffixIcon: IconButton(
                    icon: Icon(visivel ? Icons.visibility : Icons.visibility_off, color: Colors.green),
                    onPressed: () {
                      setState(() {
                        visivel = !visivel;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Senha obrigatória!';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  child: const Text('Entrar'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  child: const Text(
                    'Esqueceu a senha?',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
