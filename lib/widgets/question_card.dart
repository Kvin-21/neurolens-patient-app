import 'package:flutter/material.dart';

const _primaryTeal = Color(0xFF4DA8A2);
const _darkText = Color(0xFF2D3436);

class QuestionCard extends StatelessWidget {
  final String questionText;
  final int questionNumber;
  final int totalQuestions;
  final String? imageAssetPath;

  const QuestionCard({
    super.key,
    required this.questionText,
    required this.questionNumber,
    required this.totalQuestions,
    this.imageAssetPath,
  });

  double _fontSize(int len) {
    if (len < 30) return 22;
    if (len < 50) return 20;
    if (len < 70) return 19;
    return 17;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final compact = screenHeight < 800;
    final shortQuestion = questionText.length <= 95;
    final imageHeight = compact ? 130.0 : 160.0;
    final cardPadding = compact
      ? (shortQuestion ? 10.0 : 12.0)
      : (shortQuestion ? 14.0 : 16.0);
    final questionFont = compact ? _fontSize(questionText.length) - 1 : _fontSize(questionText.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(cardPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Question $questionNumber of $totalQuestions',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: _primaryTeal.withOpacity(0.8),
                letterSpacing: 1.0,
              ),
            ),
            if (imageAssetPath != null) ...[
              SizedBox(height: compact ? 10 : 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: imageHeight,
                  width: double.infinity,
                  color: Colors.grey.shade50,
                  alignment: Alignment.center,
                  child: Image.asset(
                    imageAssetPath!,
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: imageHeight,
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: Text(
                          'Image unavailable',
                          style: TextStyle(
                            color: _darkText.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SizedBox(height: compact ? 10 : 14),
            Text(
              questionText,
              style: TextStyle(
                fontSize: questionFont.clamp(17, 22).toDouble(),
                fontWeight: FontWeight.w600,
                color: _darkText,
                height: 1.22,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}