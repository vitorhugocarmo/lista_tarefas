import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ListaTarefasApp());
}

// MODELO DA TAREFA
class Tarefa {
  String titulo;
  bool concluida;

  Tarefa({
    required this.titulo,
    this.concluida = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'concluida': concluida,
    };
  }

  factory Tarefa.fromJson(Map<String, dynamic> json) {
    return Tarefa(
      titulo: json['titulo'] as String,
      concluida: json['concluida'] as bool,
    );
  }
}

// APLICATIVO
class ListaTarefasApp extends StatelessWidget {
  const ListaTarefasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lista de Tarefas',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD71920),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      home: const TelaTarefas(),
    );
  }
}

// TELA PRINCIPAL
class TelaTarefas extends StatefulWidget {
  const TelaTarefas({super.key});

  @override
  State<TelaTarefas> createState() => _TelaTarefasState();
}

class _TelaTarefasState extends State<TelaTarefas> {
  static const Color vermelho = Color(0xFFD71920);
  static const Color escuro = Color(0xFF202632);
  static const String chaveTarefas = 'minhas_tarefas';

  final SharedPreferencesAsync preferencias =
      SharedPreferencesAsync();

  final TextEditingController controlador =
      TextEditingController();

  final List<Tarefa> tarefas = [];

  bool carregando = true;
  bool salvando = false;

  int get total => tarefas.length;

  int get concluidas =>
      tarefas.where((tarefa) => tarefa.concluida).length;

  int get pendentes => total - concluidas;

  @override
  void initState() {
    super.initState();
    carregarTarefas();
  }

  @override
  void dispose() {
    controlador.dispose();
    super.dispose();
  }

