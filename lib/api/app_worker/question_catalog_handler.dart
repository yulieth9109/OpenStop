import 'dart:async';
import 'package:flutter/material.dart';

import '/utils/service_worker.dart';
import '/models/question_catalog/question_catalog.dart';

mixin QuestionCatalogHandler<M> on ServiceWorker<M> {
  static final _completer = Completer<QuestionCatalog>();

  @mustCallSuper
  void updateQuestionCatalog(CatalogUpdatedData questionCatalogData) {
    if (_completer.isCompleted) {
      _questionCatalog = Future.value(questionCatalogData.questionCatalog);
    } else {
      _completer.complete(questionCatalogData.questionCatalog);
    }
  }

  var _questionCatalog = _completer.future;

  Future<QuestionCatalog> get questionCatalog => _questionCatalog;

}
