import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import '../../../models/event_prefill.dart';
import '../../../utils/constants.dart';
import '../../../services/event/event_service.dart';
import '../../../services/group/group_service.dart';
import '../../../services/direct/direct_service.dart';
import '../../../services/notification/notification_service.dart';
import '../../../widgets/chat_default_background.dart';

class CreateEventScreen extends StatefulWidget {
  final String? groupId;
  final String? chatId;
  final EventPrefill? prefill;

  const CreateEventScreen({
    super.key,
    this.groupId,
    this.chatId,
    this.prefill,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dressCodeCtrl = TextEditingController();
  final _eventService = EventService();
  final _groupService = GroupService();
  final _directService = DirectService();
  final _notificationService = NotificationService();
  final _currentUser = FirebaseAuth.instance.currentUser;
  final _imagePicker = ImagePicker();

  DateTime _selectedDate = DateTime.now();
  Duration _startDuration = const Duration(minutes: 15);
  Duration? _endDuration;
  bool _showRsvpMessages = false;
  bool _isCreating = false;
  File? _eventImage;

  // Populated only when a PickFight prefill's cover image could not be
  // downloaded — used as the event's imageUrl directly instead of an upload.
  String? _prefillImageUrl;

  @override
  void initState() {
    super.initState();
    _applyPrefill();
  }

  /// Fills the existing form from a PickFight [EventPrefill]. All controls
  /// and the whole creation path below stay exactly as they were — this only
  /// seeds the fields.
  Future<void> _applyPrefill() async {
    final p = widget.prefill;
    if (p == null) return;

    _titleCtrl.text = p.title;
    _descCtrl.text = p.description;
    if (p.location != null && p.location!.isNotEmpty) {
      _locationCtrl.text = p.location!;
    }
    _startDuration = const Duration(hours: 1);

    final url = p.imageUrl;
    if (url == null || url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final dir = await Directory.systemTemp.createTemp('wedo_event_');
        final file = File('${dir.path}/cover.jpg');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        if (mounted) setState(() => _eventImage = file);
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _prefillImageUrl = url);
  }

  static const _startOptions = <MapEntry<String, Duration>>[
    MapEntry('In 5 minutes', Duration(minutes: 5)),
    MapEntry('In 10 minutes', Duration(minutes: 10)),
    MapEntry('In 15 minutes', Duration(minutes: 15)),
    MapEntry('In 30 minutes', Duration(minutes: 30)),
    MapEntry('In 1 hour', Duration(hours: 1)),
    MapEntry('In 2 hours', Duration(hours: 2)),
    MapEntry('In 3 hours', Duration(hours: 3)),
    MapEntry('In 6 hours', Duration(hours: 6)),
    MapEntry('In 12 hours', Duration(hours: 12)),
    MapEntry('Tomorrow', Duration(hours: 24)),
  ];

  static const _endOptions = <MapEntry<String, Duration>>[
    MapEntry('5 minutes after start', Duration(minutes: 5)),
    MapEntry('10 minutes after start', Duration(minutes: 10)),
    MapEntry('15 minutes after start', Duration(minutes: 15)),
    MapEntry('30 minutes after start', Duration(minutes: 30)),
    MapEntry('1 hour after start', Duration(hours: 1)),
    MapEntry('2 hours after start', Duration(hours: 2)),
    MapEntry('3 hours after start', Duration(hours: 3)),
  ];

  DateTime get _eventStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selectedDay.isAtSameMomentAs(today)) {
      return now.add(_startDuration);
    }
    return selectedDay.add(_startDuration);
  }

