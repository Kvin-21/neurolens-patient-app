import 'package:flutter/material.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _darkText = Color(0xFF2D3436);

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Question $questionNumber of $totalQuestions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primaryTeal.withOpacity(0.8),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              questionText,
              style: TextStyle(
                fontSize: _fontSize(questionText.length),
                fontWeight: FontWeight.w600,
                color: _darkText,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}