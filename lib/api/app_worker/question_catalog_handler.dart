import 'dart:async';
import '/utils/service_worker.dart';
import '/models/question_catalog/question_catalog.dart';

mixin QuestionCatalogHandler<M> on ServiceWorker<M> {
  static final _completer = Completer<QuestionCatalog>();

  void takeQuestionCatalogAsset(QuestionCatalog questionCatalog) {
    _completer.complete(questionCatalog);
  }

  var _questionCatalog = _completer.future;

  Future<QuestionCatalog> get questionCatalog => _questionCatalog;

  /// Note: currently this won't update any existing questionnaires.
  /// Only the creation of subsequent questionnaires will be affected by this.

  Future<void> updateQuestionCatalogPreferences({required bool excludeProfessional}) async {
    final qc = await _questionCatalog;
    _questionCatalog = Future.value(
      qc.copyWith(excludeProfessional: excludeProfessional),
    );
  }
}
