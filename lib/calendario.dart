// Este arquivo implementa a funcionalidade de calendário.
// Ele permite que o usuário adicione e visualize lembretes em um calendário interativo.

import 'package:flutter/material.dart';
import 'package:infoeco3/menu.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa o Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Importa o FirebaseAuth
import 'user_profile_service.dart'; // Importa o serviço de perfil de usuário

// O calendário é baseado na biblioteca table_calendar, que permite a personalização do calendário e a adição de eventos.
// O usuário pode adicionar eventos clicando em um dia específico e preenchendo um formulário com o título e a descrição do evento.
// Os eventos são armazenados em um mapa, onde a chave é a data do evento e o valor é uma lista de eventos para essa data.
void Calendario_() {
  initializeDateFormatting().then((_) {
    runApp(const Calendario());
  });
}

class Calendario extends StatefulWidget {
  const Calendario({Key? key}) : super(key: key);

  @override
  _Calendario createState() => _Calendario();
}

class _Calendario extends State<Calendario> {
  final todaysDate = DateTime.now();
  var _focusedCalendarDate = DateTime.now();
  final _initialCalendarDate = DateTime(2024);
  final _lastCalendarDate = DateTime(2100);
  DateTime? selectedCalendarDate;
  final titleController = TextEditingController();
  final descpController = TextEditingController();

  late Map<DateTime, List<MyEvents>> mySelectedEvents;
  late CollectionReference eventosRef; // Referência para a coleção no Firestore
  final UserProfileService _userProfileService = UserProfileService();

  bool _isCooperativa = false; // Flag para saber se o usuário é cooperativa
  String? _cooperativaUid;
  String? _prefeituraUid;

  @override
  void initState() {
    super.initState();
    selectedCalendarDate = _focusedCalendarDate;
    mySelectedEvents = {};
    _loadUserProfileAndEvents();
  }

