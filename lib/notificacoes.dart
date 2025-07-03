// Este arquivo implementa a tela de notificações.
// Ele exibe uma mensagem padrão indicando que não há notificações disponíveis.

import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';

class Notificacoes extends StatefulWidget {
  const Notificacoes({super.key});

  @override
  State<Notificacoes> createState() => _NotificacoesState();
}

class _NotificacoesState extends State<Notificacoes> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: const Center(
        child: Text('No notifications available.'),
      ),
    );
  }
}
