// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'tasks_module_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class TasksModuleLocalizationsPt extends TasksModuleLocalizations {
  TasksModuleLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tasksTitle => 'Tarefas';

  @override
  String get hideCompleted => 'Esconder concluídas';

  @override
  String get showCompleted => 'Mostrar concluídas';

  @override
  String get newTaskLabel => 'Nova tarefa';

  @override
  String get add => 'Adicionar';

  @override
  String get emptyTitle => 'Escreva um título para a tarefa.';

  @override
  String get titleTooLong => 'O título passou do tamanho máximo.';

  @override
  String get taskGone => 'Esta tarefa não está mais na lista.';

  @override
  String get taskGoneTitle => 'Esta tarefa não está mais na lista';

  @override
  String get refreshFailed =>
      'Não foi possível atualizar agora. A lista do aparelho continua aqui.';

  @override
  String get unexpectedError => 'Algo deu errado. Tente de novo.';

  @override
  String get emptyListTitle => 'Nenhuma tarefa por aqui';

  @override
  String get emptyListMessage => 'Escreva a primeira no campo acima.';

  @override
  String get edit => 'Editar';

  @override
  String conflictsNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alterações precisam da sua decisão',
      one: '1 alteração precisa da sua decisão',
      zero: 'Nenhuma alteração precisa da sua decisão',
    );
    return '$_temp0';
  }

  @override
  String get resolve => 'Resolver';

  @override
  String get loadFailedTitle => 'Não foi possível carregar as tarefas';

  @override
  String get loadFailedMessage =>
      'A primeira lista vem do servidor. Confira a conexão.';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get taskTitle => 'Tarefa';

  @override
  String get taskTitleLabel => 'Título';

  @override
  String get save => 'Salvar';

  @override
  String get archive => 'Arquivar';

  @override
  String get archiveTitle => 'Arquivar tarefa?';

  @override
  String get archiveMessage =>
      'Ela sai da lista. Neste aparelho, não há como desfazer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get conflictsTitle => 'Alterações não aceitas';

  @override
  String get noConflicts => 'Nada esperando a sua decisão';

  @override
  String get conflictsOffline =>
      'Sem conexão com o servidor. Tente quando ela voltar.';

  @override
  String get conflictChangedElsewhere => 'Esta tarefa mudou em outro lugar';

  @override
  String get conflictRejected => 'O servidor recusou esta alteração';

  @override
  String taskSummary(String title, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'open': 'aberta',
      'done': 'concluída',
      'archived': 'arquivada',
      'other': '$status',
    });
    return '\"$title\", $_temp0';
  }

  @override
  String onDevice(String task) {
    return 'No aparelho: $task';
  }

  @override
  String onServer(String task) {
    return 'No servidor: $task';
  }

  @override
  String get fetchingServer => 'Buscando a versão do servidor…';

  @override
  String get serverGone => 'No servidor: a tarefa não existe mais.';

  @override
  String get serverUnavailable =>
      'Sem conexão para buscar a versão do servidor.';

  @override
  String get keepMine => 'Manter a minha';

  @override
  String get keepServer => 'Manter a do servidor';

  @override
  String get redo => 'Refazer';

  @override
  String get discard => 'Descartar';

  @override
  String get discardTitle => 'Descartar a alteração?';

  @override
  String get discardMessage =>
      'O que você fez nesta tarefa será apagado deste aparelho, e a versão do servidor volta na próxima atualização.';
}
