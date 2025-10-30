import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:infoeco3/menu.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:infoeco3/user_profile_service.dart';
import 'package:infoeco3/validators.dart';
import 'package:infoeco3/form_fields.dart';

class CooperadoEmailCadastro extends StatefulWidget {
  const CooperadoEmailCadastro({super.key});

  @override
  State<CooperadoEmailCadastro> createState() => _CooperadoEmailCadastroState();
}

class _CooperadoEmailCadastroState extends State<CooperadoEmailCadastro> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  final MaskTextInputFormatter cpfFormatter =
      MaskTextInputFormatter(mask: '###.###.###-##');
  bool _isLoading = false;
  bool visivel = true;

  List<Map<String, dynamic>> _cooperativas = [];
  Map<String, dynamic>? _selectedCooperativa;

  @override
  void initState() {
    super.initState();
    _carregarCooperativas();
  }

  // Carrega as cooperativas para o dropdown
  Future<void> _carregarCooperativas() async {
    // Usamos uma collectionGroup query para buscar todas as cooperativas, independente da prefeitura
    final snapshot = await FirebaseFirestore.instance.collectionGroup('cooperativas').get();
    setState(() {
      _cooperativas = snapshot.docs.map((doc) => {
        'uid': doc.id,
        'nome': doc['nome'] ?? doc.id,
        'prefeitura_uid': doc['prefeitura_uid'] // Guardamos o UID da prefeitura para a referência
      }).toList();
      if (_cooperativas.isNotEmpty) {
        _selectedCooperativa = _cooperativas.first;
      }
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedCooperativa == null) return;
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      // Referência para a cooperativa selecionada
      final cooperativaRef = FirebaseFirestore.instance
          .collection('prefeituras').doc(_selectedCooperativa!['prefeitura_uid'])
          .collection('cooperativas').doc(_selectedCooperativa!['uid']);

      // Cria o cooperado como uma subcoleção da cooperativa
      final cooperadoRef = cooperativaRef.collection('cooperados').doc(credential.user!.uid);
      await cooperadoRef.set({
        'uid': credential.user!.uid, // Adiciona o UID do usuário no documento
        'nome': _nomeController.text,
        'cpf': _cpfController.text,
        'email': _emailController.text,
        'cooperativa_uid': _selectedCooperativa!['uid'], // Salva o UID da cooperativa
        'isAprovado': false,
        'materiais_qtd': {
          "ALUMINIO DURO": 0,
          "ALUMINIO GROSSO": 0,
          "VIDRO": 0
        }
      });

      // Salva o perfil do usuário na coleção 'users' para lookups rápidos
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'role': UserRole.cooperado.toString().split('.').last,
        'isAprovado': false,
        'cooperativaUid': _selectedCooperativa!['uid'],
        'prefeituraUid': _selectedCooperativa!['prefeitura_uid'],
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Sucesso'),
            content: const Text('Usuário Criado com sucesso!'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.message}')),
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
      appBar: AppBar(title: const Text('Cadastro Cooperado por Email'), backgroundColor: Colors.green),
      body: Form(
        key: _formKey,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.person, size: 100, color: Color.fromARGB(255, 29, 145, 64)),
                SizedBox(height: 20),
                CustomTextFormField(
                  label: 'Nome Completo',
                  controller: _nomeController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome obrigatório!';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                CustomTextFormField(
                  label: 'CPF',
                  controller: _cpfController,
                  inputFormatters: [cpfFormatter],
                  validator: (value) {
                    if (value == null || !validarCPF(value)) {
                      return 'CPF inválido!';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                CustomTextFormField(
                  label: 'Email',
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || !validarEmail(value)) {
                      return 'Email inválido!';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
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
                SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedCooperativa,
                      items: _cooperativas.map<DropdownMenuItem<Map<String, dynamic>>>((coop) => DropdownMenuItem<Map<String, dynamic>>(
                        value: coop,
                        child: Text(coop['nome'] as String),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCooperativa = value;
                        });
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.grey.shade200,
                        filled: true,
                        labelText: 'Selecione a Cooperativa',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Selecione uma cooperativa!';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _register,
                        child: Text('Cadastre-se'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
