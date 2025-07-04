import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth para autenticação
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore para salvar dados
import 'package:infoeco3/menu.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:infoeco3/user_profile_service.dart'; // Import UserRole
import 'package:infoeco3/validators.dart'; // Importa validadores compartilhados
import 'package:infoeco3/form_fields.dart'; // Importa campo de formulário reutilizável

// Tela de cadastro de cooperativa
class Cooperativa extends StatefulWidget {
  const Cooperativa({super.key});

  @override
  State<Cooperativa> createState() => _CooperativaState();
}

class _CooperativaState extends State<Cooperativa> {
  // Chave do formulário para validação
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // Controladores dos campos
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  // Máscara para o campo de CNPJ
  final MaskTextInputFormatter cnpjFormatter =
      MaskTextInputFormatter(mask: '##.###.###/####-##');
  bool _isLoading = false; // Indica se está carregando
  bool visivel = true;

  // Lista de prefeituras disponíveis
  List<Map<String, dynamic>> _prefeituras = [];
  String? _selectedPrefeituraUid;

  @override
  void initState() {
    super.initState();
    _carregarPrefeituras();
  }

  // Carrega as prefeituras do Firestore para o dropdown
  Future<void> _carregarPrefeituras() async {
    final snapshot = await FirebaseFirestore.instance.collection('prefeituras').get();
    setState(() {
      _prefeituras = snapshot.docs.map((doc) => {'uid': doc.id, 'nome': doc['nome'] ?? doc.id}).toList();
      if (_prefeituras.isNotEmpty) {
        _selectedPrefeituraUid = _prefeituras.first['uid'];
      }
    });
  }

  // Função de cadastro usando Firebase Auth e Firestore
  // Firebase Auth: cria usuário com email e senha
  // Firestore: salva dados da cooperativa
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Cria usuário no Firebase Authentication
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );
      // Salva dados adicionais no Firestore, agora como subcoleção de prefeituras
      final prefeituraRef = FirebaseFirestore.instance.collection('prefeituras').doc(_selectedPrefeituraUid);
      final cooperativaRef = prefeituraRef.collection('cooperativas').doc(credential.user!.uid);
      await cooperativaRef.set({
        'nome': _nomeController.text,
        'cnpj': _cnpjController.text,
        'email': _emailController.text,
        'prefeitura_uid': _selectedPrefeituraUid, // Salva o UID da prefeitura escolhida
        'isAprovado': false, // Adicionado campo de aprovação
        'materiais_preco': {
          "ALUMINIO DURO": 999.9,
          "ALUMINIO GROSSO": 999.9,
          "BATERIA": 999.9,
          "CIMENTO": 999.9,
          "COBRE": 999.9,
          "COBRE LIMPO": 999.9,
          "CRISTAL": 999.9,
          "EMBALAGEM CARTONADA_LEITE": 999.9,
          "EMBALAGEM_AGUA": 999.9,
          "EMBALAGEM_ÓLEO DE COZINHA": 999.9,
          "INOX": 999.9,
          "ISOPOR": 999.9,
          "LATINHAS": 999.9,
          "METAL": 999.9,
          "MOTORZINHO": 999.9,
          "PAPEL BRANCO": 999.9,
          "PAPEL MISTO": 999.9,
          "PAPELAO": 999.9,
          "PEAD": 999.9,
          "PET BRANCO": 999.9,
          "PET VERDE": 999.9,
          "PLASTICO FINO": 999.9,
          "PVC": 999.9,
          "RAFIA": 999.9,
          "SUCATA": 999.9,
          "VIDRO": 999.9
        },
        'materiais_qtd': {
          "ALUMINIO DURO": 0,
          "ALUMINIO GROSSO": 0,
          "BATERIA": 0,
          "CIMENTO": 0,
          "COBRE": 0,
          "COBRE LIMPO": 0,
          "CRISTAL": 0,
          "EMBALAGEM CARTONADA_LEITE": 0,
          "EMBALAGEM_AGUA": 0,
          "EMBALAGEM_ÓLEO DE COZINHA": 0,
          "INOX": 0,
          "ISOPOR": 0,
          "LATINHAS": 0,
          "METAL": 0,
          "MOTORZINHO": 0,
          "PAPEL BRANCO": 0,
          "PAPEL MISTO": 0,
          "PAPELAO": 0,
          "PEAD": 0,
          "PET BRANCO": 0,
          "PET VERDE": 0,
          "PLASTICO FINO": 0,
          "PVC": 0,
          "RAFIA": 0,
          "SUCATA": 0,
          "VIDRO": 0
        }
      });
      // Salva o perfil do usuário na coleção 'users'
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'role': UserRole.cooperativa.toString().split('.').last,
        'isAprovado': false, // Adicionado campo de aprovação
      });

      if (!mounted) return;

      // Mostra um alerta de sucesso e volta para a tela principal
      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Sucesso'),
            content: const Text('Usuário Criado'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(dialogContext).pop(), // Fecha o diálogo
              ),
            ],
          );
        },
      );

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      // Mostra erro de autenticação
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
      appBar: AppBar(title: const Text('Cadastro Cooperativa')),
      body: Form(
        key: _formKey,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.person, size: 100, color: Color.fromARGB(255, 29, 145, 64)),
                SizedBox(height: 20),
                // Campo Nome
                CustomTextFormField(
                  label: 'Nome Cooperativa',
                  controller: _nomeController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome obrigatório!';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
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
                SizedBox(height: 20),
                // Campo Email
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
                SizedBox(height: 20),
                // Dropdown para selecionar prefeitura (centralizado)
                Center(
                  child: SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      value: _selectedPrefeituraUid,
                      items: _prefeituras.map<DropdownMenuItem<String>>((pref) => DropdownMenuItem<String>(
                        value: pref['uid'] as String,
                        child: Text(pref['nome'] as String),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPrefeituraUid = value;
                        });
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.grey.shade200,
                        filled: true,
                        labelText: 'Selecione a Prefeitura',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Selecione uma prefeitura!';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Botão de cadastro
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
