import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuestionCatalogReader {
  String deviceLocale = Platform.localeName;
  final defaultLocate = 'en';

  Future<String> read() async {
    dynamic jsonStringQuestionCatalog;
    dynamic localizationsDeviceLanguage;
    dynamic localizationsLanguageCode;
    dynamic localizationsDefaultLanguage;
    dynamic questionCatalog = '';

    await readFile(0).then((jsonMap) {
      jsonStringQuestionCatalog = jsonMap;
    });

    await readFile(1).then((jsonMap) {
      localizationsDeviceLanguage = jsonMap;
    });
    await readFile(2).then((jsonMap) {
      localizationsLanguageCode = jsonMap;
    });
    await readFile(3).then((jsonMap) {
      localizationsDefaultLanguage = jsonMap;
    });

    if (jsonStringQuestionCatalog != null) {
      questionCatalog =
          json.decode(jsonStringQuestionCatalog, reviver: (key, value) {
        if (value is String) {
          if (value.startsWith('@')) {
            if (localizationsDeviceLanguage is Map &&
                localizationsDeviceLanguage[value.substring(1)] != null) {
              return localizationsDeviceLanguage[value.substring(1)];
            } else if (localizationsLanguageCode is Map &&
                localizationsLanguageCode[value.substring(1)] != null) {
              return localizationsLanguageCode[value.substring(1)];
            } else if (localizationsDefaultLanguage is Map &&
                localizationsDefaultLanguage[value.substring(1)] != null) {
              return localizationsDefaultLanguage![value.substring(1)];
            }
          }
        }
        return value;
      });
    }
    return json.encode(questionCatalog);
  }

  Future<dynamic> readFile(int number) async {
    ByteData jsonData;
    print('systemLocale $deviceLocale');
    try {
      switch (number) {
        case 0:
          jsonData =
              await rootBundle.load('assets/question_catalog/definition.json');
          return utf8.decode(jsonData.buffer.asUint8List());
        case 1:
          jsonData = await rootBundle
              .load('assets/question_catalog/locales/$deviceLocale.arb');
          return json.decode(utf8.decode(jsonData.buffer.asUint8List()));
        case 2:
          final languageCode = deviceLocale.substring(0, 2);
          print('languageCode $languageCode');
          jsonData = await rootBundle
              .load('assets/question_catalog/locales/$languageCode.arb');
          return json.decode(utf8.decode(jsonData.buffer.asUint8List()));
        case 3:
          jsonData = await rootBundle
              .load('assets/question_catalog/locales/$defaultLocate.arb');
          return json.decode(utf8.decode(jsonData.buffer.asUint8List()));
      }
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }
}
