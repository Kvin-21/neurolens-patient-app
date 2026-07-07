import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

const _primaryTeal = Color(0xFF4DA8A2);

class RecordingButton extends StatefulWidget {
  final bool isRecording;
  final bool isRecorded;
  final VoidCallback onPressed;
  final Stream<double>? amplitudeStream;

  const RecordingButton({
    super.key,
    required this.isRecording,
    required this.isRecorded,
    required this.onPressed,
    this.amplitudeStream,
  });

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with TickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  late AnimationController _waveController;
  StreamSubscription<double>? _amplitudeSub;
  double _amplitude = 0.0;
  double _procAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _subscribeAmplitude();
  }

  @override
  void didUpdateWidget(RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream ||
        oldWidget.isRecording != widget.isRecording) {
      _subscribeAmplitude();
    }
    if (!widget.isRecording && (_amplitude != 0.0 || _procAmplitude != 0.0)) {
      setState(() {
        _amplitude = 0.0;
        _procAmplitude = 0.0;
      });
    }
  }

  void _subscribeAmplitude() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    if (widget.isRecording && widget.amplitudeStream != null) {
      _amplitudeSub = widget.amplitudeStream!.listen((a) {
        if (!mounted) return;
        setState(() {
          _amplitude = a;
          _handleIncomingAmplitude(a);
        });
      });
    }
  }

  void _handleIncomingAmplitude(double value) {
    final delta = (value - _procAmplitude).abs();
    if (delta >= 0.10) {
      _procAmplitude = value.clamp(0.0, 1.0);
    } else {
      // Small changes are softened a little so the bar does not jitter.
      _procAmplitude = _procAmplitude * 0.85 + value * 0.15;
    }
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _pulse.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 186,
            height: 146,
            child: AnimatedBuilder(
              animation: Listenable.merge([_scale, _waveController]),
              builder: (_, __) => Center(
                child: Transform.scale(
                  scale: widget.isRecording ? _scale.value : 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.isRecording
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : widget.isRecorded
                                ? [_primaryTeal, const Color(0xFF3D9690)]
                                : [_primaryTeal.withValues(alpha: 0.85), _primaryTeal],
                      ),
                      boxShadow: [
                        if (widget.isRecording)
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 6,
                          )
                        else if (!widget.isRecorded)
                          BoxShadow(
                            color: _primaryTeal.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: Icon(
                      widget.isRecording ? Icons.stop_rounded : Icons.mic,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (widget.isRecording)
            AnimatedBuilder(
              animation: Listenable.merge([_waveController]),
              builder: (_, __) => CustomPaint(
                painter: _DotBarPainter(
                  time: _waveController.value,
                  amplitude: _procAmplitude,
                ),
                size: const Size(176, 34),
              ),
            ),
        ],
      ),
    );
  }
}

class _DotBarPainter extends CustomPainter {
  final double time;
  final double amplitude;

  _DotBarPainter({required this.time, required this.amplitude});

  @override
  void paint(Canvas canvas, Size size) {
    final centreY = size.height / 2;
    const barCount = 30;
    final totalWidth = size.width * 0.85;
    final startX = (size.width - totalWidth) / 2;
    final barSpacing = totalWidth / barCount;

    final shader = const LinearGradient(
      colors: [Color(0xFF21C47B), Color(0xFF7ED957), Color(0xFFFFC857), Color(0xFFFF8A3D)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(startX, centreY - 20, totalWidth, 40));

    final paint = Paint()
      ..shader = shader
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke;

    const centreIdx = barCount ~/ 2;
    const maxBarHeight = 40.0;
    const minBarHeight = 3.5;
    final activeAmplitude = amplitude.clamp(0.0, 1.0);

    for (int i = 0; i < barCount; i++) {
      final x = startX + (i + 0.5) * barSpacing;

      final distFromCentre = (i - centreIdx).abs().toDouble();
      final centreFactor = (1.0 - (distFromCentre / (barCount / 2))).clamp(0.0, 1.0).toDouble();

      final mirroredIndex = min(i, barCount - 1 - i).toDouble();
      final sideWave = sin(time * 6.0 + mirroredIndex * 0.8) * 0.55 +
          cos(time * 3.5 + mirroredIndex * 0.35) * 0.35;
      final slightAsymmetry = sin(time * 4.2 + i * 0.21) * 0.18;

      final centreLift = pow(activeAmplitude, 1.18).toDouble() * centreFactor * maxBarHeight;
      final edgeVariance = activeAmplitude * (1.0 - centreFactor) * (0.9 + sideWave + slightAsymmetry);

      final finalHeight = (minBarHeight + centreLift + edgeVariance)
          .clamp(minBarHeight, maxBarHeight)
          .toDouble();

      final p1 = Offset(x, centreY - finalHeight);
      final p2 = Offset(x, centreY + finalHeight);

      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(_DotBarPainter old) =>
      old.time != time || old.amplitude != amplitude;
}
