import 'package:flutter/material.dart';
import '../../models/admin_division.dart';
import '../../utils/location_data.dart';
import 'city_places_screen.dart';

class CityPickerScreen extends StatefulWidget {
  final String provinceName;
  final bool foodMode;

  const CityPickerScreen({
    super.key,
    required this.provinceName,
    this.foodMode = false,
  });

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _searchCtrl = TextEditingController();
  final _bg = const Color(0xFFE7ECEF);

  List<AdminDivision> _cities = [];
  List<AdminDivision> _filtered = [];
  AdminDivision? _selectedCity;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cities = await LocationData.getCities(widget.provinceName);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _filtered = cities;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterCities(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = _cities
          .where((c) => c.name.toLowerCase().contains(q))
          .toList();
    });
  }

  void _confirm() {
    if (_selectedCity == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CityPlacesScreen(
          city: _selectedCity!,
          foodMode: widget.foodMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Choose city',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.provinceName,
              style: const TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _filterCities,
                        decoration: InputDecoration(
                          hintText: 'Search city...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No cities found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final city = _filtered[index];
                                final isSelected = city == _selectedCity;
                                return ListTile(
                                  title: Text(city.name),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Colors.blue)
                                      : const Icon(Icons.radio_button_unchecked, color: Colors.black26),
                                  tileColor: isSelected ? Colors.blue.shade50 : null,
                                  onTap: () {
                                    setState(() => _selectedCity = city);
                                  },
                                );
                              },
                            ),
                    ),
                    if (_selectedCity != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _confirm,
                            child: const Text('Confirm'),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
