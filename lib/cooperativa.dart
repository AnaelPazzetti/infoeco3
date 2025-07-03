// Este arquivo implementa a tela de login para cooperativas.
// Ele utiliza o Firebase para autenticação e validação de CNPJ.

import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoeco3/validators.dart'; // Importa validadores compartilhados
import 'package:infoeco3/form_fields.dart'; // Importa campo de formulário reutilizável

class CooperativaLogin extends StatefulWidget {
  const CooperativaLogin({super.key});

  @override
  State<CooperativaLogin> createState() => _CooperativaLoginState();
}

class _CooperativaLoginState extends State<CooperativaLogin> {
  final _keyform = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool visivel = true;

  Future<void> _login() async {
    if (!_keyform.currentState!.validate()) return;
    final senha = _passwordController.text;
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
        key: _keyform,
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
                  controller: _passwordController,
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
