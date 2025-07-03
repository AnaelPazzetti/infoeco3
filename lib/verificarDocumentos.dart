import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_service.dart'; // Import the new service

// Define DisplayItem classes
abstract class DisplayItem {
  String get id;
  String get name;
  bool get isFolder;
}

class FileItem extends DisplayItem {
  final Reference ref;
  @override
  String get id => ref.fullPath;
  @override
  String get name => ref.name;
  @override
  bool get isFolder => false;
  FileItem(this.ref);
}

class FolderItem extends DisplayItem {
  final Reference storagePrefixRef;
  String displayName;
  @override
  String get id => storagePrefixRef.name; // UID of the cooperado if it's a cooperado folder
  @override
  String get name => displayName;
  @override
  bool get isFolder => true;
  FolderItem(this.storagePrefixRef, this.displayName);
}

class VerificarDocumentos extends StatefulWidget {
  const VerificarDocumentos({super.key});

  @override
  State<VerificarDocumentos> createState() => _VerificarDocumentosState();
}

class _VerificarDocumentosState extends State<VerificarDocumentos> {
  List<DisplayItem> _displayItems = [];
  bool isLoading = true;
  UserProfileInfo? _userProfileInfo;
  final UserProfileService _userProfileService = UserProfileService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // For Cooperativa navigation
  String? _currentCooperadoIdForListing; // If set, we are viewing this Cooperado's files
  String _currentPathForDisplay = "";

  @override
  void initState() {
    super.initState();
    _carregarArquivos();
  }

