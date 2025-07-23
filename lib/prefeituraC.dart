import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth para autenticação
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore para salvar dados
import 'package:infoeco3/user_profile_service.dart'; // Import UserRole
import 'package:infoeco3/validators.dart'; // Importa validadores compartilhados
import 'package:infoeco3/form_fields.dart'; // Importa campo de formulário reutilizável

// Tela para cadastro de prefeituras
class PrefeituraC extends StatefulWidget {
  const PrefeituraC({super.key});

  @override
  State<PrefeituraC> createState() => _PrefeituraCState();
}

class _PrefeituraCState extends State<PrefeituraC> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // Chave para o formulário
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController(); // Novo campo para nome da prefeitura
  final MaskTextInputFormatter cnpjFormatter =
      MaskTextInputFormatter(mask: '##.###.###/####-##'); // Máscara para CNPJ
  bool visivel = true; // Controle de visibilidade da senha
  bool _isLoading = false; // Indica se está carregando

  // Função de cadastro usando Firebase Auth e Firestore
  // Firebase Auth: cria usuário com email e senha
  // Firestore: salva dados da prefeitura
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Cria usuário no Firebase Authentication
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );
      // Salva dados adicionais no Firestore
      await FirebaseFirestore.instance
          .collection('prefeituras')
          .doc(credential.user!.uid)
          .set({
        'nome': _nomeController.text,
        'cnpj': _cnpjController.text,
        'email': _emailController.text,
      });
      // Mostra mensagem de sucesso


      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'role': UserRole.prefeitura.toString().split('.').last,
      });

      if (!mounted) return;

      // Quando é finalizado o cadastro, mostra confirmação e volta para a tela inicial
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Sucesso'),
            content: const Text('Usuário Criado'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      );

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      // Mostra erro de autenticação
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro Prefeitura')), // Add an AppBar
      body: Form(
        key: _formKey, // Usa a nova chave
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
                const Padding(padding: EdgeInsets.all(20)),
                // Campo Nome
                CustomTextFormField(
                  label: 'Nome da Prefeitura',
                  controller: _nomeController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome obrigatório!';
                    }
                    return null;
                  },
                ),
                const Padding(padding: EdgeInsets.all(20)),
                // Campo CNPJ
                CustomTextFormField(
                  label: 'CNPJ',
                  controller: _cnpjController,
                  inputFormatters: [cnpjFormatter],
                  validator: (value) {
                    if (value == null || !validarCNPJ(value)) {
                      return 'CNPJ inválido!';
                    }
                    return null;
                  },
                ),
                const Padding(padding: EdgeInsets.all(20)),
                // Campo Email
                CustomTextFormField(
                  label: 'Email',
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || !validarEmail(value)) {
                      return 'Email inválido! Insira um email que seja válido!';
                    }
                    return null;
                  },
                ),
                const Padding(padding: EdgeInsets.all(20)),
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
                const Padding(padding: EdgeInsets.all(20)),
                // Botão para cadastro
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _register,
                        style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.green)),
                        child: const Text('Cadastre-se'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// Fim da tela de cadastro de prefeituras
