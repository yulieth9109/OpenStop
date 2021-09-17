import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:flutter/services.dart';
import '/widgets/question_sheet.dart';
import '/commons/globals.dart';
import '/commons/mapbox_utils.dart';
import '/widgets/home_controls.dart';
import '/widgets/home_sidebar.dart';
import '/models/question.dart';
import '/widgets/loading_indicator.dart';
import '/api/stop_query_handler.dart';
import '/models/stop.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  final _mapCompleter = Completer<MapboxMapController>();

  final _styleCompleter = Completer<void>();

  late final MapboxMapController _mapController;

  final _stopQueryHandler = StopQueryHandler();

  static const double _initialSheetSize = 0.4;

  final _selectedMarker = ValueNotifier<Circle?>(null);

  final _selectedQuestion = ValueNotifier<Question?>(null);

  late final Future<List<Question>> _questionCatalog;

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
    // wait for map creation to finish
    _mapCompleter.future.then(_initMap);

    _questionCatalog = parseQuestions();

    _selectedQuestion.addListener(() {
      if (_selectedQuestion.value == null) _deselectCurrentCircle();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: HomeSidebar(),
      // use builder to get scaffold context
      body: Builder(builder: (context) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MapboxMap(
            // move to user location and track it by default
            myLocationTrackingMode: MyLocationTrackingMode.Tracking,
            // dispatch camera change events
            trackCameraPosition: true,
            compassEnabled: false,
            accessToken: MAPBOX_API_TOKEN,
            styleString: MAPBOX_STYLE_URL,
            myLocationEnabled: true,
            tiltGesturesEnabled: false,
            initialCameraPosition: CameraPosition(
              zoom: 15.0,
              target: LatLng(50.8261, 12.9278),
            ),
            // Mapbox bug: requires devicePixelDensity for android
            attributionButtonMargins: Point(
              // another bug: https://github.com/tobrun/flutter-mapbox-gl/pull/681
              0,
              (MediaQuery.of(context).padding.bottom + 5) *
              (Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1)
            ),
            logoViewMargins: Point(
              25 *
              (Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1),
              (MediaQuery.of(context).padding.bottom + 5) *
              (Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1)
            ),
            onMapCreated: _mapCompleter.complete,
            onStyleLoadedCallback: _styleCompleter.complete,
            onMapClick: (Point point, LatLng location) => _selectedQuestion.value = null,
            onCameraIdle: _onCameraIdle,
          ),
          FutureBuilder(
            future: _mapCompleter.future,
            builder: (BuildContext context, AsyncSnapshot<MapboxMapController> snapshot) {
              // only show controls when map creation finished
              return AnimatedSwitcher(
                duration: Duration(milliseconds: 1000),
                child: snapshot.hasData ?
                  HomeControls(
                    mapController: snapshot.data!,
                  ) :
                  Container(
                    color: Colors.white
                  )
              );
            }
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            right: 0.0,
            left: 0.0,
            child: ValueListenableBuilder<int>(
              builder: (BuildContext context, int value, Widget? child) =>
                AnimatedSwitcher(
                  switchInCurve: Curves.elasticOut,
                  switchOutCurve: Curves.elasticOut,
                  transitionBuilder: (Widget child, Animation<double> animation) =>
                    ScaleTransition(child: child, scale: animation),
                  duration: Duration(milliseconds: 500),
                  child: value > 0 ? child : const SizedBox.shrink()
                ),
              valueListenable: _stopQueryHandler.pendingQueryCount,
              child: LoadingIndicator()
            )
          ),
          QuestionSheet(
            // TODO: Get rid of marker notifier here for example by combining them to a single notifier
            marker: _selectedMarker,
            question: _selectedQuestion,
            initialSheetSize: _initialSheetSize
          )
        ]
      )),
    );
  }


  _initMap(MapboxMapController controller) async {
    // store reference to controller
    _mapController = controller;

    _mapController.onCircleTapped.add(_onCircleTap);

    _stopQueryHandler.stops.listen(_addStopsToMap);
  }

  void _onCameraIdle() async {
    // await _mapController and style loaded callback
    await _mapCompleter.future;
    await _styleCompleter.future;

    // only update/query until certain zoom level is reached
    if (_mapController.cameraPosition != null && _mapController.cameraPosition!.zoom >= 12) {
      var viewBBox = await _mapController.getVisibleRegion();
      _stopQueryHandler.update(viewBBox);
    }
  }

  void _onCircleTap(Circle circle) async {
    _deselectCurrentCircle();
    _selectCircle(circle);

    final questions = await _questionCatalog;
    _selectedQuestion.value = questions[Random().nextInt(questions.length)];

    // move camera to circle
    // padding is not available for newLatLng()
    // therefore use newLatLngBounds as workaround
    final location = circle.options.geometry!;
    final mediaQuery = MediaQuery.of(context);
    final paddingBottom =
      (mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom) * _initialSheetSize;
    moveToLocation(
        mapController: _mapController,
        location: location,
        paddingBottom: paddingBottom
    );
  }


  /// Deselect a given symbol on the map

  void _deselectCircle(Circle circle) {
    _mapController.updateCircle(circle, CircleOptions(
        circleStrokeColor: '#f0ca00',
        circleColor: '#f0ca00',
        circleRadius: 20,
    ));
    // unset variable
    _selectedMarker.value = null;
  }


  /// Deselect the last selected symbol on the map

  void _deselectCurrentCircle() {
    if (_selectedMarker.value != null) {
      _deselectCircle(_selectedMarker.value!);
    }
  }


  /// Select a given symbol on the map
  /// This pushes it to the _selectedMarker ValueNotifier and changes its icon

  void _selectCircle(Circle circle) {
    // ignore if the symbol is already selected
    if (_selectedMarker.value == circle) {
      return;
    }
    _mapController.updateCircle(circle, CircleOptions(
      circleColor: '#00cc7f',
      circleStrokeColor: '#00cc7f',
      circleRadius: 30,
    ));
    _selectedMarker.value = circle;
  }


  /// Add a given list of Stops as circles to the map

  void _addStopsToMap(Iterable<Stop> result) async {
    final data = <Map<String, String>>[];
    final circle = <CircleOptions>[];
    final dot = <CircleOptions>[];

    for (final stop in result) {
      dot.add(
          CircleOptions(
              circleRadius: 4,
              circleColor: '#00cc7f',
              circleOpacity: 1,
              geometry: stop.location)
      );
      circle.add(CircleOptions(
              circleRadius: 20,
              circleColor: '#f0ca00',
              circleOpacity: 0.2,
              circleStrokeColor: '#f0ca00',
              circleStrokeOpacity: 1,
              circleStrokeWidth: 5,
              geometry: stop.location)
      );
      data.add({
        "name": stop.name
      });
    }
    _mapController.addCircles(dot);
    _mapController.addCircles(circle, data);
  }


  Future<List<Question>> parseQuestions() async {
    final questionJsonData = await rootBundle.loadString("assets/questions/question_catalog.json");
    final questionJson = jsonDecode(questionJsonData).cast<Map<String, dynamic>>();
    return questionJson.map<Question>((question) => Question.fromJSON(question)).toList();
  }


  @override
  void dispose() {
    super.dispose();
    _mapController.dispose();
    _stopQueryHandler.dispose();
    _selectedMarker.dispose();
  }
}