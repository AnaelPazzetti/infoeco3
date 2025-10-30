
import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoeco3/form_fields.dart';
import 'package:infoeco3/user_profile_service.dart';

class CooperadoEmailLogin extends StatefulWidget {
  const CooperadoEmailLogin({super.key});

  @override
  State<CooperadoEmailLogin> createState() => _CooperadoEmailLoginState();
}

class _CooperadoEmailLoginState extends State<CooperadoEmailLogin> {
  final _keyform = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool visivel = true;

  Future<void> _login() async {
    if (!_keyform.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (credential.user == null) {
        throw Exception('Usuário não encontrado.');
      }

      // 2. Check user role and approval status in Firestore
      final userDoc = await _firestore.collection('users').doc(credential.user!.uid).get();

      if (userDoc.exists && 
          userDoc.data()?['role'] == UserRole.cooperado.toString().split('.').last) {
        
        if (userDoc.data()?['isAprovado'] == true) {
          // 3. Role is correct and user is approved, navigate to menu
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => Menu()),
            );
          }
        } else {
          // User is a cooperado but not approved
          await _auth.signOut();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seu cadastro ainda não foi aprovado.')),
          );
        }
      } else {
        // User is not a cooperado, deny access
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso negado. Este usuário não é um cooperado.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail ou senha inválidos!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Cooperado'), backgroundColor: Colors.green),
      body: Form(
        key: _keyform,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.person,
                  size: 100,
                  color: Color.fromARGB(255, 29, 145, 64),
                ),
                const SizedBox(height: 20),
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
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('Entrar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