  DateTime? get _eventEnd => _endDuration != null ? _eventStart.add(_endDuration!) : null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _dressCodeCtrl.dispose();
    super.dispose();
  }

  String _formatDateShort(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  String _getTodayTimeLabel() {
    final now = DateTime.now();
    final start = now.add(_startDuration);
    return 'Today at ${_formatTime(start)}';
  }

  String _getTomorrowLabel() => 'Tomorrow at ${_formatTime(_selectedDate.add(_startDuration))}';

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.lavenderAccent,
              onPrimary: AppColors.midnightBg,
              surface: Color(0xFF211635),
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF211635)),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    setState(() {
      _selectedDate = date;
    });
  }

  Future<void> _pickCustomStart() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: const Text('Custom start time', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Minutes from now',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            suffixText: 'min',
            suffixStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lavenderAccent),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(ctrl.text);
              if (mins != null && mins > 0) Navigator.pop(ctx, mins);
            },
            child: const Text('OK', style: TextStyle(color: AppColors.lavenderAccent)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _startDuration = Duration(minutes: result));
    }
  }

  Future<void> _pickCustomEnd() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: const Text('Custom end time', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Minutes after start',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            suffixText: 'min',
            suffixStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lavenderAccent),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(ctrl.text);
              if (mins != null && mins > 0) Navigator.pop(ctx, mins);
            },
            child: const Text('OK', style: TextStyle(color: AppColors.lavenderAccent)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _endDuration = Duration(minutes: result));
    }
  }

  Future<void> _pickEventImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF211635),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: const Text(
          'Event photo',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('Camera', style: TextStyle(color: AppColors.lavenderAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Gallery', style: TextStyle(color: AppColors.lavenderAccent)),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF190831),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFFE4EF0),
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (cropped != null && mounted) {
      setState(() => _eventImage = File(cropped.path));
    }
  }

  Future<void> _createEvent() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _currentUser == null) return;

    setState(() => _isCreating = true);

    try {
      String? imageUrl;
      final image = _eventImage;
      if (image != null) {
        imageUrl = await _eventService.uploadEventImage(
          chatId: widget.chatId,
          groupId: widget.groupId,
          file: image,
        );
      }

      final eventId = await _eventService.createEvent(
        createdBy: _currentUser.uid,
        title: title,
        description: _descCtrl.text.trim(),
        date: _eventStart,
        endDate: _eventEnd,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        dressCode: _dressCodeCtrl.text.trim().isEmpty
            ? null
            : _dressCodeCtrl.text.trim(),
        imageUrl: imageUrl ?? _prefillImageUrl,
        showRsvpMessages: _showRsvpMessages,
        chatId: widget.chatId,
        groupId: widget.groupId,
        source: widget.prefill != null ? 'pickfight' : null,
        cardType: widget.prefill?.cardType,
        latitude: widget.prefill?.latitude,
        longitude: widget.prefill?.longitude,
        address: widget.prefill?.address,
        placeId: widget.prefill?.placeId,
        tag: widget.prefill?.tag,
        rating: widget.prefill?.rating,
        distanceSnapshot: widget.prefill?.distanceSnapshot,
        sessionId: widget.prefill?.sessionId,
      );

      if (widget.groupId != null) {
        await _groupService.sendEventMessage(
          groupId: widget.groupId!,
          senderId: _currentUser.uid,
          senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
          eventId: eventId,
          title: title,
        );
        await _sendEventNotifications(
          eventId: eventId,
          eventTitle: title,
          groupId: widget.groupId!,
        );
      } else if (widget.chatId != null) {
        await _directService.sendEventMessage(
          chatId: widget.chatId!,
          senderId: _currentUser.uid,
          senderName: _currentUser.displayName ?? _currentUser.email ?? 'Unknown',
          eventId: eventId,
          title: title,
        );
        await _sendEventNotifications(
          eventId: eventId,
          eventTitle: title,
          chatId: widget.chatId!,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create event: $e'),
            backgroundColor: const Color(0xFF211635),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _sendEventNotifications({
    required String eventId,
    required String eventTitle,
    String? groupId,
    String? chatId,
  }) async {
    try {
      final user = _currentUser;
      if (user == null) return;
      final senderName = user.displayName ?? user.email ?? 'Unknown';

      if (groupId != null) {
        final members = await _groupService.getGroupMembersWithNames(groupId);
        for (final member in members) {
          final uid = member['uid'] as String;
          if (uid == user.uid) continue;
          await _notificationService.createEventCreatedNotification(
            recipientId: uid,
            senderId: user.uid,
            senderName: senderName,
            eventId: eventId,
            eventTitle: eventTitle,
            groupId: groupId,
          );
        }
      } else if (chatId != null) {
        final chat = await _directService.getChat(chatId);
        if (chat == null) return;
        final otherUid = chat.otherUserId(user.uid);
        if (otherUid.isEmpty) return;
        await _notificationService.createEventCreatedNotification(
          recipientId: otherUid,
          senderId: user.uid,
          senderName: senderName,
          eventId: eventId,
          eventTitle: eventTitle,
          chatId: chatId,
          otherUid: user.uid,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Event',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createEvent,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.lavenderAccent,
                    ),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(
                      color: AppColors.lavenderAccent,
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatDefaultBackground()),
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              left: 16,
              right: 16,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassCard(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _titleCtrl,
                        label: 'Title',
                        hint: "What's the event about?",
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descCtrl,
                        label: 'Description',
                        hint: 'Add more details...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassCard(child: _buildImagePickerField()),
                const SizedBox(height: 16),
                _GlassCard(
                  child: Column(
                    children: [
                      _buildLogisticsRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: _formatDateShort(_selectedDate),
                        onTap: _pickDate,
                      ),
                      const _GlassDivider(),
                      _buildLogisticsRow(
                        icon: Icons.timer,
                        label: 'Start',
                        child: _buildStartDropdown(),
                      ),
                      const _GlassDivider(),
                      _buildLogisticsRow(
                        icon: Icons.event_available,
                        label: 'End (optional)',
                        iconColor: _endDuration != null ? AppColors.lavenderAccent : AppColors.textSecondary,
                        child: _buildEndDropdown(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickSelector(
                      label: _getTodayTimeLabel(),
                      onTap: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _QuickSelector(
                      label: _getTomorrowLabel(),
                      onTap: () {
                        setState(() {
                          _selectedDate = DateTime.now().add(const Duration(days: 1));
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _GlassCard(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _locationCtrl,
                        label: 'Location',
                        hint: 'Where is the event?',
                        prefixIcon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _dressCodeCtrl,
                        label: 'Dress code',
                        hint: 'e.g. Casual, Formal, Black tie',
                        prefixIcon: Icons.checkroom,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Show response messages',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Post a message when someone changes their response',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(alpha: 0.7),
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _showRsvpMessages,
                        onChanged: (value) => setState(() => _showRsvpMessages = value),
                        activeThumbColor: AppColors.midnightBg,
                        activeTrackColor: AppColors.lavenderAccent,
                        inactiveTrackColor: AppColors.glassBorder,
                        thumbColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.midnightBg;
                          }
                          return AppColors.textSecondary;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildCreateButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'PlusJakartaSans',
        fontSize: 15,
      ),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textSecondary, size: 20)
            : null,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lavenderAccent, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 14,
        ),
      ),
    );
  }

  Widget _buildImagePickerField() {
    final image = _eventImage;

    if (image != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event photo',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'For best results, upload a 9:16 portrait image',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickEventImage,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    color: const Color(0xFF190831),
                    child: Image.file(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Text(
                          'Tap to change',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _eventImage = null),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: const Icon(Icons.close, size: 16, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickEventImage,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.lavenderAccent.withValues(alpha: 0.45),
          radius: 16,
        ),
        child: const SizedBox(
          width: double.infinity,
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.lavenderAccent,
                size: 34,
              ),
              SizedBox(height: 8),
              Text(
                'Add event photo',
                style: TextStyle(
                  color: AppColors.lavenderAccent,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Optional — makes your event card stand out',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'For best results, upload a 9:16 portrait image',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogisticsRow({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
    Widget? child,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.lavenderAccent, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (child != null) child,
            if (value != null)
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Duration>(
        value: _startOptions.any((e) => e.value == _startDuration)
            ? _startDuration
            : null,
        dropdownColor: const Color(0xFF211635),
        borderRadius: BorderRadius.circular(12),
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
        items: [
          ..._startOptions.map((e) => DropdownMenuItem(
                value: e.value,
                child: Text(
                  e.key,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                  ),
                ),
              )),
          const DropdownMenuItem(
            value: null,
            child: Text(
              'Custom...',
              style: TextStyle(
                color: AppColors.lavenderAccent,
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
              ),
            ),
          ),
        ],
        onChanged: (val) {
          if (val == null) {
            _pickCustomStart();
          } else {
            setState(() => _startDuration = val);
          }
        },
      ),
    );
  }

  Widget _buildEndDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Duration>(
        value: _endDuration,
        dropdownColor: const Color(0xFF211635),
        borderRadius: BorderRadius.circular(12),
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
        hint: const Text(
          'No end time',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
          ),
        ),
        items: [
          ..._endOptions.map((e) => DropdownMenuItem(
                value: e.value,
                child: Text(
                  e.key,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                  ),
                ),
              )),
          const DropdownMenuItem(
            value: null,
            child: Text(
              'Custom...',
              style: TextStyle(
                color: AppColors.lavenderAccent,
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
              ),
            ),
          ),
        ],
        onChanged: (val) {
          if (val == null && _endDuration == null) {
            _pickCustomEnd();
          } else if (val == null) {
            setState(() => _endDuration = null);
          } else {
            setState(() => _endDuration = val);
          }
        },
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _isCreating ? null : _createEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isCreating
                ? [AppColors.lavenderAccent.withValues(alpha: 0.4), AppColors.lavenderAccent.withValues(alpha: 0.4)]
                : [AppColors.lavenderAccent, const Color(0xFFc4a8ff)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: _isCreating
              ? []
              : [
                  BoxShadow(
                    color: AppColors.lavenderAccent.withValues(alpha: 0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 20,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCreating)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.midnightBg,
                ),
              )
            else ...[
              const Icon(Icons.add_rounded, color: AppColors.midnightBg, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              _isCreating ? 'Creating...' : 'Create Event',
              style: const TextStyle(
                color: AppColors.midnightBg,
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Divider(
        height: 1,
        color: AppColors.divider,
      ),
    );
  }
}

class _QuickSelector extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSelector({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lavenderAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: AppColors.lavenderAccent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.lavenderAccent,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Dashed rounded-rect border for the event photo picker ───────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth = 1.5;
  final double dashLength = 7;
  final double gapLength = 5;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashLength),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
