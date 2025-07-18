import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../place_model.dart';
import '../../place_service.dart';

const String _apiKey = 'AIzaSyD7kQHyGfDcFhWBLX4D6Rne4tfoY6ovbOU';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<StatefulWidget> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final PlaceService _placeService = PlaceService(_apiKey);
  // extract user location info
  double? _lat, _lng;

  // UI state
  bool _loading = false;
  String? _error;
  bool _showMap = false;

  // search parameters
  double _radius = 1000; // in meters
  List<String> _selectedTypes = ['restaurant'];

  // fetched places
  List<Place> _places = [];

  // google map controller
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    LocationPermission permit = await Geolocator.requestPermission(); // send request to user
    if (permit == LocationPermission.denied) {
      permit = await Geolocator.requestPermission();
    }
    if (permit == LocationPermission.deniedForever || permit == LocationPermission.denied) {
      setState(() {
        _error = 'Location permission denied';
      });
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _lat = position.latitude;
      _lng = position.longitude;
    });
    await _fetchPlaces();
  }

  Future<void> _fetchPlaces() async {
    if (_lat == null || _lng == null) return;

    setState(() {
      _loading = true;
      _error = null; // clear error message
    });
    try { // HTTP req may fail so we need to catch it
      final results = await _placeService.searchNearbyPlaces(
        latitude: _lat!,
        longitude: _lng!,
        radius: _radius,
        types: _selectedTypes,
      );
      setState(() {
        // store the fetched places and update state
        _places = results;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == null || _lng == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          // radius slider
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tune_outlined),
                const SizedBox(width: 8),
                Text('${(_radius/1000).toStringAsFixed(1)}km'),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 15,
                    divisions: 14,
                    value: _radius/1000,
                    label: '${(_radius/1000).toStringAsFixed(1)}km',
                    onChanged: (v) => setState(() => _radius = v * 1000),
                    onChangeEnd: (_) => _fetchPlaces(),
                  ),
                ),
              ],
            ),
          ),

          // Map/List toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.list),
                Switch(
                  value: _showMap,
                  onChanged: (v) => setState(() => _showMap = v),
                ),
                const Icon(Icons.map),
              ],
            ),
          ),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text('Error: $_error')))
          else if (_showMap)
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_lat!, _lng!),
                  zoom: 14,
                ),
                circles: {
                  Circle(
                    circleId: const CircleId('search_area'),
                    center: LatLng(_lat!, _lng!),
                    radius: _radius,
                    strokeColor: Colors.blueAccent,
                    fillColor: Colors.blueAccent,
                  ),
                },
                markers: _places.map((p) {
                  return Marker(
                    markerId: MarkerId(p.resourceName),
                    position: LatLng(p.lat, p.lng),
                    infoWindow: InfoWindow(title: p.displayName),
                  );
                }).toSet(),
                onMapCreated: (ctrl) => _mapController = ctrl,
              ),
            )
          else
            // list view
            Expanded(
              child: ListView.builder(
                itemCount: _places.length,
                itemBuilder: (context, i) {
                  final p = _places[i];
                  return ListTile(
                    leading: Icon(Icons.place),
                    title: Text(p.displayName),
                    subtitle: Text('${p.rating.toStringAsFixed(1)} ★\n${p.formattedAddress}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      // TODO go to detail page of that place
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}