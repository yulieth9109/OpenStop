import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:animated_location_indicator/animated_location_indicator.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_api/osm_api.dart';
import 'package:provider/provider.dart';

import '/view_models/incomplete_osm_elements_provider.dart';
import '/view_models/questionnaire_provider.dart';
import '/view_models/osm_elements_provider.dart';
import '/view_models/map_view_model.dart';
import '/view_models/stop_areas_provider.dart';
import '/helpers/camera_tracker.dart';
import '/commons/stream_debouncer.dart';
import '/widgets/map_layer/stop_area_layer.dart';
import '/widgets/question_dialog/question_dialog.dart';
import '/widgets/map_overlay.dart';
import '/widgets/home_sidebar.dart';
import '/widgets/loading_indicator.dart';
import '/widgets/map_layer/osm_element_layer.dart';
import '/models/question_catalog.dart';
import '/models/stop_area.dart';
import '/commons/map_utils.dart';


class HomeScreen extends StatefulWidget {

  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  final _stopAreasProvider = StopAreasProvider(
    stopAreaRadius: 50
  );

  late final _cameraTracker = CameraTracker(
    mapController: _mapController
  );

  @override
  void initState() {
    super.initState();
    // set system ui to fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // update native ui colors
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black.withOpacity(0.25),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black.withOpacity(0.25),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // query stops on map interactions
    _mapController.mapEventStream.debounce<MapEvent>(const Duration(milliseconds: 500)).listen((event) {
      if (_mapController.bounds != null && _mapController.zoom > 12) {
        _stopAreasProvider.loadStopAreas(_mapController.bounds!);
      }
    });

    _mapController.onReady.then((_) {
      // use post frame callback because initial bounds are not applied in onReady yet
      SchedulerBinding.instance?.addPostFrameCallback((duration) {
        // move to user location and start camera tracking on app start
        // this will also trigger the first query of stops, but only if the user enabled the location service
        _cameraTracker.startTacking(initialZoom: 15);
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuestionCatalog>(
      future: _parseQuestionCatalog(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // TODO: Style this properly
          return const Center(
            child: CircularProgressIndicator()
          );
        }
        else {
          final questionCatalog = snapshot.requireData;

          return MultiProvider(
            providers: [
              Provider.value(value: questionCatalog),
              ChangeNotifierProvider(create: (_) => QuestionnaireProvider()),
              ChangeNotifierProvider.value(value: _cameraTracker),
              ChangeNotifierProvider.value(value: _stopAreasProvider),
              ChangeNotifierProvider(create: (_) => OSMElementProvider()),
              ChangeNotifierProxyProvider<OSMElementProvider, IncompleteOSMElementProvider>(
                create: (_) => IncompleteOSMElementProvider(questionCatalog),
                update: (_, osmElementProvider, incompleteOSMElementProvider) {
                  return incompleteOSMElementProvider!
                    ..extractNew(osmElementProvider.loadedStopAreas);
                }
              ),
              ChangeNotifierProvider(create: (_) => MapViewModel(
                urlTemplate: 'https://osm-2.nearest.place/retina/{z}/{x}/{y}.png'
              )),
              Provider.value(value: _mapController),
            ],
            child: Scaffold(
              drawer: const HomeSidebar(),
              // use builder to get scaffold context
              body: Builder(builder: (context) =>
                Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        onTap: (position, location) => _closeQuestionDialog(context),
                        enableMultiFingerGestureRace: true,
                        center: LatLng(50.8144951, 12.9295576),
                        zoom: 15.0,
                      ),
                      children: [
                        Consumer<MapViewModel>(
                          builder: (context, value, child) {
                            return TileLayerWidget(
                              options: TileLayerOptions(
                                overrideTilesWhenUrlChanges: true,
                                urlTemplate: value.urlTemplate,
                                minZoom: value.minZoom,
                                maxZoom: value.maxZoom,
                                tileProvider: NetworkTileProvider(),
                              ),
                            );
                          }
                        ),
                        Consumer2<StopAreasProvider, OSMElementProvider>(
                          builder: (context, stopAreaProvider, osmElementProvider, child) {
                            return StopAreaLayer(
                              stopAreas: stopAreaProvider.stopAreas,
                              loadingStopAreas: osmElementProvider.loadingStopAreas,
                              onStopAreaTap: (stopArea) => _onStopAreaTap(stopArea, context),
                            );
                          }
                        ),
                        Consumer<IncompleteOSMElementProvider>(
                          builder: (context, incompleteOsmElementProvider, child) {
                            return OsmElementLayer(
                              onOsmElementTap: (osmElement) => _onOsmElementTap(osmElement, context),
                              geoElements: incompleteOsmElementProvider.loadedOsmElements
                            );
                          }
                        ),
                        AnimatedLocationLayerWidget(
                          options: AnimatedLocationOptions()
                        )
                      ],
                      nonRotatedChildren: [
                        // only show controls when map creation finished
                        FutureBuilder(
                          future: _mapController.onReady,
                          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                            // only show overlay when question history has no active entry
                            return Consumer<QuestionnaireProvider>(
                              builder: (context, questionnaire,child) {
                                final mapIsLoaded = snapshot.connectionState == ConnectionState.done;
                                final noActiveEntry = !questionnaire.hasEntries;

                                return AnimatedSwitcher(
                                  switchInCurve: Curves.ease,
                                  switchOutCurve: Curves.ease,
                                  duration: const Duration(milliseconds: 300),
                                  child: mapIsLoaded && noActiveEntry
                                    ? const MapOverlay()
                                    : const SizedBox.expand(
                                      // TODO: decide overlay style/color
                                      child: ColoredBox(color: Colors.transparent)
                                    )
                                );
                              }
                            );
                          }
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 15),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: context.read<StopAreasProvider>().isLoading,
                              builder: (context, value, child) => LoadingIndicator(
                                active: value,
                              ),
                            )
                          )
                        ),
                      ],
                    ),
                    // place sheet on extra stack above map so touch events won't pass through
                    const QuestionDialog(),
                  ],
                )
              ),
            )
          );
        }
      }
    );
  }


  void _onStopAreaTap(StopArea stopArea, BuildContext context) async {
    context.read<OSMElementProvider>().loadStopAreaElements(stopArea);

    _mapController.animateToBounds(
      ticker: this,
      bounds: stopArea.bounds,
    );
  }


  void _onOsmElementTap(OSMElement osmElement, BuildContext context) async {
    final questionCatalog = context.read<QuestionCatalog>();
    final questionnaire = context.read<QuestionnaireProvider>();

    if (questionnaire.workingElement?.id != osmElement.id) {
      questionnaire.create(osmElement, questionCatalog);
    }
    else {
      return;
    }


    final mediaQuery = MediaQuery.of(context);
    final paddingBottom =
      (mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom) * 0.4;

    // TODO: take padding into account
    // TODO: handle ways and relations

    if (osmElement is OSMNode) {
      // move camera to element and include default sheet size as bottom padding
      _mapController.animateTo(
        ticker: this,
        location: LatLng(osmElement.lat, osmElement.lon),
        zoom: 17
      );
    }
  }


  Future<QuestionCatalog> _parseQuestionCatalog() async {
    final jsonString = await rootBundle.loadString('assets/questions/question_catalog.json');
    return QuestionCatalog.fromJson(jsonDecode(jsonString).cast<Map<String, dynamic>>());
  }


  _closeQuestionDialog(BuildContext context) {
    context.read<QuestionnaireProvider>().discard();
  }


  @override
  void dispose() {
    _cameraTracker.dispose();
    super.dispose();
  }
}
