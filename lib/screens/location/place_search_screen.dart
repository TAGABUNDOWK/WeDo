import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/maps_key.dart';
import '../../services/location/geocoding_service.dart';

class PlaceSearchResult {
  final double latitude;
  final double longitude;
  final String? address;

  const PlaceSearchResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

/// Google Places Autocomplete search (keyed by `mapsApiKey`).
///
/// Flow: debounced text → Places Autocomplete predictions → on tap,
/// Geocoding API resolves the `place_id` to coordinates + address →
/// popped back to the location picker which flies the map there.
class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _textController = TextEditingController();
  final _geocoding = GeocodingService();

  Timer? _debounce;
  List<Map<String, dynamic>> _predictions = [];
  bool _loading = false;
  bool _resolving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!mapsApiKeyIsConfigured) {
      _error = 'Place search needs a Google Maps API key.';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _predictions = [];
        _error = mapsApiKeyIsConfigured ? null : 'Place search needs a Google Maps API key.';
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!mapsApiKeyIsConfigured) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeQueryComponent(query)}'
          '&language=en'
          '&key=$mapsApiKey';
      final response = await http
          .get(Uri.parse(url), headers: mapsAndroidHeaders)
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Search failed. Try again.';
        });
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      final predictions = (json['predictions'] as List?) ?? const [];

      setState(() {
        _predictions = predictions.cast<Map<String, dynamic>>();
        _loading = false;
        if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
          _error = 'Search failed ($status)';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed. Check your connection.';
      });
    }
  }

  Future<void> _select(Map<String, dynamic> prediction) async {
    if (_resolving) return;
    final placeId = prediction['place_id'] as String?;
    if (placeId == null) return;

    setState(() => _resolving = true);
    final place = await _geocoding.resolvePlaceId(placeId);
    if (!mounted) return;
    setState(() => _resolving = false);

    if (place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that place')),
      );
      return;
    }

    Navigator.pop(
      context,
      PlaceSearchResult(
        latitude: place.latitude,
        longitude: place.longitude,
        address: place.address,
      ),
    );
  }

  String _primaryText(Map<String, dynamic> prediction) {
    final structured =
        prediction['structured_formatting'] as Map<String, dynamic>?;
    final main = structured?['main_text'] as String?;
    if (main != null && main.isNotEmpty) return main;
    return prediction['description'] as String? ?? '';
  }

  String _secondaryText(Map<String, dynamic> prediction) {
    final structured =
        prediction['structured_formatting'] as Map<String, dynamic>?;
    return structured?['secondary_text'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF190831),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xE6190831),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        onChanged: _onChanged,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search a place…',
                          hintStyle: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          suffixIcon: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF25D366),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_resolving)
              const LinearProgressIndicator(
                color: Color(0xFF25D366),
                backgroundColor: Colors.transparent,
                minHeight: 2,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            Expanded(
              child: _predictions.isEmpty
                  ? Center(
                      child: Text(
                        _loading ? 'Searching…' : 'Start typing to search',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return _GlassButton(
                          icon: Icons.location_on_outlined,
                          onTap: () => _select(prediction),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _primaryText(prediction),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (_secondaryText(prediction).isNotEmpty)
                                Text(
                                  _secondaryText(prediction),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;

  const _GlassButton({
    required this.icon,
    this.onTap,
    this.child,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isCircle = child == null;
    return Material(
      color: const Color(0xE6190831),
      shape: isCircle
          ? CircleBorder(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            )
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
      child: InkWell(
        customBorder: isCircle
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
        child: isCircle
            ? SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, color: Colors.white, size: 22),
              )
            : Padding(
                padding: padding,
                child: Align(
                  alignment: alignment,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: const Color(0xFF25D366),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Flexible(child: child!),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