  // Função utilitária para normalizar datas (apenas ano/mês/dia)
  DateTime _normalizarData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }
  
  // Carrega o perfil do usuário e, em seguida, os eventos do calendário
  Future<void> _loadUserProfileAndEvents() async {
    final profile = await _userProfileService.getUserProfileInfo();
    if (profile.role == UserRole.cooperativa || profile.role == UserRole.cooperado) {
      setState(() {
        _cooperativaUid = profile.cooperativaUid;
        _prefeituraUid = profile.prefeituraUid;
        _isCooperativa = profile.role == UserRole.cooperativa;
      });
      _carregarEventosFirestore();
    }
  }

  // Função para carregar eventos do Firestore da subcoleção correta
  void _carregarEventosFirestore() async {
    if (_cooperativaUid == null || _prefeituraUid == null) return;
    eventosRef = FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(_cooperativaUid)
        .collection('eventos_calendario');
    eventosRef.snapshots().listen((snapshot) {
      Map<DateTime, List<MyEvents>> eventosTemp = {};
      for (var doc in snapshot.docs) {
        // Converte a data salva em string para DateTime e normaliza
        DateTime data = _normalizarData(DateTime.parse(doc['data']));
        MyEvents evento = MyEvents(
          eventTitle: doc['titulo'],
          eventDescp: doc['descricao'],
        );
        if (eventosTemp[data] == null) {
          eventosTemp[data] = [evento];
        } else {
          eventosTemp[data]!.add(evento);
        }
      }
      setState(() {
        mySelectedEvents = eventosTemp;
      });
    });
  }

  // Adiciona evento na subcoleção correta
  Future<void> _adicionarEventoFirestore(DateTime data, MyEvents evento) async {
    if (_cooperativaUid == null || _prefeituraUid == null) return;
    final dataNormalizada = _normalizarData(data);
    await FirebaseFirestore.instance
        .collection('prefeituras')
        .doc(_prefeituraUid)
        .collection('cooperativas')
        .doc(_cooperativaUid)
        .collection('eventos_calendario')
        .add({
      'data': dataNormalizada.toIso8601String(),
      'titulo': evento.eventTitle,
      'descricao': evento.eventDescp,
    });
  }

  // Retorna lista de eventos para o dia normalizado
  List<MyEvents> _listOfDayEvents(DateTime dateTime) {
    final dataNormalizada = _normalizarData(dateTime);
    return mySelectedEvents[dataNormalizada] ?? [];
  }

  _showAddEventDialog() async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Novo lembrete'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildTextField(
                      controller: titleController, hint: 'Insira o título'),
                  const SizedBox(
                    height: 20.0,
                  ),
                  buildTextField(
                      controller: descpController, hint: 'Insira a descrição'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty &&
                        descpController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Insira o título e a descrição!'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    } else {
                      final novoEvento = MyEvents(
                        eventTitle: titleController.text,
                        eventDescp: descpController.text,
                      );
                      await _adicionarEventoFirestore(selectedCalendarDate!, novoEvento); // Salva no Firestore
                      titleController.clear();
                      descpController.clear();
                      Navigator.pop(context);
                      return;
                    }
                  },
                  child: const Text('Adicionar'),
                ),
              ],
            ));
  }

  Widget buildTextField(
      {String? hint, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: hint ?? '',
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.green, width: 1.5),
          borderRadius: BorderRadius.circular(
            10.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.green, width: 1.5),
          borderRadius: BorderRadius.circular(
            10.0,
          ),
        ),
      ),
    );
  }

  // Formata a data para exibição
  String _formatarData(DateTime data) {
    return "${data.day}/${data.month}/${data.year}";
  }

  // Retorna eventos dos próximos 15 dias a partir da data atual
  List<EventoData> _eventosProximos15Dias() {
    List<EventoData> eventosFuturos = [];
    DateTime dataLimite = todaysDate.add(const Duration(days: 15));
    mySelectedEvents.forEach((data, eventos) {
      if (data.isAfter(todaysDate) && data.isBefore(dataLimite)) {
        for (var evento in eventos) {
          eventosFuturos.add(EventoData(data: data, event: evento));
        }
      }
    });
    return eventosFuturos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(20),
              elevation: 5.0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
                side: BorderSide(color: Colors.green, width: 2.0),
              ),
              child: TableCalendar(
                //locale: 'pt_BR',
                focusedDay: _focusedCalendarDate,
                firstDay: _initialCalendarDate,
                lastDay: _lastCalendarDate,
                calendarFormat: CalendarFormat.month,
                weekendDays: const [DateTime.sunday, DateTime.saturday],
                startingDayOfWeek: StartingDayOfWeek.sunday,
                daysOfWeekHeight: 40.0,
                rowHeight: 60.0,
                eventLoader: _listOfDayEvents,
                headerStyle: const HeaderStyle(
                  titleTextStyle:
                      TextStyle(color: Colors.orange, fontSize: 20.0),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10))),
                  formatButtonTextStyle:
                      TextStyle(color: Colors.white, fontSize: 16.0),
                  formatButtonDecoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(
                      Radius.circular(5.0),
                    ),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Colors.orange,
                    size: 28,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekendStyle: TextStyle(color: Colors.orange),
                ),
                calendarStyle: const CalendarStyle(
                  weekendTextStyle: TextStyle(color: Colors.orange),
                  todayDecoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                ),
                selectedDayPredicate: (currentSelectedDate) {
                  return (isSameDay(
                      selectedCalendarDate!, currentSelectedDate));
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(selectedCalendarDate, selectedDay)) {
                    setState(() {
                      selectedCalendarDate = selectedDay;
                      _focusedCalendarDate = focusedDay;
                    });
                  }
                },
              ),
            ),
            // Exibe eventos do dia selecionado (oculta se for hoje ou se não houver eventos)
            if (!(isSameDay(selectedCalendarDate, todaysDate) || _listOfDayEvents(selectedCalendarDate!).isEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eventos do dia selecionado:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    ..._listOfDayEvents(selectedCalendarDate!).map(
                      (myEvents) => ListTile(
                        leading: const Icon(
                          Icons.event,
                          color: Colors.greenAccent,
                        ),
                        title: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text('Título: ${myEvents.eventTitle}'),
                        ),
                        subtitle: Text(
                          'Descrição: ${myEvents.eventDescp}\nData: ${_formatarData(selectedCalendarDate!)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Exibe eventos do dia atual (today)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eventos de hoje (${_formatarData(todaysDate)}):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  ...(_listOfDayEvents(todaysDate).isNotEmpty
                      ? _listOfDayEvents(todaysDate).map(
                          (myEvents) => ListTile(
                                leading: const Icon(
                                  Icons.today,
                                  color: Colors.blue,
                                ),
                                title: Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text('Título: ${myEvents.eventTitle}'),
                                ),
                                subtitle: Text(
                                  'Descrição: ${myEvents.eventDescp}\nData: ${_formatarData(todaysDate)}',
                                ),
                              ))
                      : [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                            child: Text('Nenhum evento marcado para hoje.'),
                          )
                        ]),
                ],
              ),
            ),
            // Exibe eventos dos próximos 15 dias a partir da data atual
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Próximos 15 dias:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  ..._eventosProximos15Dias().map(
                    (eventoData) => ListTile(
                      leading: const Icon(
                        Icons.event_available,
                        color: Colors.orange,
                      ),
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text('Título: ${eventoData.event.eventTitle}'),
                      ),
                      subtitle: Text(
                        'Descrição: ${eventoData.event.eventDescp}\nData: ${_formatarData(eventoData.data)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(padding: EdgeInsets.all(10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCooperativa)
                  FloatingActionButton.extended(
                    onPressed: () => _showAddEventDialog(),
                    label: const Text('Adicionar lembrete'),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class MyEvents {
  final String eventTitle;
  final String eventDescp;

  MyEvents({required this.eventTitle, required this.eventDescp});

  @override
  String toString() => eventTitle;
}

// Classe para representar os dados do evento com a data associada
class EventoData {
  final DateTime data;
  final MyEvents event;

  EventoData({required this.data, required this.event});
}
