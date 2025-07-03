// Este arquivo é o ponto de entrada principal do aplicativo.
// Ele inicializa o Firebase e define a tela inicial do aplicativo.

import 'package:flutter/material.dart';
import 'package:infoeco3/cadastro.dart';
import 'package:infoeco3/phone_auth.dart'; // Import the phone authentication screen
import 'login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:infoeco3/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InfoEco',
      theme: ThemeData(
        primarySwatch: Colors.green, // Cor primária
        // Define um tema global para todos os ElevatedButtons no aplicativo.
        // Isso atende à diretriz 'code_reuse', evitando a repetição de ButtonStyle.
        elevatedButtonTheme: ElevatedButtonThemeData( // Keep the theme data structure
          style: ElevatedButton.styleFrom( // Use ElevatedButton.styleFrom for modern approach
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), // Keep rounded corners
            // Remove fixed minimumSize here to allow buttons to be responsive
          ), 
        ),
      ),
      home: const MyHomePage(title: 'InfoEco'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    // Remover validação de aprovação do cooperado daqui
  }

  @override
  Widget build(BuildContext context) {
    // Implement PopScope to handle back button press on the initial screen
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (didPop) async {
        if (didPop) return; // If system already popped, do nothing
        final bool confirmExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Saída'),
            content: const Text('Você tem certeza que deseja sair do aplicativo?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sair'),
              ),
            ],
          ),
        ) ?? false; // Handle null if dialog dismissed

        if (confirmExit) {
          // This is the root screen, so exiting the app.
          // In a real app, you might want to use SystemNavigator.pop() or exit(0)
          // but for Flutter's navigation stack, simply allowing the pop is usually enough
          // if there's nothing below it. For explicit app exit, platform channels might be needed.
          // For now, we'll just let the default system back behavior take over if confirmed.
          // Or, if this is the very first screen, Navigator.pop() will close the app.
          // Since we set canPop: false, we need to explicitly pop if confirmed.
          if (mounted) {
            Navigator.of(context).pop(); // This will close the app if it's the last route
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(
                image: const AssetImage(
                  'assets/img/LogoNome.png',
                ),
                width: 250,
                height: 250,
              ),
              const Padding(padding: EdgeInsets.all(10)),
              const Padding(padding: EdgeInsets.only(bottom: 70)),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Login())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(300, 75), // Re-apply specific size if needed, or remove for full responsiveness
                ),
                child: const Text('INICIAR SESSÃO', style: TextStyle(color: Colors.white)),
              ),
              const Padding(padding: EdgeInsets.all(10)),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Cadastro())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(300, 75), // Re-apply specific size if needed, or remove for full responsiveness
                ),
                child: const Text('CRIAR CONTA', style: TextStyle(color: Colors.white)),
              ),
              const Padding(padding: EdgeInsets.all(10)),
              // Botão para login com telefone usando Firebase Auth
              // Leva o usuário para a tela de autenticação por telefone (PhoneAuthScreen)
              // ElevatedButton(
              //   onPressed: () {
              //     Navigator.push(context,
              //         MaterialPageRoute(builder: (context) => PhoneAuthScreen()));
              //   },
              //   style: ButtonStyle(
              //       minimumSize: WidgetStateProperty.all(const Size(300, 75)),
              //       backgroundColor: WidgetStateProperty.all(Colors.blue),
              //       shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              //           RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(10.0),
              //       ))),
              //   child: Text('LOGIN COM TELEFONE',
              //       style: TextStyle(color: Colors.white)),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