  Future<void> _carregarArquivos() async {
    print("Carregando arquivos para: ${_currentCooperadoIdForListing ?? 'Cooperativa Root / Outro'}");
    setState(() { isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { isLoading = false; });
      return;
    }

    if (_userProfileInfo == null) { // Fetch profile only once or if needed
      try {
        _userProfileInfo = await _userProfileService.getUserProfileInfo();
        print('UserProfileInfo fetched: role=${_userProfileInfo?.role}, cooperativaUid=${_userProfileInfo?.cooperativaUid}, cooperadoUid=${_userProfileInfo?.cooperadoUid}');
      } catch (e) {
        print('Erro ao buscar perfil do usuário: $e');
        setState(() { isLoading = false; });
        return;
      }
    }

    String path;
    final cooperativaUid = _userProfileInfo!.cooperativaUid;
    final cooperadoUid = _userProfileInfo!.cooperadoUid;
    final isCooperado = _userProfileInfo!.role == UserRole.cooperado;
    final isCooperativa = _userProfileInfo!.role == UserRole.cooperativa;
    final isPrefeitura = _userProfileInfo!.role == UserRole.prefeitura;

    if (isCooperado && cooperativaUid != null && _userProfileInfo!.cooperadoUid != null) {
      path = 'Documentos/$cooperativaUid/${_userProfileInfo!.cooperadoUid}';
      _currentPathForDisplay = path;
    } else if (isCooperativa && cooperativaUid != null) {
      if (_currentCooperadoIdForListing != null) {
        path = 'Documentos/$cooperativaUid/$_currentCooperadoIdForListing';
        // Fetch cooperado name for display path
        String cooperadoDisplayName = await _getCooperadoName(cooperativaUid, _currentCooperadoIdForListing!);
        _currentPathForDisplay = "Cooperativa > $cooperadoDisplayName";
      } else {
        path = 'Documentos/$cooperativaUid';
        _currentPathForDisplay = "Cooperativa > Meus Arquivos";
      }
    } else if (isPrefeitura) { // Prefeitura logic remains recursive for now
      path = 'Documentos';
      _currentPathForDisplay = path;
    } else {
      print('Nenhum tipo de usuário detectado.');
      setState(() { isLoading = false; });
      return;
    }
    print('Tipo de usuário: isCooperado=${isCooperado}, isCooperativa=${isCooperativa}, isPrefeitura=${isPrefeitura}');
    print('Path detectado: $path');

    List<DisplayItem> items = [];
    try {
      final ListResult result = await FirebaseStorage.instance.ref(path).listAll();

      if (isPrefeitura) {
        print('Attempting to list root path for Prefeitura: $path');
        print('Prefeitura - Root list successful. Prefixes: ${result.prefixes.length}, Items: ${result.items.length}');
        for (final coopFolder in result.prefixes) {
          print('Prefeitura - Listing Cooperativa folder: ${coopFolder.fullPath}');
          // For simplicity, Prefeitura still sees a flat list of all files from all depths
          final coopResult = await coopFolder.listAll();
          print('Prefeitura - Cooperativa folder ${coopFolder.name} - Prefixes: ${coopResult.prefixes.length}, Items: ${coopResult.items.length}');
          for (final coopSub in coopResult.prefixes) {
            print('Prefeitura - Listing Cooperado sub-folder: ${coopSub.fullPath}');
            final subResult = await coopSub.listAll();
            print('Prefeitura - Cooperado sub-folder ${coopSub.name} - Items: ${subResult.items.length}');
            items.addAll(subResult.items.map((item) => FileItem(item)));
          }
          items.addAll(coopResult.items.map((item) => FileItem(item)));
        }
        items.addAll(result.items.map((item) => FileItem(item)));
      } else if (isCooperativa) {
        if (_currentCooperadoIdForListing == null) { // Viewing cooperativa's root
          // Add direct files of the cooperativa
          items.addAll(result.items.map((item) => FileItem(item)));
          // Add cooperado folders
          for (final prefix in result.prefixes) {
            String cooperadoName = await _getCooperadoName(cooperativaUid!, prefix.name);
            items.add(FolderItem(prefix, cooperadoName));
          }
        } else { // Viewing a specific cooperado's folder
          items.addAll(result.items.map((item) => FileItem(item)));
        }
      } else if (isCooperado) {
        print('Attempting to list path for Cooperado: $path');
        print('Cooperado - List successful. Items: ${result.items.length}');
        items.addAll(result.items.map((item) => FileItem(item)));
      }
    } catch (e) {
      print('Erro ao listar arquivos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao listar arquivos: ${e.toString()}')),
        );
      }
    }
    print('Itens para display: ${items.length}');
    setState(() {
      _displayItems = items;
      isLoading = false;
    });
  }

  Future<String> _getCooperadoName(String cooperativaUid, String cooperadoUidToFind) async {
    try {
      final prefeiturasSnapshot = await _firestore.collection('prefeituras').get();
      for (final prefeituraDoc in prefeiturasSnapshot.docs) {
        final cooperativaDocRef = prefeituraDoc.reference.collection('cooperativas').doc(cooperativaUid);
        // Check if this cooperativa (cooperativaUid) exists under this prefeitura
        // This check (cooperativaSnapshot.exists) is important if a cooperativaUid might not be under all prefeituras
        // However, if cooperativaUid is globally unique and we know it exists, we can directly try to get the cooperado.
        // For robustness, let's assume we need to find which prefeitura hosts this cooperativa.
        final cooperativaSnapshot = await cooperativaDocRef.get();
        if (cooperativaSnapshot.exists) {
          final cooperadoDoc = await cooperativaDocRef.collection('cooperados').doc(cooperadoUidToFind).get();
          if (cooperadoDoc.exists && cooperadoDoc.data() != null && cooperadoDoc.data()!.containsKey('nome')) {
            return cooperadoDoc.data()!['nome'] as String;
          }
          // Found the correct cooperativa, so if cooperado not found here, it's not found.
          break;
        }
      }
    } catch (e) {
      print("Error fetching cooperado name for $cooperadoUidToFind: $e");
    }
    return cooperadoUidToFind; // Fallback to UID
  }

  Future<void> _handleItemTap(DisplayItem item) async {
    if (item.isFolder) {
      // Navigate into folder for Cooperativa
      if (_userProfileInfo?.role == UserRole.cooperativa) {
        setState(() {
          _currentCooperadoIdForListing = item.id; // item.id is cooperadoUID for FolderItem
        });
        _carregarArquivos();
      }
      // Potentially handle folder taps for Prefeitura here if needed for navigation
    } else if (item is FileItem) {
      final url = await item.ref.getDownloadURL();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Download do Arquivo'),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  Widget celulaHeader(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: Colors.grey[300],
      child: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Adiciona método para confirmar e excluir arquivo
  void _confirmDeleteFile(DisplayItem item) async {
    if (item is! FileItem) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir arquivo'),
        content: Text('Tem certeza que deseja excluir "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await item.ref.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arquivo "${item.name}" excluído com sucesso.')),
        );
        _carregarArquivos();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir arquivo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar Documentos')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth * 0.8;
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: tableWidth),
                      child: Table(
                        columnWidths: const <int, TableColumnWidth>{
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(1.5),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.5),
                        },
                        border: TableBorder.all(color: Colors.black),
                        children: [
                          TableRow(children: [
                            celulaHeader('Documento'),
                            celulaHeader('Data de Upload'),
                            celulaHeader('Tipo'),
                            celulaHeader('Ações'),
                          ]),
                          for (final item in _displayItems)
                            TableRow(children: [
                              // Documento (icon + name)
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  children: [
                                    Icon(item.isFolder ? Icons.folder : Icons.insert_drive_file, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Data de Upload (only for files)
                              Center(
                                child: item.isFolder
                                    ? const Text('-', style: TextStyle(fontSize: 14))
                                    : FutureBuilder<FullMetadata>(
                                        future: (item as FileItem).ref.getMetadata(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const SizedBox(width: 24, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
                                          }
                                          if (snapshot.hasData && snapshot.data?.timeCreated != null) {
                                            final dt = snapshot.data!.timeCreated!;
                                            final formatted = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                                            return Text(formatted, style: const TextStyle(fontSize: 14));
                                          }
                                          return const Text('-', style: TextStyle(fontSize: 14));
                                        },
                                      ),
                              ),
                              // Tipo (extension or Pasta)
                              Center(
                                child: Text(
                                  item.isFolder
                                    ? 'Pasta'
                                    : (item.name.contains('.') ? '.${item.name.split('.').last}' : 'Arquivo'),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              // Ações
                              Center(
                                child: item.isFolder
                                    ? ElevatedButton(
                                        onPressed: () => _handleItemTap(item),
                                        child: const Text('Abrir'),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.download),
                                            onPressed: () => _handleItemTap(item),
                                            tooltip: 'Baixar',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _confirmDeleteFile(item),
                                            tooltip: 'Excluir',
                                          ),
                                        ],
                                      ),
                              ),
                            ]),
                        ],
                      ),
                    ),
                    // ...existing code...
                  ],
                ),
              ),
            ),
          );
        },
      ),
      // ...existing code...
    );
  }
}
