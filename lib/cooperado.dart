// Este arquivo implementa a tela de login para cooperados.
// Autenticação é feita por número de telefone usando Firebase Auth.
// O código segue as guidelines do projeto: limpo, reutilizável e totalmente comentado em pt-br.

import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:infoeco3/validators.dart'; // Importa validadores compartilhados
import 'package:infoeco3/form_fields.dart'; // Importa campo de formulário reutilizável
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore

class Cooperado extends StatefulWidget {
  const Cooperado({super.key});

  @override
  State<Cooperado> createState() => _CooperadoState();
}

class _CooperadoState extends State<Cooperado> {
  final keyform_ = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController(); // Controlador do telefone
  final TextEditingController _smsController = TextEditingController();   // Controlador do código SMS
  final MaskTextInputFormatter phoneMask = MaskTextInputFormatter(mask: '(##) #####-####');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId; // ID de verificação retornado pelo Firebase
  bool _codeSent = false;  // Indica se o código foi enviado
  bool _isLoading = false; // Indica se está processando

  // Função para enviar o código SMS para o telefone informado
  Future<void> _sendCode() async {
    if (!_validatePhone(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefone inválido!')),
      );
      return;
    }
    setState(() { _isLoading = true; });
    final String phone = '+55' + _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Autenticação automática (Android)
          await _auth.signInWithCredential(credential);
          _onLoginSuccess();
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao enviar código: ${e.message}')),
          );
          setState(() { _isLoading = false; });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código enviado!')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() { _verificationId = verificationId; _isLoading = false; });
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar código: $e')),
      );
      setState(() { _isLoading = false; });
    }
  }

  // Função para autenticar usando o código SMS informado
  Future<void> _verifyCode() async {
    if (_verificationId == null || _smsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código recebido por SMS.')),
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      _onLoginSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código inválido!')),
      );
      setState(() { _isLoading = false; });
    }
  }

  // Função chamada ao autenticar com sucesso
  void _onLoginSuccess() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login realizado com sucesso!')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Menu()),
      );
    }
  }

  // Validação simples do telefone (pode ser substituída por um validador mais robusto)
  bool _validatePhone(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length == 11;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Cooperado')),
      body: Form(
        key: keyform_,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.phone,
                  size: 100,
                  color: Color.fromARGB(255, 29, 145, 64),
                ),
                const SizedBox(height: 20),
                // Campo de telefone
                CustomTextFormField(
                  label: 'Telefone',
                  controller: _phoneController,
                  inputFormatters: [phoneMask],
                  validator: (value) {
                    if (value == null || !_validatePhone(value)) {
                      return 'Telefone inválido!';
                    }
                    return null;
                  },
                  obscureText: false,
                ),
                const SizedBox(height: 20),
                // Botão para enviar código
                !_codeSent ? ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Enviar código'),
                ) : Column(
                  children: [
                    // Campo para código SMS
                    CustomTextFormField(
                      label: 'Código SMS',
                      controller: _smsController,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Informe o código recebido.';
                        }
                        return null;
                      },
                      obscureText: false,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Entrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
