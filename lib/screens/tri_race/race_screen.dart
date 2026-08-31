import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/tri_race_entity.dart';
import '../../services/tri_race/tri_race_service.dart';
import 'tri_race_results_screen.dart';

const _fontFamily = 'PlusJakartaSans';

// ── Cached segment data for piecewise progress ──────────────────────────────

class _Segment {
  final double start;
  final double speedMultiplier;
  const _Segment(this.start, this.speedMultiplier);
}

List<_Segment> _buildSegments(double speedSeed) {
  final rng = Random(speedSeed.hashCode);
  final count = 4 + rng.nextInt(3);
  final segLen = 1.0 / count;
  return List.generate(count, (i) => _Segment(i * segLen, 0.3 + rng.nextDouble() * 1.4));
}

double _piecewiseProgress(double t, List<_Segment> segments) {
  if (segments.isEmpty) return 0;
  final segLen = 1.0 / segments.length;

  var totalWeight = 0.0;
  for (final seg in segments) {
    totalWeight += seg.speedMultiplier;
  }

  var accumulated = 0.0;
  for (final seg in segments) {
    if (t >= seg.start) {
      final segProgress = ((t - seg.start) / segLen).clamp(0.0, 1.0);
      accumulated += segLen * seg.speedMultiplier * segProgress;
    } else {
      break;
    }
  }

  // Normalize so t == 1.0 always maps to exactly 1.0: the triangle reaches
  // the finish line precisely when the racer's time is up. This keeps the
  // visual finish order aligned with the server-authoritative placement.
  final total = segLen * totalWeight;
  if (total <= 0) return accumulated.clamp(0.0, 1.0);
  return (accumulated / total).clamp(0.0, 1.0);
}

// ── Race Screen ─────────────────────────────────────────────────────────────

class RaceScreen extends StatefulWidget {
  final String raceId;
  final bool isHost;
  const RaceScreen({super.key, required this.raceId, this.isHost = false});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = TriRaceService();
  late final AnimationController _ticker;

  List<TriRaceParticipant> _participants = [];
  DateTime? _raceStartedAt;
  int _raceDurationMs = 14000;
  StreamSubscription<TriRace?>? _raceSub;
  StreamSubscription<List<TriRaceParticipant>>? _participantsSub;

  final Set<String> _arrived = {};
  bool _finishHandled = false;
  bool _showingResults = false;
  bool _isLoading = true;
  String? _loadError;
  Timer? _landscapeKeeper;

  // Cached data — rebuilt only when participants change
  final Map<String, Color> _colors = {};
  final Map<String, Color?> _colorEnds = {};
  final Map<String, List<_Segment>> _segments = {};

  // Rotation state — updated every frame from ticker, no separate timers
  final Map<String, double> _rotations = {};
  final Map<String, Random> _rotRngs = {};
  final Map<String, double> _nextRotChange = {};
  double _lastRotationTick = 0;

  static const double _worldWidthFactor = 4.0;
  static const double _finishLineOffset = 100;

