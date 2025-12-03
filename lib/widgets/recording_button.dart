import 'package:flutter/material.dart';

/// Animated microphone button that pulses while recording.
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
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: widget.isRecording ? _scale.value : 1.0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isRecording
                    ? [Colors.red.shade400, Colors.red.shade700]
                    : widget.isRecorded
                        ? [Colors.green.shade600, Colors.green.shade800]
                        : [Colors.green.shade400, Colors.green.shade600],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isRecording
                      ? Colors.red.withOpacity(0.4)
                      : widget.isRecorded
                          ? Colors.transparent
                          : Colors.green.withOpacity(0.3),
                  blurRadius: widget.isRecording ? 30 : 20,
                  spreadRadius: widget.isRecording ? 10 : 5,
                ),
              ],
            ),
            child: Icon(
              widget.isRecording ? Icons.stop : Icons.mic,
              size: 70,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}