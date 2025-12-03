import 'package:flutter/material.dart';

const _primaryPurple = Color(0xFF667eea);

/// Displays the current question text in a styled card.
class QuestionCard extends StatelessWidget {
  final String questionText;
  final int questionNumber;
  final int totalQuestions;

  const QuestionCard({
    super.key,
    required this.questionText,
    required this.questionNumber,
    required this.totalQuestions,
  });

  /// Scale font down for longer questions to keep card compact.
  double _fontSize(int len) {
    if (len < 30) return 24;
    if (len < 50) return 22;
    if (len < 70) return 20;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Question $questionNumber of $totalQuestions',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primaryPurple,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              questionText,
              style: TextStyle(
                fontSize: _fontSize(questionText.length),
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}