import 'package:flutter/material.dart';

const _primaryPurple = Color(0xFF667eea);

/// Row of numbered circles showing progress through the questions.
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
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: done
                    ? Colors.green
                    : isCurrent
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
                border: isCurrent && !done
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: isCurrent
                    ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                    : null,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 28)
                    : Text(
                        '$num',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? _primaryPurple : Colors.white.withOpacity(0.7),
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