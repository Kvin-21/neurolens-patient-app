import 'package:flutter/material.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _darkText = Color(0xFF2D3436);

class QuestionProgressIndicator extends StatelessWidget {
  final int currentQuestion;
  final List<bool> completedQuestions;
  final int totalQuestions;

  const QuestionProgressIndicator({
    super.key,
    required this.currentQuestion,
    required this.completedQuestions,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalQuestions, (i) {
          final num = i + 1;
          final done = completedQuestions[i];
          final isCurrent = num == currentQuestion;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isCurrent ? 42 : 36,
              height: isCurrent ? 42 : 36,
              decoration: BoxDecoration(
                color: done
                    ? _primaryTeal
                    : isCurrent
                        ? Colors.white
                        : _primaryTeal.withOpacity(0.08),
                shape: BoxShape.circle,
                border: isCurrent && !done
                    ? Border.all(color: _primaryTeal, width: 2.5)
                    : null,
                boxShadow: isCurrent
                    ? [BoxShadow(color: _primaryTeal.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)]
                    : null,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '$num',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? _primaryTeal : _darkText.withOpacity(0.35),
                        ),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }
}