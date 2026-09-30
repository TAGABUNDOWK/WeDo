import 'package:flutter/foundation.dart';

/// Shared signal between [HomePage]'s floating navigation bar and the
/// Friends screen's swipeable glass panel: when `true` the nav bar fades
/// out and ignores pointer events while the panel is open.
final ValueNotifier<bool> navBarHidden = ValueNotifier(false);
