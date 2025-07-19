import 'package:flutter/material.dart';
import '../place_service.dart';
import './pages/explore_page.dart';
import './pages/notifications_page.dart';
import './pages/favorites_page.dart';
import './pages/profile_page.dart';

const String _apiKey = 'AIzaSyD7kQHyGfDcFhWBLX4D6Rne4tfoY6ovbOU';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// track which tab is selected
  int _currentIndex = 1; // default to be 1 --- Explore Page

  late final PlaceService _placeService = PlaceService(_apiKey);
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      NotificationsPage(placeService: _placeService, apiKey: _apiKey),
      ExplorePage(),
      FavoritesPage(placeService: _placeService, apiKey: _apiKey),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() {
          _currentIndex = i;
        }),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],

      ),
    );
  }
}
