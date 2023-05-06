
import 'dart:async';

import 'package:Conserv/database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'c_location.dart';

void main() {aaaaaaaaa
  initApp();
}

void initApp() async {
  ConservDB db = await ConservDB.init();
  Location location = await ConservLocation.init();
  runApp(App(db: db, location: location));
}

class App extends StatelessWidget {
  const App(
      {
        Key? key,
        required this.db,
        required this.location
      }
      ) : super(key: key);
  final ConservDB db;
  final Location location;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conserv[Debug]',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(title: 'Conserv', db: db, location: location),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage(
      {
        Key? key,
        required this.title,
        required this.db,
        required this.location
      }
      ) : super(key: key);
  final String title;
  final ConservDB db;
  final Location location;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  late final ConservDB db;
  late final Location location;
  int clickCounter = 0;
  bool addPoints = true;
  bool addLines = true;
  bool addPolygons = true;
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  LatLng? routePoint;
  Polyline? route;
  Polygon? area;
  bool isMarkingArea = false;
  bool isRouting = false;
  Set<Polyline> routes = {};
  Set<Polygon> areas = {};
  LatLng userLocation = const LatLng(-13.98768679403707, 33.76740157508061);
  bool isCollectingData = false;
  bool isInViewMode = false;

  FloatingActionButtonLocation fltButtonLocation = FloatingActionButtonLocation.endFloat;
  FloatingActionButton? addPointButton;
  Widget? mainFloatingActionButton;
  FloatingActionButton? pointsButton;

  FloatingActionButton? linesButton;

  FloatingActionButton? polygonsButton;

  void getUserLocation() async {
    LocationData ld = await location.getLocation();
    userLocation = LatLng(ld.latitude!, ld.longitude!);
  }

  Future<void> startRouting(bool start) async {
    //Collecting route data
    List<LatLng> routePoints = [];
    isRouting = start;
    String lineName = "Route ${routes.length + 1}";
    if(!start) {
      int lineId = routes.length;
      lineName = "Route $lineId";
      for (var point in route!.points) {
        int id = await db.countAllPoints();
        CPoint cPoint = CPoint(
            id: id + 1,
            polylineId: lineId,
            latitude: point.latitude,
            longitude: point.longitude
        );
        db.insertPoint(cPoint);
      }
      db.insertLine(CPolyline(
        id: lineId,
        name: lineName,
        project: "dummy project",
      ));
    }
    location.onLocationChanged.listen((point) {
      if(isRouting) {
        setState(() {
          userLocation = LatLng(point.latitude!, point.longitude!);
          routePoints.add(userLocation);
          route = createPolyline(lineName, routePoints);
            routes.add(route!);
        });
      }
    });
  }

  Polyline createPolyline(String id, List<LatLng> points) {
    return Polyline(
        polylineId: PolylineId(id),
        points: points,
        color: Colors.white,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap
    );
  }

  Future<void> startMarkingArea(bool start) async {
    List<LatLng> areaPoints = [];
    isMarkingArea = start;
    String polygonName = "Area ${areas.length + 1}";
    if(!start) {
      int polygonId = areas.length;
      for (var coordinate in area!.points) {
        int id = await db.countAllPoints();
        CPoint point = CPoint(
          id: id + 1,
          polygonId: polygonId,
          latitude: coordinate.latitude,
          longitude: coordinate.longitude,
        );
        db.insertPoint(point);
      }
      polygonName = "Area $polygonId";
      db.insertPolygon(
          CPolygon(
              id: polygonId,
              name: polygonName,
              project: "dummy project"
          )
      );
    }
    location.onLocationChanged.listen((point){
      if(isMarkingArea){
        setState(() {
          userLocation = LatLng(point.latitude!, point.longitude!);
          areaPoints.add(userLocation);
          area = createPolygon(polygonName, areaPoints);
          areas.add(area!);
        }
        );
      }
    });
  }

  Polygon createPolygon(String id, List<LatLng> points) {
    return Polygon(
        polygonId: PolygonId(id),
        points: points,
        fillColor: Colors.blueGrey,
        strokeColor: Colors.black54,
        strokeWidth: 5
    );
  }

  Future<void> readAllPoints() async {
    List<CPoint> points = await db.getActualPoints();
    for(var point in points) {
      int pointId = point.id;
      debugPrint(point.name);
      InfoWindow infoWindow = InfoWindow(title: "Point $pointId");
      markers.add(
          Marker(
            markerId: MarkerId("${point.name} $pointId"),
            position: LatLng(point.latitude, point.longitude),
            infoWindow: infoWindow,
          )
      );
    }
  }

  Future<void> readAllLines() async {
    List<CPolyline> lines = await db.getLines();
    List<CPoint> linePoints;
    for (var line in lines) {
      List<LatLng> routePoints = [];
      linePoints = await db.getLinePoints(line.id);
      for(var point in linePoints) {
        routePoints.add(LatLng(point.latitude, point.longitude));
      }
      routes.add(createPolyline(line.name!, routePoints));
    }
  }

  Future<void> readAllPolygons() async {
    List<CPolygon> polygons = await db.getPolygons();
    List<CPoint> polygonPoints;
    for (var polygon in polygons) {
      List<LatLng> areaPoints = [];
      polygonPoints = await db.getPolygonPoints(polygon.id);
      for(var point in polygonPoints) {
        areaPoints.add(LatLng(point.latitude, point.longitude));
      }
      areas.add(
          createPolygon(polygon.name!, areaPoints)
      );
    }
  }     

  @override void initState() {
    super.initState();
    db = super.widget.db;
    location = super.widget.location;

    getUserLocation();

    readAllPoints().whenComplete(() => {
      setState(() => {})
    });

    readAllLines().whenComplete(() => {
      setState(() => {})
    });

    readAllPolygons().whenComplete(() => {
      setState(() => {})
    });
  }

  @override
  Widget build(BuildContext context) {

    pointsButton = FloatingActionButton(
      onPressed:() {
        //Switch tagging points
        setState((){
          addLines = !addPoints;
          addPolygons = addLines;
          fltButtonLocation = FloatingActionButtonLocation.centerFloat;
        });
      },
      tooltip: 'Toggle add points',
      child: const Icon(Icons.pin_drop_sharp),
    );

    linesButton = FloatingActionButton(
      onPressed:() {
        setState(() {
          addPoints = !addLines;
          addPolygons = addPoints;
          fltButtonLocation = FloatingActionButtonLocation.centerFloat;
          startRouting(true);
        });
      },
      tooltip: 'Toggle add points',
      child: const Icon(Icons.route),
    );

    polygonsButton = FloatingActionButton(
      onPressed:() {
        //Switch tagging points
        setState((){
          addPoints = !addPolygons;
          addLines = addPoints;
          fltButtonLocation = FloatingActionButtonLocation.centerFloat;
          startMarkingArea(true);
        });
      },
      tooltip: 'Toggle add points',
      child: const Icon(Icons.crop_landscape),
    );

    addPointButton = FloatingActionButton(
      onPressed: () {
        //Logic to add point on every click
        int pointId = markers.length + 1;
        String pointName = "Point $pointId";
        InfoWindow infoWindow = InfoWindow(title: pointName);
        markers.add(
            Marker(
              markerId: MarkerId(pointName),
              position: userLocation,
              infoWindow: infoWindow,
            )
        );
        db.insertPoint(
            CPoint(
                id: pointId, name: pointName,
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
        );
        setState((){});
      },
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.location_pin),
    );

    if(addPoints && !addLines && !addPolygons){
      pointsButton = FloatingActionButton(
        onPressed:() {
          setState((){
            addPoints = true;
            addLines = addPoints;
            addPolygons = addLines;
            fltButtonLocation = FloatingActionButtonLocation.endFloat;
          });
        },
        tooltip: 'Finish adding points',
        child: const Icon(Icons.done),
      );

      mainFloatingActionButton =
          Wrap(
              direction: Axis.horizontal,
              alignment: WrapAlignment.center,
              children: <Widget>[
                Visibility(
                    visible: addPoints,
                    child: Container(margin: const EdgeInsets.only(right: 60), child:addPointButton!)
                ),
                Visibility(
                    visible: addPoints,
                    child: Container(child: pointsButton!)
                ),
              ]
          );
    }
    else if(addLines && !addPoints && !addPolygons){
      mainFloatingActionButton = FloatingActionButton(
        onPressed: () {
          setState((){
            startRouting(false);
            addPoints = addLines;
            addPolygons = addPoints;
            fltButtonLocation = FloatingActionButtonLocation.endFloat;
          });
        },
        tooltip: "Finish line",
        child: const Icon(Icons.done),
      );
    }
    else if(addPolygons && !addPoints && !addLines){
      mainFloatingActionButton = FloatingActionButton(
        onPressed: () {
          setState((){
            startMarkingArea(false);
            addLines = addPolygons;
            addPoints = addLines;
            fltButtonLocation = FloatingActionButtonLocation.endFloat;
          });
        },
        tooltip: "Finish area",
        child: const Icon(Icons.done),
      );
    }
    else{
      mainFloatingActionButton = Wrap(
        direction: Axis.vertical,
        alignment: WrapAlignment.end,
        children: <Widget>[
          Visibility(
              visible: true,
              child: Container(
                margin: const EdgeInsets.only(right: 0, bottom: 10),
                child: pointsButton,
              )),
          Visibility(
              visible: true,
              child: Container(
                margin: const EdgeInsets.only(right: 0, bottom: 10),
                child: linesButton,
              )),
          Visibility(
              visible: true,
              child: Container(
                margin: const EdgeInsets.only(right: 0, bottom: 90),
                child: polygonsButton,
              )),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: GoogleMap(
          zoomGesturesEnabled: true,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          initialCameraPosition: CameraPosition(
            target: userLocation,
            zoom: 10,
          ),
          markers: markers,
          polylines: routes,
          polygons: areas,
          mapType: MapType.satellite,
          onMapCreated: (controller) {
            setState((){
              mapController = controller;
              location.onLocationChanged.listen((point) {
                userLocation = LatLng(point.latitude!, point.longitude!);
                mapController!.animateCamera(CameraUpdate.newCameraPosition(
                    CameraPosition(target: userLocation, zoom: 20)));
                debugPrint("${userLocation.latitude},${userLocation.longitude}");
              });
            });
          },
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          //Projects to be listed here
          children: [
            DrawerHeader(
                decoration: const BoxDecoration( color: Colors.blue),
                child: Column(
                  children: const [
                    Text(
                      "Conserv",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
            ),
            Padding(
                padding: const EdgeInsets.only(left: 15),
                child: const Text(
                    "Projects",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    )
                )
            ),
            Padding(
                padding: const EdgeInsets.only(left: 0),
                child: Column(
                    children: [
                      ListTile(
                        title: const Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Project 1")
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Project 2")
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Project 3")
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Project 4")
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Project 1")
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        title: const Padding(
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Project 5")
                        ),
                        onTap: () {},
                      ),
                    ]
                )
            ),
            Padding(
                padding: const EdgeInsets.only(left: 0),
                child: ListTile(
                  title: const Text(
                      "Settings",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold
                      )
                  ),
                  onTap: () {},
                )
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: fltButtonLocation,
      floatingActionButton: mainFloatingActionButton,
    );
  }
}
