import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../place_model.dart';
import '../../place_service.dart';
import './place_detail_page.dart';

const String _apiKey = 'AIzaSyD7kQHyGfDcFhWBLX4D6Rne4tfoY6ovbOU';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<StatefulWidget> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final PlaceService _placeService = PlaceService(_apiKey);
  // extract user location info as initial
  double? _initialLat, _initialLng;

  // the current location of program use
  double? _lat, _lng;

  // UI state
  bool _loading = false;
  String? _error;
  bool _showMap = false;

  // search parameters
  double _radius = 1000; // in meters
  String _selectedType = 'restaurant';

  // fetched places
  List<Place> _places = [];

  // google map controller
  GoogleMapController? _mapController;

  // search-ahead state
  final TextEditingController _searchController = TextEditingController();
  List<Place> _searchResults = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  // list of choice chips to choose from
  final List<String> _types = [
    'restaurant',
    'cafe',
    'shopping_mall',
    'bar',
    'park',
    'hospital',
    'massage',
    'school',
    'museum',
  ];

  // for showing the origin location on map
  LatLng? _origin;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
    // set the initial Lat & Lng once, and when no search input reuse it to get nearby places
    _initialLat = position.latitude;
    _initialLng = position.longitude;

    setState(() {
      _lat = _initialLat;
      _lng = _initialLng;
      _origin = LatLng(_initialLat!, _initialLng!);
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
        types: [_selectedType], // wrap with a List
      );
      
      // sort the result by rating highest to lower
      results.sort((a,b) => b.rating.compareTo(a.rating));

      if (!mounted) return;
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

  void _onSearchChanged(String query) {
    // use debounce so don’t hammer the API, API cost consider here,
    // delay the searching, so that user can finish typing if type fast
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // clear and reset the search results if text is empty
    if (query.trim().isEmpty) {
      setState(() {
        _showSuggestions = false;
        _searchResults = [];

        // reset the lat & lng to initial position
        _lat = _initialLat;
        _lng = _initialLng;
      });

      // rerun nearby API
      _fetchPlaces();
      return;
    }

    // only when user stop typing for 300ms, fire one search request
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final text = query.trim();
      if (text.isEmpty) {
        setState(() {
          _searchResults = [];
          _showSuggestions = false;
        });
        return;
      }

      try {
        final hits = await _placeService.searchText(
          query: text,
          latitude: _lat,
          longitude: _lng,
          radius: 50000.0, // hardcode here as max distance for text search, since I dont want the search result being toooooo far away
        );

        // sort by distance from current origin
        hits.sort((a, b) {
          final da = Geolocator.distanceBetween(_lat!, _lng!, a.lat, a.lng);
          final db = Geolocator.distanceBetween(_lat!, _lng!, b.lat, b.lng);
          return da.compareTo(db);
        });

        setState(() {
          _searchResults = hits;
          _showSuggestions = hits.isNotEmpty;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      }
    });
  }

  void _selectOrigin(Place p) {
    // user tapped one of the dropdown items
    _debounce?.cancel();
    _searchController.text = p.displayName;

    // choose the selected place as origin, and update state
    setState(() {
      _showSuggestions = false;
      _lat = p.lat;
      _lng = p.lng;
      _origin = LatLng(p.lat, p.lng);
    });
    _fetchPlaces();
  }

  double _distanceMeters(Place p) {
    if (_lat == null || _lng == null) return 0;
    return Geolocator.distanceBetween(_lat!, _lng!, p.lat, p.lng);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(meters < 10_000 ? 2 : 1)} km';
  }

  // build the photo url for the place
  String buildPhotoUrl(String photoName) {
    return 'https://places.googleapis.com/v1/$photoName/media'
        '?maxWidthPx=160&maxHeightPx=160&key=$_apiKey';
  }

  Widget _buildLeadingPic(Place p) {
    if (p.photoNames.isEmpty) {
      return const Icon(Icons.place, size: 48);
    }

    final url = buildPhotoUrl(p.photoNames.first);

    return SizedBox(
      width: 64,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade300,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image, size: 32, color: Colors.grey),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == null || _lng == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          // support search as origin textfield search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search a place as origin ...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _onSearchChanged,
              controller: _searchController, // attach to controller
            ),
          ),

          // dropdown to select on searching results from TextSearch to change origin
          if (_showSuggestions)
            Container(
              height: 250,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
              ),
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, i) {
                  final place = _searchResults[i];
                  final distance = Geolocator.distanceBetween(_lat!, _lng!, place.lat, place.lng);
                  return ListTile(
                    // each suggestion is a place with info: distance, displayname, formatted addr,
                    leading: const Icon(Icons.place),
                    title: Text(place.displayName),
                    subtitle: Text(place.formattedAddress),
                    trailing: Text('${(distance/1000).toStringAsFixed(2)}km'),
                    onTap: () => _selectOrigin(place),
                  );
                },

              ),
            ),

          // choice chip to select one type of place
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _types.length,
                separatorBuilder: (context, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final type = _types[i];
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      // if user try to de-select the same chip, do nothing
                      if (!selected) return;
                      setState(() {
                        _selectedType = type;
                      });

                      // rerun the featchPlaces on this type
                      _fetchPlaces();
                    },
                  );
                },
              ),
            ),
          ),

          //slider + list-map switch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

                SizedBox(width: 16,),

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
                    strokeWidth: 4,
                    fillColor: Colors.lightBlueAccent.withValues(alpha: 0.4),
                  ),
                },
                markers: {
                  if (_origin != null)
                    Marker(
                      markerId: const MarkerId('origin'),
                      position: _origin!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      infoWindow: const InfoWindow(title: 'Origin'),
                      zIndexInt: 100,
                    ),
                  ..._places.map((p) => Marker(
                    markerId: MarkerId(p.resourceName),
                    position: LatLng(p.lat, p.lng),
                    infoWindow: InfoWindow(title: p.displayName),
                  )),
                },
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

                  final dist = _distanceMeters(p);
                  final distText = _formatDistance(dist);

                  return ListTile(
                    leading: _buildLeadingPic(p),
                    title: Text(p.displayName),
                    subtitle: Text('${p.rating.toStringAsFixed(1)} ★           $distText\n${p.formattedAddress}\n${p.formattedAddress}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => PlaceDetailSheet(
                          place: p,
                          placeService: _placeService,
                          apiKey: _apiKey,
                        ),
                      );
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