  // Camera — reactive leader-follow, updated every frame from the ticker
  static const double _cameraLeadFactor = 0.45;
  static const double _cameraDamping = 6.0;
  double _cameraX = 0;
  double _screenW = 0;
  double _lastCameraTick = 0;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setLandscape();
    // Re-assert once the first frame renders and again after the route
    // transition settles — guards against the OS snapping back to portrait.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setLandscape();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _setLandscape();
    });
    // Keep the orientation request "fresh" — re-assert once per second so the
    // OS has no chance to fall back to portrait (rotation-lock snap-back).
    _landscapeKeeper = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _setLandscape();
    });
    WakelockPlus.enable();

    _ticker = AnimationController(vsync: this, duration: const Duration(days: 365))
      ..addListener(_onTick)
      ..repeat();

    _initRace();
  }

  void _setLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rotation sensor state can be re-applied by the OS on resume; re-assert.
    if (state == AppLifecycleState.resumed) {
      if (mounted) _setLandscape();
    }
  }

  @override
  void didChangeMetrics() {
    // Fires whenever the OS changes window size/orientation — exactly the
    // moment it would snap back to portrait. Immediately re-assert landscape.
    if (mounted) {
      final size = MediaQuery.of(context).size;
      debugPrint('RaceScreen orientation metric changed: '
          '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)} '
          '-> re-asserting landscape');
      _setLandscape();
    }
  }

  // ── Data init + live subscriptions ─────────────────────────────────────

  Future<void> _initRace() async {
    // Subscribe to race doc — keeps raceStartedAt, raceDurationMs fresh; detects finished
    _raceSub = _service.getTriRaceStream(widget.raceId).listen((race) {
      if (!mounted || race == null) return;
      setState(() {
        _raceDurationMs = race.raceDurationMs ?? _raceDurationMs;
        if (race.raceStartedAt != null) _raceStartedAt = race.raceStartedAt;
      });
      if (race.status == TriRaceStatus.finished && !_finishHandled) {
        _finishHandled = true;
        _showRaceFinished();
      }
    });

    // Subscribe to participants — single source of truth for triangle data.
    // finishTimeMs / speedSeed / placement arrive when the start batch lands.
    _participantsSub = _service.getParticipantsStream(widget.raceId).listen((list) {
      if (!mounted) return;
      setState(() {
        _participants = list;
        _rebuildCaches();
      });
    });

    // One-shot fetch for immediate race doc data (raceStartedAt, raceDurationMs)
    try {
      final race = await _service.fetchTriRace(widget.raceId);
      if (race == null) {
        if (mounted) setState(() { _isLoading = false; _loadError = 'Race not found'; });
        return;
      }

      // Already over? Go straight to results instead of showing a race that
      // would instantly finish and snap the screen back to portrait.
      final startTime = race.raceStartedAt;
      final duration = race.raceDurationMs ?? _raceDurationMs;
      final alreadyOver = race.status == TriRaceStatus.finished ||
          (startTime != null &&
              DateTime.now().difference(startTime).inMilliseconds >= duration);
      if (alreadyOver && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TriRaceResultsScreen(raceId: widget.raceId),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _raceDurationMs = duration;
          _raceStartedAt = startTime;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _loadError = 'Failed to load race'; });
    }
  }

  // ── Race finished — brief pause then navigate to results ─────────────────

  void _showRaceFinished() {
    if (!mounted || _showingResults) return;
    setState(() => _showingResults = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TriRaceResultsScreen(raceId: widget.raceId)),
        );
      }
    });
  }

  Future<void> _handleFinish() async {
    try {
      await _service.markTriRaceFinished(widget.raceId);
    } catch (e) {
      debugPrint('markTriRaceFinished failed: $e');
    }
    _showRaceFinished();
  }

  // ── Frame-driven update — runs every frame at 60fps ──────────────────────

  void _onTick() {
    if (!mounted || _raceStartedAt == null || _showingResults) return;
    _epoch++;

    // Update rotations in batch
    final now = _ticker.lastElapsedDuration?.inMilliseconds.toDouble() ?? 0;
    final dt = now - _lastRotationTick;
    if (dt > 100) {
      _lastRotationTick = now;
      for (final p in _participants) {
        final nextChange = _nextRotChange[p.userId] ?? 0;
        if (now >= nextChange) {
          final rng = _rotRngs[p.userId]!;
          _rotations[p.userId] = (rng.nextDouble() - 0.5) * 20;
          _nextRotChange[p.userId] = now + 800 + rng.nextInt(700);
        }
      }
    }

    // Arrival detection — catches arrivals instantly
    for (final p in _participants) {
      if (p.finishTimeMs != null && !_arrived.contains(p.userId)) {
        final progress = _computeProgress(p);
        if (progress >= 1.0) {
          _arrived.add(p.userId);
        }
      }
    }

    // When all arrived OR elapsed past raceDurationMs — mark finished
    if (_participants.isNotEmpty && !_finishHandled) {
      final elapsed = DateTime.now().difference(_raceStartedAt!).inMilliseconds;
      if (_arrived.length == _participants.length || elapsed >= _raceDurationMs) {
        _finishHandled = true;
        _handleFinish();
      }
    }

    // Reactive camera — tracks whoever is currently FIRST, live every frame.
    // The anchor follows the max visual progress so overtakes move the camera
    // instantly toward the new leader, without ever outrunning the pack.
    final trackLength = (_screenW * _worldWidthFactor) - _finishLineOffset - 40;
    double leaderDisplay = 0;
    for (final p in _participants) {
      final display = _visualProgress(p);
      if (display > leaderDisplay) leaderDisplay = display;
    }
    final maxCameraX = _screenW * (_worldWidthFactor - 1.0);
    final desired = (leaderDisplay * trackLength - _screenW * _cameraLeadFactor)
        .clamp(0.0, maxCameraX);

    final cameraDtMs = now - _lastCameraTick;
    if (cameraDtMs > 0) {
      _lastCameraTick = now;
      _cameraX += (desired - _cameraX) * (1 - exp(-_cameraDamping * cameraDtMs / 1000.0));
      _cameraX = _cameraX.clamp(0.0, maxCameraX);
    } else {
      _cameraX = desired;
    }

    // Trigger rebuild for triangle positions + leaderboard
    setState(() {});
  }

  // ── Cache rebuilding ────────────────────────────────────────────────────

  void _rebuildCaches() {
    _colors.clear();
    _colorEnds.clear();
    _segments.clear();
    for (final p in _participants) {
      _colors[p.userId] = Color(int.parse(p.avatarColor.replaceFirst('#', '0xFF')));
      _colorEnds[p.userId] = p.avatarColorEnd != null
          ? Color(int.parse(p.avatarColorEnd!.replaceFirst('#', '0xFF')))
          : null;
      _segments[p.userId] = _buildSegments(p.speedSeed ?? 0.5);

      if (!_rotRngs.containsKey(p.userId)) {
        final rng = Random(p.speedSeed?.hashCode ?? 0);
        _rotRngs[p.userId] = rng;
        _rotations[p.userId] = 0;
        _nextRotChange[p.userId] = 0;
      }
    }
  }

  double _computeProgress(TriRaceParticipant p) {
    if (_raceStartedAt == null || p.finishTimeMs == null) return 0;
    final elapsed = DateTime.now().difference(_raceStartedAt!).inMilliseconds;
    return (elapsed / p.finishTimeMs!).clamp(0.0, 1.0);
  }

  // Visual (on-screen) progress — normalized piecewise of the linear progress.
  // This matches the triangle position painted on screen exactly.
  double _visualProgress(TriRaceParticipant p) {
    final linear = _computeProgress(p);
    final segs = _segments[p.userId];
    if (segs == null || segs.isEmpty) return linear;
    return _piecewiseProgress(linear, segs);
  }

  @override
  void dispose() {
    _landscapeKeeper?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _raceSub?.cancel();
    _participantsSub?.cancel();
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenW = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0221),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4))),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0221),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final worldWidth = screenW * _worldWidthFactor;

    final elapsed = _raceStartedAt != null
        ? DateTime.now().difference(_raceStartedAt!).inMilliseconds
        : 0;
    final overallProgress = _raceDurationMs > 0
        ? (elapsed / _raceDurationMs).clamp(0.0, 1.0)
        : 0.0;
    final cameraX = _cameraX;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0221),
      body: Stack(
        children: [
          // ── Background (repaints once, never again) ──
          Positioned(
            left: -cameraX * 0.3,
            top: 0,
            width: worldWidth,
            height: screenH,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _BackgroundPainter(worldWidth, screenH),
              ),
            ),
          ),

          // ── Ground (repaints once, never again) ──
          Positioned(
            left: -cameraX,
            top: 0,
            width: worldWidth,
            height: screenH,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GroundPainter(worldWidth, screenH, _participants.length),
              ),
            ),
          ),

          // ── Finish line ──
          Positioned(
            left: worldWidth - _finishLineOffset - cameraX,
            top: 0,
            width: 4,
            height: screenH,
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.8),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Finish line label ──
          Positioned(
            left: worldWidth - _finishLineOffset - cameraX - 20,
            top: 10,
            child: Text(
              'FINISH',
              style: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
          ),

          // ── Participant triangles (single repaint boundary) ──
          RepaintBoundary(
            child: CustomPaint(
              size: Size(screenW, screenH),
              painter: _TriangleLayerPainter(
                participants: _participants,
                colors: _colors,
                colorEnds: _colorEnds,
                segments: _segments,
                rotations: _rotations,
                computeProgress: _computeProgress,
                worldWidth: worldWidth,
                screenH: screenH,
                cameraX: cameraX,
                finishLineOffset: _finishLineOffset,
                epoch: _epoch,
              ),
            ),
          ),

          // ── Progress bar ──
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4ECDC4)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(elapsed / 1000).toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${(_raceDurationMs / 1000).toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Leaderboard (reactive ranking by live progress) ──
          Positioned(
            top: 50,
            right: 12,
            child: RepaintBoundary(
              child: _LeaderboardPanel(
                participants: _participants,
                arrived: _arrived,
                colors: _colors,
                visualProgress: _visualProgress,
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ── Triangle Layer Painter (draws all triangles in one pass) ────────────────

class _TriangleLayerPainter extends CustomPainter {
  final List<TriRaceParticipant> participants;
  final Map<String, Color> colors;
  final Map<String, Color?> colorEnds;
  final Map<String, List<_Segment>> segments;
  final Map<String, double> rotations;
  final double Function(TriRaceParticipant) computeProgress;
  final double worldWidth;
  final double screenH;
  final double cameraX;
  final double finishLineOffset;
  final int epoch;

  _TriangleLayerPainter({
    required this.participants,
    required this.colors,
    required this.colorEnds,
    required this.segments,
    required this.rotations,
    required this.computeProgress,
    required this.worldWidth,
    required this.screenH,
    required this.cameraX,
    this.finishLineOffset = 100,
    this.epoch = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (participants.isEmpty) return;

    final laneHeight = (screenH - 80) / participants.length;
    const triangleSize = Size(40, 34);

    for (int i = 0; i < participants.length; i++) {
      final p = participants[i];
      final color = colors[p.userId] ?? Colors.white;
      final segs = segments[p.userId];
      if (segs == null) continue;

      final progress = computeProgress(p);
      final displayProgress = _piecewiseProgress(progress, segs);
      final triangleX = displayProgress * (worldWidth - finishLineOffset - 40);
      final laneY = 60.0 + i * laneHeight + laneHeight / 2;
      final rotation = rotations[p.userId] ?? 0;

      final cx = triangleX - cameraX + triangleSize.width / 2;
      final cy = laneY;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotation * pi / 180);

      final path = Path()
        ..moveTo(0, -triangleSize.height / 2)
        ..lineTo(triangleSize.width / 2, triangleSize.height / 2)
        ..lineTo(-triangleSize.width / 2, triangleSize.height / 2)
        ..close();

      final fillPaint = Paint()
        ..style = PaintingStyle.fill;

      final colorEnd = colorEnds[p.userId];
      if (colorEnd != null) {
        fillPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, colorEnd],
        ).createShader(Rect.fromLTWH(
          -triangleSize.width / 2,
          -triangleSize.height / 2,
          triangleSize.width,
          triangleSize.height,
        ));
      } else {
        fillPaint.color = color;
      }
      canvas.drawPath(path, fillPaint);

      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, borderPaint);

      canvas.restore();

      final textPainter = TextPainter(
          text: TextSpan(
            text: p.username,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(triangleX - cameraX + 4, cy + triangleSize.height / 2 + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TriangleLayerPainter old) {
    return old.epoch != epoch ||
        old.participants != participants ||
        old.cameraX != cameraX ||
        !mapEquals(old.rotations, rotations);
  }
}

// ── Background Painter (abstract parallax) ──────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  final double worldWidth;
  final double worldHeight;
  _BackgroundPainter(this.worldWidth, this.worldHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);

    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * worldWidth;
      final y = rng.nextDouble() * worldHeight;
      final radius = 2.0 + rng.nextDouble() * 20;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.02 + rng.nextDouble() * 0.04),
      );
    }

    for (int i = 0; i < 15; i++) {
      final y = rng.nextDouble() * worldHeight;
      final startX = rng.nextDouble() * worldWidth;
      final length = 20.0 + rng.nextDouble() * 80;

      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + length, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.03)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Ground Painter (lane dividers) ──────────────────────────────────────────

class _GroundPainter extends CustomPainter {
  final double worldWidth;
  final double worldHeight;
  final int laneCount;
  _GroundPainter(this.worldWidth, this.worldHeight, this.laneCount);

  @override
  void paint(Canvas canvas, Size size) {
    if (laneCount == 0) return;

    final laneHeight = (worldHeight - 80) / laneCount;

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 1; i < laneCount; i++) {
      final y = 60.0 + i * laneHeight;
      double x = 0;
      while (x < worldWidth) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 12, y),
          dashPaint,
        );
        x += 24;
      }
    }

    final startPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2;
    canvas.drawLine(
      const Offset(40, 40),
      Offset(40, worldHeight - 40),
      startPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Leaderboard Panel (reactive — sorts by live progress) ───────────────────

class _LeaderboardPanel extends StatelessWidget {
  final List<TriRaceParticipant> participants;
  final Set<String> arrived;
  final Map<String, Color> colors;
  final double Function(TriRaceParticipant) visualProgress;

  const _LeaderboardPanel({
    required this.participants,
    required this.arrived,
    required this.colors,
    required this.visualProgress,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<TriRaceParticipant>.from(participants)
      ..sort((a, b) {
        final aFinished = arrived.contains(a.userId);
        final bFinished = arrived.contains(b.userId);

        // Finished participants always on top, sorted by placement
        if (aFinished && !bFinished) return -1;
        if (!aFinished && bFinished) return 1;
        if (aFinished && bFinished) return (a.placement ?? 999).compareTo(b.placement ?? 999);

        // In-progress sorted by current progress (higher progress = higher rank)
        return visualProgress(b).compareTo(visualProgress(a));
      });

    return Container(
      width: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LEADERBOARD',
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ...sorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final p = entry.value;
            final isArrived = arrived.contains(p.userId);
            final color = colors[p.userId] ?? Colors.white;
            final medal = (isArrived && p.placement != null && p.placement! <= 3)
                ? const ['🥇', '🥈', '🥉'][p.placement! - 1]
                : '';

            return AnimatedOpacity(
              opacity: isArrived ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    if (medal.isNotEmpty) ...[
                      Text(medal, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                    ] else ...[
                      Container(
                        width: 16,
                        alignment: Alignment.center,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.username,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isArrived ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
