/// gradeQuiz / weakSkills unit tests.
library;

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:test/test.dart';

QuizItem quiz(String id, String skill, int answer) => QuizItem(
      id: id,
      skill: skill,
      prompt: 'prompt $id',
      options: const <String>['a', 'b', 'c', 'd'],
      answer: answer,
      explanation: LocalizedText(const <String, String>{'en': 'because'}),
      evidence: 'p1',
    );

void main() {
  group('gradeQuiz', () {
    test('scores correct/total/accuracy and wrong ids', () {
      final items = <QuizItem>[
        quiz('q1', 'detail', 0),
        quiz('q2', 'detail', 1),
        quiz('q3', 'inference', 2),
      ];
      final result = gradeQuiz(items, <String, int>{
        'q1': 0,
        'q2': 2,
        'q3': 2,
      });
      expect(result.correct, 2);
      expect(result.total, 3);
      expect(result.accuracy, closeTo(2 / 3, 1e-9));
      expect(result.wrongQuizIds, <String>['q2']);
      expect(result.bySkill, <String, int>{'detail': 1, 'inference': 1});
      expect(result.bySkillTotal, <String, int>{'detail': 2, 'inference': 1});
    });

    test('missing answers count as wrong', () {
      final items = <QuizItem>[
        quiz('q1', 'detail', 0),
        quiz('q2', 'detail', 1),
      ];
      final result = gradeQuiz(items, <String, int>{'q1': 0});
      expect(result.correct, 1);
      expect(result.total, 2);
      expect(result.wrongQuizIds, <String>['q2']);
    });

    test('empty quiz is vacuously perfect', () {
      final result = gradeQuiz(
          const <QuizItem>[], const <String, int>{});
      expect(result.correct, 0);
      expect(result.total, 0);
      expect(result.accuracy, 1.0);
      expect(result.wrongQuizIds, isEmpty);
    });

    test('is deterministic', () {
      final items = <QuizItem>[
        quiz('q1', 'detail', 0),
        quiz('q2', 'vocabulary', 1),
      ];
      final answers = <String, int>{'q1': 0};
      final a = gradeQuiz(items, answers);
      final b = gradeQuiz(items, answers);
      expect(a.correct, b.correct);
      expect(a.total, b.total);
      expect(a.accuracy, b.accuracy);
      expect(a.bySkill, b.bySkill);
      expect(a.bySkillTotal, b.bySkillTotal);
      expect(a.wrongQuizIds, b.wrongQuizIds);
    });
  });

  group('weakSkills', () {
    test('sorts by accuracy ascending and filters samples < 2', () {
      final bySkill = <String, int>{
        'detail': 4,
        'inference': 1,
        'sequence': 0,
      };
      final bySkillTotal = <String, int>{
        'detail': 5,
        'inference': 2,
        'sequence': 4,
        'mainIdea': 1, // sample size 1 -> filtered out
      };
      // detail 4/5=0.8, inference 1/2=0.5, sequence 0/4=0.0
      expect(
        weakSkills(bySkill, bySkillTotal),
        <String>['sequence', 'inference', 'detail'],
      );
    });

    test('breaks ties deterministically by skill name', () {
      final bySkill = <String, int>{'vocabulary': 1, 'detail': 1};
      final bySkillTotal = <String, int>{'vocabulary': 2, 'detail': 2};
      expect(
        weakSkills(bySkill, bySkillTotal),
        <String>['detail', 'vocabulary'],
      );
    });

    test('treats a missing bySkill entry as zero correct', () {
      final result = weakSkills(
        const <String, int>{},
        <String, int>{'inference': 3},
      );
      expect(result, <String>['inference']);
    });
  });
}
