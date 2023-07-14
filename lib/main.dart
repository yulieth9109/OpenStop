import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:ui' as ui;

import '/commons/themes.dart';
import '/commons/app_config.dart' as app_config;
import '/commons/routes.dart';
import '/api/preferences_service.dart';
import '/api/app_worker/app_worker_interface.dart';
import 'models/question_catalog/question_catalog_reader.dart';

Future <void> main() async {
  // this is required to run flutter dependent code before runApp is called
  // in this case SharedPreferences requires this
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final futures = await Future.wait([
    AppWorkerInterface.spawn(),
    SharedPreferences.getInstance(),
  ]);

  final QuestionCatalogReader questionCatalogReader = QuestionCatalogReader();

  ui.PlatformDispatcher.instance.onLocaleChanged = () async {
    await questionCatalogReader.read();
  };



  GetIt.I
      .registerSingleton<AppWorkerInterface>(futures[0] as AppWorkerInterface);
  GetIt.I.registerSingleton<PreferencesService>(
    PreferencesService(preferences: futures[1] as SharedPreferences),
  );

  
  GetIt.I.get<AppWorkerInterface>().updateQuestionCatalog(questionCatalog: await questionCatalogReader.read(),);

  // required because isolate cannot read assets
  // https://github.com/flutter/flutter/issues/96895
  Future.wait([rootBundle.load('assets/datasets/map_feature_collection.json')])
      .then(GetIt.I.get<AppWorkerInterface>().passAssets);

  reaction((p0) => GetIt.I.get<PreferencesService>().isProfessional, (value) {
    GetIt.I.get<AppWorkerInterface>().updateQuestionCatalogPreferences(
      excludeProfessional: !value,
    );
  }, fireImmediately: true);

  runApp(const MyApp());
}

class MyApp extends StatelessObserverWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preferenceService = GetIt.I.get<PreferencesService>();
    final themeMode = preferenceService.themeMode;
    final hasSeenOnboarding = preferenceService.hasSeenOnboarding;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: app_config.appName,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // used instead of home: because otherwise no pop page transition to the first screen will be applied
      onGenerateRoute: (settings) => hasSeenOnboarding ? Routes.home : Routes.onboarding,
      theme: lightTheme,
      darkTheme: darkTheme,
      highContrastTheme: highContrastLightTheme,
      highContrastDarkTheme: highContrastDarkTheme,
      themeMode: themeMode,
    );
  }
}
