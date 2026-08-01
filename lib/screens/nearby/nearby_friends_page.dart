import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../../models/user_entity.dart';
import '../../services/auth/user_service.dart';
import '../../services/friends/friend_service.dart';
import '../../services/location/location_service.dart';
import '../../services/location/overpass_service.dart';

class NearbyFriendsPage extends StatefulWidget {
  const NearbyFriendsPage({super.key});

  @override
  State<NearbyFriendsPage> createState() => _NearbyFriendsPageState();
}

class _NearbyFriendsPageState extends State<NearbyFriendsPage> {
  final _auth = FirebaseAuth.instance;
  final _locationService = LocationService();
  final _userService = UserService();
  final _friendService = FriendService();
  final _overpassService = OverpassService();
  final _bg = const Color(0xFFE7ECEF);

  bool _isLoading = true;
  bool _permissionDenied = false;
  Position? _position;
  String? _areaLabel;
  List<String> _studyPlaces = const [];
  List<UserEntity> _nearbyUsers = const [];
  Map<String, String> _partners = {};

  String get _uid => _auth.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    Position? position;
    try {
      position = await _locationService.getCurrentPosition();
    } catch (_) {
      position = null;
    }

    if (position == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }

    final uid = _uid;
    await _userService.updateLocationIfNeeded(
      uid,
      position.latitude,
      position.longitude,
    );

    final label = await _overpassService.labelArea(
      position.latitude,
      position.longitude,
    );
    final places = await _overpassService.nearbyStudyPlaces(
      position.latitude,
      position.longitude,
    );
    final users = await _userService.findNearbyUsers(
      position.latitude,
      position.longitude,
      excludeUid: uid,
    );
    final partners = await _friendService.getPartnerStatusMap(uid);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _position = position;
      _areaLabel = label;
      _studyPlaces = places;
      _nearbyUsers = users;
      _partners = partners;
    });
  }

  Future<void> _openSettings() async {
    await _locationService.openLocationSettings();
    _load();
  }

  Future<void> _onSend(UserEntity user) async {
    try {
      await _friendService.sendRequest(_uid, user.userId);
      if (!mounted) return;
      setState(() => _partners[user.userId] = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to @${user.username}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Nearby',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? _buildPermissionDenied()
              : _buildContent(),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.black45),
            const SizedBox(height: 16),
            const Text(
              'Location access is needed to find people near you',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allow location access in your device settings, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final position = _position!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(position),
          if (_studyPlaces.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildStudyPlaces(),
          ],
          const SizedBox(height: 16),
          const _SectionTitle('People near you'),
          if (_nearbyUsers.isEmpty)
            const _EmptyText('No one nearby yet. Check back later!')
          else
            ..._nearbyUsers.map((user) => _buildUserTile(position, user)),
        ],
      ),
    );
  }

  Widget _buildHeader(Position position) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Color(0xFFB8C6CC),
            offset: Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _areaLabel ?? 'Your area',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${position.latitude.toStringAsFixed(3)}, '
                  '${position.longitude.toStringAsFixed(3)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPlaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Study places near you'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _studyPlaces.map((name) {
            return Chip(
              avatar: const Icon(Icons.local_library, size: 18, color: Colors.blue),
              label: Text(name),
              backgroundColor: Colors.white,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUserTile(Position position, UserEntity user) {
    final distance = _distanceTo(position, user);
    final status = _partners[user.userId];
    final name = user.displayName.isEmpty ? user.username : user.displayName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Color(0xFFB8C6CC),
            offset: Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade100,
            child: const Icon(Icons.person, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'User' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.username.isNotEmpty && user.username != user.displayName)
                  Text(
                    '@${user.username}',
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Text(
                  _formatDistance(distance),
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
          if (status == 'friends')
            const Text('Friends', style: TextStyle(color: Colors.green))
          else if (status == 'pending')
            const Text('Sent', style: TextStyle(color: Colors.black45))
          else
            TextButton(
              onPressed: () => _onSend(user),
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }

  double _distanceTo(Position position, UserEntity user) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      user.latitude!,
      user.longitude!,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String message;
  const _EmptyText(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(message, style: const TextStyle(color: Colors.black45)),
    );
  }
}
