/// Represents a single question shown to the patient during recording.
class Question {
  final int number;
  final String text;

  Question({required this.number, required this.text});

  Map<String, dynamic> toJson() => {
    'question_number': number,
    'question_text': text,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    number: json['question_number'] as int,
    text: json['question_text'] as String,
  );
}
