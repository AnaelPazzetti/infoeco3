import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:infoeco3/form_fields.dart';

// Tela para troca de senha
class TrocaSenha extends StatefulWidget {
  const TrocaSenha({super.key});

  @override
  State<TrocaSenha> createState() => _TrocaSenhaState();
}

class _TrocaSenhaState extends State<TrocaSenha> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarNovaSenhaController = TextEditingController();
  bool _isLoading = false;
  bool _senhaAtualVisivel = true;
  bool _novaSenhaVisivel = true;
  bool _confirmarSenhaVisivel = true;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarNovaSenhaController.dispose();
    super.dispose();
  }

  Future<void> _trocarSenha() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;

    // Verifica se o usuário está logado
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Usuário não está logado. Por favor, faça login novamente.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Verifica se o usuário tem um e-mail (necessário para reautenticação com senha)
    if (user.email == null || user.email!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'A troca de senha não é aplicável para contas sem e-mail (ex: login por telefone).')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final String email = user.email!;
    final String senhaAtual = _senhaAtualController.text;
    final String novaSenha = _novaSenhaController.text;

    try {
      // Reautentica o usuário com a senha atual para segurança
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: senhaAtual,
      );

      await user.reauthenticateWithCredential(credential);

      // Se a reautenticação for bem-sucedida, atualiza a senha
      await user.updatePassword(novaSenha);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha alterada com sucesso!')),
        );
        Navigator.of(context).pop(); // Volta para a tela anterior
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Ocorreu um erro. Tente novamente.';
      if (e.code == 'wrong-password') {
        errorMessage = 'A senha atual está incorreta.';
      } else if (e.code == 'weak-password') {
        errorMessage =
            'A nova senha é muito fraca (deve ter no mínimo 6 caracteres).';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'Esta operação é sensível e requer autenticação recente. Por favor, faça login novamente.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro desconhecido: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trocar Senha'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 80, color: Colors.green),
                  const SizedBox(height: 40),
                  // Campo Senha Atual
                  CustomTextFormField(
                    label: 'Senha Atual',
                    controller: _senhaAtualController,
                    obscureText: _senhaAtualVisivel,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira sua senha atual.';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(_senhaAtualVisivel
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _senhaAtualVisivel = !_senhaAtualVisivel),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Campo Nova Senha
                  CustomTextFormField(
                    label: 'Nova Senha',
                    controller: _novaSenhaController,
                    obscureText: _novaSenhaVisivel,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira a nova senha.';
                      }
                      if (value.length < 6) {
                        return 'A senha deve ter pelo menos 6 caracteres.';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(_novaSenhaVisivel
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _novaSenhaVisivel = !_novaSenhaVisivel),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Campo Confirmar Nova Senha
                  CustomTextFormField(
                    label: 'Confirmar Nova Senha',
                    controller: _confirmarNovaSenhaController,
                    obscureText: _confirmarSenhaVisivel,
                    validator: (value) {
                      if (value != _novaSenhaController.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(_confirmarSenhaVisivel
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                          () => _confirmarSenhaVisivel = !_confirmarSenhaVisivel),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _trocarSenha,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('ALTERAR SENHA'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
