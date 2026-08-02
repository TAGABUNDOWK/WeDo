import 'package:flutter/material.dart';
import '../../utils/location_data.dart';
import 'city_picker_screen.dart';

class ProvincePickerScreen extends StatefulWidget {
  final bool foodMode;

  const ProvincePickerScreen({super.key, this.foodMode = false});

  @override
  State<ProvincePickerScreen> createState() => _ProvincePickerScreenState();
}

class _ProvincePickerScreenState extends State<ProvincePickerScreen> {
  final _searchCtrl = TextEditingController();
  final _bg = const Color(0xFFE7ECEF);

  List<String> _provinces = [];
  List<String> _filtered = [];
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
      final provinces = await LocationData.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _filtered = provinces;
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

  void _filterProvinces(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = _provinces
          .where((p) => p.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Choose province',
          style: TextStyle(fontWeight: FontWeight.w600),
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
                        onChanged: _filterProvinces,
                        decoration: InputDecoration(
                          hintText: 'Search province...',
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
                                'No provinces found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final province = _filtered[index];
                                return ListTile(
                                  title: Text(province),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.black26),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CityPickerScreen(
                                          provinceName: province,
                                          foodMode: widget.foodMode,
                                        ),
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
