/// scoreRetell unit tests: three-factor boundaries, normalization inside the
/// scorer (decision ②), concept pool (⑤), fluency span (⑥), feedback keys.
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:test/test.dart';

Concept concept(String id, List<String> terms, {bool required = false}) =>
    Concept(
      id: id,
      label: LocalizedText(<String, String>{'en': id}),
      terms: terms,
      required: required,
    );

Scene scene(List<Concept> concepts, {int targetWordCount = 10}) => Scene(
      id: 's-${concepts.length}-$targetWordCount',
      order: 1,
      image: Media(
        url: 'media/x.png',
        alt: LocalizedText(const <String, String>{'en': 'x'}),
      ),
      prompt: 'prompt',
      concepts: concepts,
      hint1: LocalizedText(const <String, String>{'en': 'h1'}),
      hint2: LocalizedText(const <String, String>{'en': 'h2'}),
      suggestedAnswer: 'answer',
      targetWordCount: targetWordCount,
    );

Rubric rubric({
  double conceptWeight = 0.6,
  double fluencyWeight = 0.2,
  double completenessWeight = 0.2,
  List<int> wpmTargetRange = const <int>[70, 120],
  int minWords = 30,
}) =>
    Rubric(
      minWords: minWords,
      maxSeconds: 90,
      conceptWeight: conceptWeight,
      fluencyWeight: fluencyWeight,
      completenessWeight: completenessWeight,
      wpmTargetRange: wpmTargetRange,
    );

/// [count] copies of `rain` — one token per word.
String rainWords(int count) => List<String>.filled(count, 'rain').join(' ');

