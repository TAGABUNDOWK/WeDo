import 'package:flutter/material.dart';

import '../../services/auth/user_service.dart';
import '../../services/group/group_service.dart';

/// Big avatar used on incoming/outgoing call screens.
///
/// Group calls show the group chat's profile photo; direct (1:1) calls show
/// the other person's profile photo. Falls back to an initial letter while
/// loading or when no photo exists.
class CallAvatar extends StatefulWidget {
  final String? groupId;
  final String? userUid;
  final String fallbackName;
  final double radius;

  const CallAvatar({
    super.key,
    this.groupId,
    this.userUid,
    required this.fallbackName,
    this.radius = 55,
  });

  @override
  State<CallAvatar> createState() => _CallAvatarState();
}

class _CallAvatarState extends State<CallAvatar> {
  String? _photoUrl;
  bool _isAsset = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    String? url;
    var isAsset = false;
    try {
      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        final group = await GroupService().getGroup(widget.groupId!);
        url = group?.photoUrl;
      } else if (widget.userUid != null && widget.userUid!.isNotEmpty) {
        final user = await UserService().getUserDocument(widget.userUid!);
        if (user != null) {
          if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
            url = user.photoUrl;
          } else if (user.avatarAsset != null && user.avatarAsset!.isNotEmpty) {
            url = user.avatarAsset;
            isAsset = true;
          }
        }
      }
    } catch (_) {
      // Fall through to the initial-letter avatar.
    }
    if (!mounted) return;
    setState(() {
      _photoUrl = url != null && url.isNotEmpty ? url : null;
      _isAsset = isAsset;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _loaded && _photoUrl != null;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: const Color(0xFFFE4EF0).withValues(alpha: 0.3),
      backgroundImage: hasPhoto
          ? (_isAsset
              ? AssetImage(_photoUrl!)
              : NetworkImage(_photoUrl!))
          : null,
      child: !hasPhoto
          ? Text(
              widget.fallbackName.isNotEmpty
                  ? widget.fallbackName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: widget.radius * 0.8,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