  // RECUPERAR TAREFAS ARMAZENADAS
  Future<void> carregarTarefas() async {
    try {
      final String? dados =
          await preferencias.getString(chaveTarefas);

      final List<Tarefa> recuperadas = [];

      if (dados != null) {
        final List<dynamic> lista = jsonDecode(dados);

        for (final item in lista) {
          recuperadas.add(
            Tarefa.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        tarefas
          ..clear()
          ..addAll(recuperadas);
        carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      mostrarMensagem(
        'Não foi possível carregar as tarefas.',
        erro: true,
      );
    }
  }

  // SALVAR TAREFAS LOCALMENTE
  Future<bool> salvarTarefas() async {
    try {
      final String dados = jsonEncode(
        tarefas.map((tarefa) => tarefa.toJson()).toList(),
      );

      await preferencias.setString(chaveTarefas, dados);

      return true;
    } catch (erro) {
      mostrarMensagem(
        'Erro ao salvar as tarefas.',
        erro: true,
      );
      return false;
    }
  }

  // CADASTRAR NOVA TAREFA
  Future<void> adicionarTarefa() async {
    final String titulo = controlador.text.trim();

    if (salvando) return;

    if (titulo.isEmpty) {
      mostrarMensagem(
        'Digite um título para a tarefa.',
        erro: true,
      );
      return;
    }

    setState(() {
      salvando = true;
      tarefas.insert(
        0,
        Tarefa(titulo: titulo),
      );
    });

    final bool sucesso = await salvarTarefas();

    if (!mounted) return;

    setState(() {
      if (sucesso) {
        controlador.clear();
      } else {
        tarefas.removeAt(0);
      }
      salvando = false;
    });

    if (sucesso) {
      FocusScope.of(context).unfocus();
      mostrarMensagem('Tarefa adicionada!');
    }
  }

  // MARCAR OU DESMARCAR CONCLUSÃO
  Future<void> alterarConclusao(int indice) async {
    if (salvando) return;

    setState(() {
      salvando = true;
      tarefas[indice].concluida =
          !tarefas[indice].concluida;
    });

    final bool sucesso = await salvarTarefas();

    if (!mounted) return;

    setState(() {
      if (!sucesso) {
        tarefas[indice].concluida =
            !tarefas[indice].concluida;
      }
      salvando = false;
    });
  }

  // EXCLUIR TAREFA
  Future<void> excluirTarefa(int indice) async {
    if (salvando) return;

    final Tarefa removida = tarefas[indice];

    setState(() {
      salvando = true;
      tarefas.removeAt(indice);
    });

    final bool sucesso = await salvarTarefas();

    if (!mounted) return;

    setState(() {
      if (!sucesso) {
        tarefas.insert(indice, removida);
      }
      salvando = false;
    });

    if (sucesso) {
      mostrarMensagem('Tarefa excluída.');
    }
  }

  // EDITAR TAREFA - MELHORIA EXTRA
  Future<void> editarTarefa(int indice) async {
    if (salvando) return;

    final TextEditingController edicao =
        TextEditingController(
      text: tarefas[indice].titulo,
    );

    final String? novoTitulo = await showDialog<String>(
      context: context,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Editar tarefa'),
          content: TextField(
            controller: edicao,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Título da tarefa',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (valor) {
              Navigator.pop(contexto, valor.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  contexto,
                  edicao.text.trim(),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    edicao.dispose();

    if (!mounted || novoTitulo == null) return;

    if (novoTitulo.isEmpty) {
      mostrarMensagem(
        'O título não pode ficar vazio.',
        erro: true,
      );
      return;
    }

    final String tituloAnterior = tarefas[indice].titulo;

    setState(() {
      salvando = true;
      tarefas[indice].titulo = novoTitulo;
    });

    final bool sucesso = await salvarTarefas();

    if (!mounted) return;

    setState(() {
      if (!sucesso) {
        tarefas[indice].titulo = tituloAnterior;
      }
      salvando = false;
    });

    if (sucesso) {
      mostrarMensagem('Tarefa atualizada!');
    }
  }

  // LIMPAR CONCLUÍDAS - MELHORIA EXTRA
  Future<void> limparConcluidas() async {
    if (salvando || concluidas == 0) return;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) {
        return AlertDialog(
          title: const Text('Limpar concluídas?'),
          content: const Text(
            'Todas as tarefas concluídas serão removidas.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(contexto, true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmar != true) return;

    final List<Tarefa> anteriores =
        List<Tarefa>.from(tarefas);

    setState(() {
      salvando = true;
      tarefas.removeWhere((tarefa) => tarefa.concluida);
    });

    final bool sucesso = await salvarTarefas();

    if (!mounted) return;

    setState(() {
      if (!sucesso) {
        tarefas
          ..clear()
          ..addAll(anteriores);
      }
      salvando = false;
    });

    if (sucesso) {
      mostrarMensagem('Tarefas concluídas removidas.');
    }
  }

  // MENSAGENS
  void mostrarMensagem(
    String mensagem, {
    bool erro = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor:
            erro ? const Color(0xFFB42318) : escuro,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // CARTÃO DE ESTATÍSTICA
  Widget indicador({
    required String titulo,
    required int valor,
    required IconData icone,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFE8E9EC),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor, size: 23),
            const SizedBox(height: 12),
            Text(
              '$valor',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: escuro,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ITEM DA LISTA
  Widget construirTarefa(int indice) {
    final Tarefa tarefa = tarefas[indice];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tarefa.concluida
              ? const Color(0xFFD5EEE0)
              : const Color(0xFFE8E9EC),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: tarefa.concluida,
            activeColor: const Color(0xFF218653),
            onChanged: salvando
                ? null
                : (_) => alterarConclusao(indice),
          ),
          Expanded(
            child: InkWell(
              onTap: salvando
                  ? null
                  : () => alterarConclusao(indice),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 9,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarefa.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: tarefa.concluida
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: tarefa.concluida
                            ? Colors.grey
                            : escuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tarefa.concluida
                          ? 'Concluída'
                          : 'Pendente',
                      style: TextStyle(
                        fontSize: 12,
                        color: tarefa.concluida
                            ? const Color(0xFF218653)
                            : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Editar tarefa',
            onPressed: salvando
                ? null
                : () => editarTarefa(indice),
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
            ),
            color: Colors.blueGrey,
          ),
          IconButton(
            tooltip: 'Excluir tarefa',
            onPressed: salvando
                ? null
                : () => excluirTarefa(indice),
            icon: const Icon(
              Icons.delete_outline,
              size: 21,
            ),
            color: vermelho,
          ),
        ],
      ),
    );
  }

  // INTERFACE PRINCIPAL
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: vermelho,
            ),
            SizedBox(width: 10),
            Text(
              'TaskFlow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: escuro,
              ),
            ),
          ],
        ),
      ),

      body: carregando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 650),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // CABEÇALHO
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: vermelho,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.task_alt,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Organize seu dia.',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Gerencie suas tarefas e acompanhe '
                            'seu progresso. Seus dados ficam '
                            'salvos neste dispositivo.',
                            style: TextStyle(
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // INDICADORES
                    Row(
                      children: [
                        indicador(
                          titulo: 'Total',
                          valor: total,
                          icone: Icons.list_alt_outlined,
                          cor: vermelho,
                        ),
                        const SizedBox(width: 10),
                        indicador(
                          titulo: 'Pendentes',
                          valor: pendentes,
                          icone: Icons.schedule,
                          cor: Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        indicador(
                          titulo: 'Concluídas',
                          valor: concluidas,
                          icone: Icons.check_circle_outline,
                          cor: Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Nova tarefa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: escuro,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // CADASTRO
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: controlador,
                            maxLength: 100,
                            textInputAction:
                                TextInputAction.done,
                            onSubmitted: (_) =>
                                adicionarTarefa(),
                            decoration: InputDecoration(
                              hintText:
                                  'O que você precisa fazer?',
                              prefixIcon: const Icon(
                                Icons.edit_note,
                              ),
                              filled: true,
                              fillColor:
                                  const Color(0xFFF5F6F8),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: salvando
                                  ? null
                                  : adicionarTarefa,
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Adicionar tarefa',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: vermelho,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // TÍTULO DA LISTA
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Minhas tarefas',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: escuro,
                            ),
                          ),
                        ),
                        if (concluidas > 0)
                          TextButton(
                            onPressed: salvando
                                ? null
                                : limparConcluidas,
                            child: const Text(
                              'Limpar concluídas',
                              style: TextStyle(
                                color: vermelho,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // LISTA OU ESTADO VAZIO
                    if (tarefas.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(42),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 55,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nenhuma tarefa cadastrada',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: escuro,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Adicione sua primeira tarefa '
                              'para começar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        itemCount: tarefas.length,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, indice) {
                          return construirTarefa(indice);
                        },
                      ),

                    const SizedBox(height: 30),

                    const Center(
                      child: Text(
                        'TaskFlow • Flutter + Shared Preferences',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