void main() {
  group('normalization inside scoreRetell (decision 2)', () {
    test("contraction: transcript I'm hits term 'i am'", () {
      final score = scoreRetell(
        transcript: Transcript(
            text: "I'm ready", durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['i am'])]),
        ],
        rubric: rubric(),
      );
      expect(score.missingConceptIds, isEmpty);
    });

    test("contraction: can't hits term 'can not'", () {
      final score = scoreRetell(
        transcript: Transcript(
            text: "we can't swim", durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['can not'])]),
        ],
        rubric: rubric(),
      );
      expect(score.missingConceptIds, isEmpty);
    });

    test('numbers: 3 and 12 hit terms three / twelve', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: '3 cats and 12 dogs', durationMs: 5000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['three']),
            concept('c2', <String>['twelve']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(score.missingConceptIds, isEmpty);
    });

    test('punctuation and case are ignored', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'RAIN, Wind; and... Sun!',
            durationMs: 5000,
            pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['rain']),
            concept('c2', <String>['wind']),
            concept('c3', <String>['sun']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(score.concept, 1.0);
    });
  });

  group('word-form matching', () {
    test('raining / rained / rains all hit term rain', () {
      for (final surface in <String>['it rained', 'it is raining', 'it rains']) {
        final score = scoreRetell(
          transcript: Transcript(
              text: surface, durationMs: 2000, pauseGapsMs: const <int>[]),
          scenes: <Scene>[
            scene(<Concept>[concept('c1', <String>['rain'])]),
          ],
          rubric: rubric(),
        );
        expect(score.missingConceptIds, isEmpty, reason: surface);
      }
    });

    test('term rain does NOT hit inside train (word boundary)', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'the train passed by',
            durationMs: 3000,
            pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['rain'])]),
        ],
        rubric: rubric(),
      );
      expect(score.missingConceptIds, <String>['c1']);
    });

    test('multi-word terms match as consecutive runs', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'we could not go outside',
            durationMs: 3000,
            pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['could not go', 'cannot go']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(score.missingConceptIds, isEmpty);
    });
  });

  group('concept coverage (decision 5)', () {
    test('all concepts hit -> 1.0; none hit -> 0.0', () {
      final all = scoreRetell(
        transcript: Transcript(
            text: 'rain boat', durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['rain']),
            concept('c2', <String>['boat']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(all.concept, 1.0);

      final none = scoreRetell(
        transcript: Transcript(
            text: 'nothing relevant',
            durationMs: 3000,
            pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['rain']),
            concept('c2', <String>['boat']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(none.concept, 0.0);
      expect(none.missingConceptIds, <String>['c1', 'c2']);
    });

    test('required concept missed clamps coverage to 0.5', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'paper boat folded',
            durationMs: 3000,
            pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('req', <String>['wind'], required: true),
            concept('n1', <String>['paper']),
            concept('n2', <String>['boat']),
          ]),
        ],
        rubric: rubric(),
      );
      // raw coverage 2/3, clamped by the missed required concept.
      expect(score.concept, 0.5);
      expect(score.missingConceptIds, <String>['req']);
    });

    test('required concept hit does not clamp', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'wind paper',
            durationMs: 3000,
            pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('req', <String>['wind'], required: true),
            concept('n1', <String>['paper']),
            concept('n2', <String>['boat']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(score.concept, closeTo(2 / 3, 1e-9));
    });

    test('concepts from ALL scenes share one pool (decision 5)', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'rain only', durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['rain'])]),
          scene(<Concept>[
            concept('c2', <String>['boat']),
            concept('c3', <String>['paper']),
          ]),
        ],
        rubric: rubric(),
      );
      expect(score.concept, closeTo(1 / 3, 1e-9));
      expect(score.missingConceptIds, <String>['c2', 'c3']);
    });
  });

  group('fluency (decision 6)', () {
    // range [70, 120]: mid = 95, span = 50. 19 words / 12 s = 95 wpm.
    test('wpm exactly at mid -> 1.0', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: rainWords(19), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 19)],
        rubric: rubric(),
      );
      expect(score.fluency, closeTo(1.0, 1e-9));
    });

    test('deviation of one span -> 0.0 (above and below)', () {
      final high = scoreRetell(
        transcript: Transcript(
            text: rainWords(29), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 29)],
        rubric: rubric(),
      );
      expect(high.fluency, closeTo(0.0, 1e-9));

      final low = scoreRetell(
        transcript: Transcript(
            text: rainWords(9), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 9)],
        rubric: rubric(),
      );
      expect(low.fluency, closeTo(0.0, 1e-9));
    });

    test('half a span of deviation -> 0.5', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: rainWords(24), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 24)],
        rubric: rubric(),
      );
      expect(score.fluency, closeTo(0.5, 1e-9));
    });

    test('more than 3 long pauses (>2000ms) multiply fluency by 0.8', () {
      final base = scoreRetell(
        transcript: Transcript(
            text: rainWords(19), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 19)],
        rubric: rubric(),
      );
      final punished = scoreRetell(
        transcript: Transcript(
          text: rainWords(19),
          durationMs: 12000,
          pauseGapsMs: const <int>[2500, 2500, 2500, 2500],
        ),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 19)],
        rubric: rubric(),
      );
      expect(base.fluency, closeTo(1.0, 1e-9));
      expect(punished.fluency, closeTo(0.8, 1e-9));
    });

    test('exactly 3 long pauses are not punished', () {
      final score = scoreRetell(
        transcript: Transcript(
          text: rainWords(19),
          durationMs: 12000,
          pauseGapsMs: const <int>[2500, 2500, 2500],
        ),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 19)],
        rubric: rubric(),
      );
      expect(score.fluency, closeTo(1.0, 1e-9));
    });

    test('pauses of 2000ms or less are not long pauses', () {
      final score = scoreRetell(
        transcript: Transcript(
          text: rainWords(19),
          durationMs: 12000,
          pauseGapsMs: const <int>[2000, 2000, 2000, 2000, 2000],
        ),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 19)],
        rubric: rubric(),
      );
      expect(score.fluency, closeTo(1.0, 1e-9));
    });
  });

  group('completeness (decision 5 denominator)', () {
    test('0 words -> 0.0', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: '', durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(const <Concept>[], targetWordCount: 10)],
        rubric: rubric(),
      );
      expect(score.completeness, 0.0);
    });

    test('half the target -> 0.5; at target -> 1.0; above target capped', () {
      RetellScore at(int words) => scoreRetell(
            transcript: Transcript(
                text: rainWords(words),
                durationMs: 60000,
                pauseGapsMs: const <int>[]),
            scenes: <Scene>[scene(const <Concept>[], targetWordCount: 10)],
            rubric: rubric(),
          );
      expect(at(5).completeness, closeTo(0.5, 1e-9));
      expect(at(10).completeness, closeTo(1.0, 1e-9));
      expect(at(20).completeness, closeTo(1.0, 1e-9));
    });

    test('denominator is the SUM of scene targetWordCount', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: rainWords(10), durationMs: 60000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(const <Concept>[], targetWordCount: 10),
          scene(const <Concept>[], targetWordCount: 15),
        ],
        rubric: rubric(),
      );
      expect(score.completeness, closeTo(10 / 25, 1e-9));
    });
  });

  group('weighted total', () {
    test('all factors 1.0 with default weights -> 1.0', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: rainWords(19), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['rain'])], targetWordCount: 19),
        ],
        rubric: rubric(),
      );
      expect(score.concept, closeTo(1.0, 1e-9));
      expect(score.fluency, closeTo(1.0, 1e-9));
      expect(score.completeness, closeTo(1.0, 1e-9));
      expect(score.total, closeTo(1.0, 1e-9));
    });

    test('respects a non-default rubric (0.5/0.25/0.25)', () {
      // 1 rain word, 10 minutes: wpm ~ 0.1 -> fluency 0; completeness 0.1.
      final score = scoreRetell(
        transcript: Transcript(
            text: 'rain', durationMs: 600000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['rain'])], targetWordCount: 10),
        ],
        rubric: rubric(
            conceptWeight: 0.5,
            fluencyWeight: 0.25,
            completenessWeight: 0.25),
      );
      expect(score.concept, closeTo(1.0, 1e-9));
      expect(score.fluency, closeTo(0.0, 1e-9));
      expect(score.completeness, closeTo(0.1, 1e-9));
      expect(score.total, closeTo(0.5 * 1.0 + 0.25 * 0.0 + 0.25 * 0.1, 1e-9));
    });
  });

  group('feedbackKeys (C4: i18n keys only)', () {
    test('no speech returns only retell.feedback.noSpeech', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: '   ', durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[scene(<Concept>[concept('c1', <String>['rain'])])],
        rubric: rubric(),
      );
      expect(score.feedbackKeys, <String>['retell.feedback.noSpeech']);
    });

    test('too short, partial concepts and low fluency map to their keys', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: 'rain and wind', durationMs: 600000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['rain']),
            concept('c2', <String>['boat']),
          ]),
        ],
        rubric: rubric(),
      );
      // Missed concepts (boat) are NOT a feedback key — the UI renders them
      // as content concept labels via missingConceptIds (docs/08 S5).
      expect(score.missingConceptIds, <String>['c2']);
      expect(score.feedbackKeys, <String>[
        'retell.feedback.tooShort', // 3 words < minWords 30
        'retell.feedback.concepts', // 1 hit
        'retell.feedback.fluency', // wpm far below target
      ]);
    });

    test('good run maps to concepts + fluencyOk, no missing/short', () {
      final score = scoreRetell(
        transcript: Transcript(
            text: rainWords(19), durationMs: 12000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[concept('c1', <String>['rain'])], targetWordCount: 19),
        ],
        rubric: rubric(minWords: 10), // 19 words is a complete run here
      );
      expect(score.feedbackKeys, <String>[
        'retell.feedback.concepts',
        'retell.feedback.fluencyOk',
      ]);
    });

    test('every returned key exists in the real i18n/en.json catalog', () {
      // C4: feedbackKeys must be real i18n keys — verified against the
      // actual catalog (single source of truth), not a hardcoded set.
      final Map<String, dynamic> catalog = json.decode(
        File('../../i18n/en.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final score = scoreRetell(
        transcript: Transcript(
            text: 'rain', durationMs: 3000, pauseGapsMs: const <int>[]),
        scenes: <Scene>[
          scene(<Concept>[
            concept('c1', <String>['rain'], required: true),
            concept('c2', <String>['boat'], required: true),
          ]),
        ],
        rubric: rubric(),
      );
      expect(score.feedbackKeys, isNotEmpty);
      for (final key in score.feedbackKeys) {
        expect(catalog.containsKey(key), isTrue,
            reason: 'key "$key" missing from i18n/en.json');
      }
    });
  });

  group('determinism (C3)', () {
    test('same input twice -> identical fields', () {
      Transcript t = Transcript(
        text: "I'm 3 rain cats, can't stop raining!",
        durationMs: 9000,
        pauseGapsMs: const <int>[2500, 3000, 4000, 5000],
      );
      List<Scene> s = <Scene>[
        scene(<Concept>[
          concept('c1', <String>['rain'], required: true),
          concept('c2', <String>['three']),
          concept('c3', <String>['paper boat']),
        ]),
      ];
      Rubric r = rubric();
      final a = scoreRetell(transcript: t, scenes: s, rubric: r);
      final b = scoreRetell(transcript: t, scenes: s, rubric: r);
      expect(a.concept, b.concept);
      expect(a.fluency, b.fluency);
      expect(a.completeness, b.completeness);
      expect(a.total, b.total);
      expect(a.missingConceptIds, b.missingConceptIds);
      expect(a.feedbackKeys, b.feedbackKeys);
    });
  });
}
