/// Quiz grading (`docs/07-modules.md` §3.1). Pure functions only (C3).
library;

import 'package:core_content/core_content.dart';

/// Aggregated result of one quiz attempt.
class QuizResult {
  const QuizResult({
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.bySkill,
    required this.bySkillTotal,
    required this.wrongQuizIds,
  });

  final int correct;
  final int total;

  /// `correct / total`; 1.0 when the quiz has no items (vacuously perfect).
  final double accuracy;

  /// skill -> number of correct answers (0 when a skill had none).
  final Map<String, int> bySkill;

  /// skill -> number of questions asked.
  final Map<String, int> bySkillTotal;

  /// Ids of the items answered wrong or left unanswered, in item order.
  final List<String> wrongQuizIds;
}

/// Grades [items] against [answers] (quizId -> selected option index).
///
/// Missing answers count as wrong. The result is fully determined by the
/// inputs: no clock, no randomness, no IO.
QuizResult gradeQuiz(List<QuizItem> items, Map<String, int> answers) {
  var correct = 0;
  final bySkill = <String, int>{};
  final bySkillTotal = <String, int>{};
  final wrongQuizIds = <String>[];
  for (final QuizItem item in items) {
    bySkillTotal[item.skill] = (bySkillTotal[item.skill] ?? 0) + 1;
    bySkill.putIfAbsent(item.skill, () => 0);
    final int? picked = answers[item.id];
    if (picked != null && picked == item.answer) {
      correct += 1;
      bySkill[item.skill] = (bySkill[item.skill] ?? 0) + 1;
    } else {
      wrongQuizIds.add(item.id);
    }
  }
  final int total = items.length;
  final double accuracy = total == 0 ? 1.0 : correct / total;
  return QuizResult(
    correct: correct,
    total: total,
    accuracy: accuracy,
    bySkill: Map<String, int>.unmodifiable(bySkill),
    bySkillTotal: Map<String, int>.unmodifiable(bySkillTotal),
    wrongQuizIds: List<String>.unmodifiable(wrongQuizIds),
  );
}

/// Returns weak skills sorted by accuracy ascending, keeping only skills
/// with at least 2 samples. Ties break on skill name ascending so the order
/// is deterministic. This is the single source of weakness attribution (§3.1):
/// the UI must only echo these skill names, never invent reasons.
List<String> weakSkills(
  Map<String, int> bySkill,
  Map<String, int> bySkillTotal,
) {
  final candidates = <(String, double)>[];
  bySkillTotal.forEach((String skill, int total) {
    if (total < 2) return;
    final int correct = bySkill[skill] ?? 0;
    candidates.add((skill, correct / total));
  });
  candidates.sort(((String, double) a, (String, double) b) {
    final int byRate = a.$2.compareTo(b.$2);
    return byRate != 0 ? byRate : a.$1.compareTo(b.$1);
  });
  return candidates.map(((String, double) e) => e.$1).toList();
}
