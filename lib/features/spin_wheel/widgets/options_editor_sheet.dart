import 'package:flutter/material.dart';
import '../models/wheel_option.dart';

class OptionsEditorSheet extends StatefulWidget {
  final List<WheelOption> initialOptions;
  final ValueChanged<List<WheelOption>> onOptionsChanged;

  const OptionsEditorSheet({
    super.key,
    required this.initialOptions,
    required this.onOptionsChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required List<WheelOption> initialOptions,
    required ValueChanged<List<WheelOption>> onOptionsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OptionsEditorSheet(
        initialOptions: List.from(initialOptions),
        onOptionsChanged: onOptionsChanged,
      ),
    );
  }

  @override
  State<OptionsEditorSheet> createState() => _OptionsEditorSheetState();
}

class _OptionsEditorSheetState extends State<OptionsEditorSheet> {
  late List<WheelOption> _options;
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();

  static const _wheelColors = [
    Color(0xFF6D28D9),
    Color(0xFF7C3AED),
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),
    Color(0xFF9333EA),
    Color(0xFFC026D3),
    Color(0xFFD946EF),
    Color(0xFF5B21B6),
  ];

  @override
  void initState() {
    super.initState();
    _options = List.from(widget.initialOptions);
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Color _getColorForIndex(int index) {
    return _wheelColors[index % _wheelColors.length];
  }

  void _addOption() {
    final text = _addController.text;
    if (text.trim().isEmpty) return;

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    setState(() {
      for (final line in lines) {
        _options.add(WheelOption(
          label: line,
          color: _getColorForIndex(_options.length),
        ));
      }
      _addController.clear();
    });
    widget.onOptionsChanged(_options);
    _addFocusNode.requestFocus();
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() {
      _options.removeAt(index);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _options.removeAt(oldIndex);
      _options.insert(newIndex, item);
    });
  }

  void _done() {
    widget.onOptionsChanged(_options);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF211635),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Options',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_options.length} options',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFE4EF0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Options list
          Expanded(
            child: _options.isEmpty
                ? const Center(
                    child: Text(
                      'Add at least 2 options',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    itemCount: _options.length,
                    onReorder: _reorder,
                    itemBuilder: (context, index) {
                      final option = _options[index];
                      return Container(
                        key: ValueKey('$index-${option.label}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Drag handle
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.drag_handle,
                                color: Colors.white38,
                                size: 20,
                              ),
                            ),

                            // Color dot
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                              ),
                            ),

                            // Editable label
                            Expanded(
                              child: TextFormField(
                                initialValue: option.label,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 12),
                                ),
                                onChanged: (value) {
                                  _options[index] = WheelOption(
                                    label: value,
                                    color: option.color,
                                  );
                                },
                              ),
                            ),

                            // Delete button
                            if (_options.length > 2)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                onPressed: () => _removeOption(index),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Add option field
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, bottomPadding > 0 ? bottomPadding + 8 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1450),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: TextField(
                      controller: _addController,
                      focusNode: _addFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type options (one per line)...',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addOption,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE4EF0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Done button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _options.length >= 2 ? _done : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE4EF0),
                    disabledBackgroundColor:
                        const Color(0xFFFE4EF0).withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _options.length >= 2 ? 'Done' : 'Add at least 2 options',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
