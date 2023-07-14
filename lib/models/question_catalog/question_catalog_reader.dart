import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'question_catalog.dart';

class QuestionCatalogReader {
  late Locale deviceLocale;
  final String defaultLocate;

  QuestionCatalogReader({this.defaultLocate = 'en'});

  Locale get _deviceLocale => PlatformDispatcher.instance.locale;

  Future<QuestionCatalog> read() async {
    final locales = await Future.wait([
      _readFile('assets/question_catalog/locales/$_deviceLocale.arb'),
      _readFile(
          'assets/question_catalog/locales/${_deviceLocale.languageCode}.arb'),
      _readFile('assets/question_catalog/locales/$defaultLocate.arb')
    ]);

    final questionCatalog = await _readFile(
        'assets/question_catalog/definition.json', (key, value) {
      if (value is String) {
        if (value.startsWith('@')) {
          for (final languagefiles in locales) {
            final localeString = languagefiles[value.substring(1)];
            if (localeString != null) {
              return localeString;
            }
          }
        }
      }
      return value;
    });

    return QuestionCatalog.fromJson(questionCatalog.cast<Map<String, dynamic>>());
  }

  Future<dynamic> _readFile(String path,
      [Object? Function(Object? key, Object? value)? reviver]) async {

    try {
      final jsonData = await rootBundle.load(path);
      return json.decode(utf8.decode(jsonData.buffer.asUint8List()), reviver: reviver);
    } catch (e) {
      return const <String, dynamic>{};
    }
  }
}
