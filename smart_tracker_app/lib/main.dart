import 'package:flutter/material.dart';
import 'services/api_services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const SmartTrackerApp());
}

class SmartTrackerApp extends StatelessWidget {
  const SmartTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Smart Tracker",

      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),

      home: const TrackerHome(),
    );
  }
}

class TrackerHome extends StatefulWidget {

  const TrackerHome({super.key});

  @override
  State<TrackerHome> createState() => _TrackerHomeState();

}

class _TrackerHomeState extends State<TrackerHome> {

  Map<String, dynamic>? locationData;

  bool loading = false;

  GoogleMapController? mapController;

  LatLng currentPosition = const LatLng(
   0.332201,
   32.570472,
  );

  Future<void> getLocation() async {
    setState(() {
      loading = true;
    });

    try {
      final data = await ApiService.getLatestLocation();
      setState(() {
        locationData = data;
        currentPosition = LatLng(
         double.parse(data["latitude"].toString()),
         double.parse(data["longitude"].toString()),
        );
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          currentPosition,15,
          ),
        );

    } catch(e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
        ),
      );
    }

    setState(() {
      loading = false;
    });

  }

  // EMERGENCY CONFIRMATION
  void showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Text("Emergency Alert"),
            ],

          ),

          content: const Text(
            "Are you sure this is an emergency alert?",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text(
                "CANCEL",
              ),

            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),

              onPressed: () {

                Navigator.pop(context);

                sendEmergencyAlert();

              },

              child: const Text(

                "YES",

                style: TextStyle(
                  color: Colors.white,
                ),

              ),

            ),

          ],

        );

      },

    );

  }

  // TEMPORARY FUNCTION
  void sendEmergencyAlert() {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Emergency alert sent!",
        ),

      ),

    );

  }


  @override
  Widget build(BuildContext context) {

    bool emergency =
        locationData?["emergency"] ?? false;

    return Scaffold(

      backgroundColor: Colors.grey[100],

      body: SafeArea(

        child: Column(

          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.shield,
                        color: Colors.blue,
                        size: 30,
                      ),

                      SizedBox(width:8),

                      Text(
                        "Smart Tracker",
                        style: TextStyle(
                          fontSize:22,
                          fontWeight:FontWeight.bold,
                        ),
                      ),

                    ],

                  ),

                  Container(

                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:12,
                      vertical:6,
                    ),

                    decoration: BoxDecoration(
                      color: emergency
                          ? Colors.red[100]
                          : Colors.green[100],
                      borderRadius:
                      BorderRadius.circular(20),

                    ),
                    child: Text(
                      emergency
                          ? "EMERGENCY"
                          : "SAFE",
                      style: TextStyle(

                        color: emergency
                            ? Colors.red
                            : Colors.green,

                        fontWeight:
                        FontWeight.bold,

                      ),

                    ),

                  ),


                ],

              ),

            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),

                clipBehavior: Clip.antiAlias,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),

                child: GoogleMap(

                  initialCameraPosition: CameraPosition(
                    target: currentPosition,
                    zoom: 15,
                  ),

                  onMapCreated: (controller){
                    mapController=controller;
                  },

                  markers: {
                    Marker(
                      markerId: const MarkerId("tracker"),
                      position: currentPosition,
                      infoWindow: const InfoWindow(
                        title:"Guardian Bracelet",
                        snippet: "Current location",
                      ),
                    ),
                  },
                  myLocationEnabled: false,
                  zoomControlsEnabled: true,
                ),

              ),

            ),

            if(locationData != null)

              Card(

                child: Padding(

                  padding:
                  const EdgeInsets.all(15),

                  child: Column(
                    children: [
                      Text(
                        "Latitude: ${locationData!['latitude']}",
                      ),

                      Text(
                        "Longitude: ${locationData!['longitude']}",
                      ),

                      Text(
                        "Battery: ${locationData!['battery_level']}%",
                      ),

                    ],

                  ),

                ),

              ),

            ElevatedButton.icon(

              onPressed:
              loading ? null : getLocation,

              icon:
              const Icon(Icons.location_on),

              label: Text(
                loading
                    ? "Loading..."
                    : "Get Current Location",

              ),

            ),

            Padding(

              padding:
              const EdgeInsets.all(16),

              child: SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  icon:
                  const Icon(
                    Icons.warning,
                    color:Colors.white,
                  ),

                  label:
                  const Text(
                    "EMERGENCY",
                    style:TextStyle(
                      color:Colors.white,
                      fontWeight:FontWeight.bold,
                    ),
                  ),

                  onPressed:
                  showEmergencyDialog,

                  style:
                  ElevatedButton.styleFrom(

                    backgroundColor:
                    Colors.red,

                  ),

                ),

              ),

            )

          ],

        ),

      ),

    );

  }

}