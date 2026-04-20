import 'package:flutter/material.dart';

const _primaryTeal = Color(0xFF4DA8A2);

class RecordingButton extends StatefulWidget {
  final bool isRecording;
  final bool isRecorded;
  final VoidCallback onPressed;

  const RecordingButton({
    super.key,
    required this.isRecording,
    required this.isRecorded,
    required this.onPressed,
  });

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with TickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  late AnimationController _waveController;

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
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scale, _waveController]),
          builder: (_, __) => CustomPaint(
            painter: widget.isRecording
                ? _WaveRingPainter(progress: _waveController.value)
                : null,
            child: Center(
              child: Transform.scale(
                scale: widget.isRecording ? _scale.value : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isRecording
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : widget.isRecorded
                              ? [_primaryTeal, const Color(0xFF3D9690)]
                              : [_primaryTeal.withOpacity(0.85), _primaryTeal],
                    ),
                    boxShadow: [
                      if (widget.isRecording)
                        BoxShadow(
                          color: Colors.red.withOpacity(0.35),
                          blurRadius: 28,
                          spreadRadius: 6,
                        )
                      else if (!widget.isRecorded)
                        BoxShadow(
                          color: _primaryTeal.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop_rounded : Icons.mic,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveRingPainter extends CustomPainter {
  final double progress;
  _WaveRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - 4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (int i = 0; i < 3; i++) {
      final wave = (progress + i * 0.33) % 1.0;
      final radius = baseRadius + wave * 18;
      final opacity = (1.0 - wave).clamp(0.0, 0.45);
      paint.color = Colors.red.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveRingPainter old) => old.progress != progress;
}