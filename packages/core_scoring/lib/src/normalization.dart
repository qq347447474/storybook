/// Fixed English normalization pipeline for retell scoring
/// (`docs/04-scoring.md` §2.1, decision ②).
///
/// Pure and deterministic: lowercase -> contraction expansion -> number to
/// words -> punctuation to spaces -> word sequence. A lightweight symmetric
/// suffix stemmer then makes `raining` / `rained` / `rain` equivalent on both
/// the transcript and the concept-term side.
library;

/// Normalizes raw ASR text into a word sequence.
List<String> normalizeWords(String text) {
  var t = text.toLowerCase();
  t = _expandContractions(t);
  t = _numbersToWords(t);
  t = t.replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
  return t.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
}

/// Deterministic suffix stemmer (simple suffix rules only).
///
/// Handles plural/third-person `-s/-es/-ies`, past `-ed`, progressive `-ing`
/// (with consonant doubling like `running -> run`) and adverb `-ly`. Both
/// sides of every match must run through this function; irregular verbs and
/// silent-e pairs (`make`/`making`) are intentionally not rewritten — no
/// fuzzy matching beyond stemming is allowed.
String stemWord(String word) {
  if (word.length <= 3) return word;
  if (word.endsWith('ies') && word.length >= 4) {
    return '${word.substring(0, word.length - 3)}y';
  }
  if (word.endsWith('sses') ||
      word.endsWith('xes') ||
      word.endsWith('zes') ||
      word.endsWith('ches') ||
      word.endsWith('shes')) {
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('s') &&
      !word.endsWith('ss') &&
      !word.endsWith('us') &&
      !word.endsWith('is')) {
    return word.substring(0, word.length - 1);
  }
  if (word.endsWith('ing') && word.length >= 5) {
    var base = word.substring(0, word.length - 3);
    if (_doubledConsonant(base)) base = base.substring(0, base.length - 1);
    return base.length >= 3 ? base : word;
  }
  if (word.endsWith('ed') && word.length >= 4) {
    var base = word.substring(0, word.length - 2);
    if (_doubledConsonant(base)) base = base.substring(0, base.length - 1);
    return base.length >= 3 ? base : word;
  }
  if (word.endsWith('ly') && word.length >= 4) {
    return word.substring(0, word.length - 2);
  }
  return word;
}

/// Irregular contractions that must not be handled by the generic rules
/// (the generic `n't` rule would turn `can't` into `ca not`).
const Map<String, String> _specialContractions = <String, String>{
  "can't": 'can not',
  "won't": 'will not',
  "shan't": 'shall not',
  "ain't": 'is not',
  "let's": 'let us',
};

String _expandContractions(String text) {
  var t = text;
  _specialContractions.forEach((String from, String to) {
    t = t.replaceAll(RegExp('\\b$from\\b'), to);
  });
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)n't\b"), (Match m) => '${m[1]} not');
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)'re\b"), (Match m) => '${m[1]} are');
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)'ve\b"), (Match m) => '${m[1]} have');
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)'ll\b"), (Match m) => '${m[1]} will');
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)'d\b"), (Match m) => '${m[1]} would');
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)'m\b"), (Match m) => '${m[1]} am');
  t = t.replaceAllMapped(
      RegExp(r"\b([a-z]+)'s\b"), (Match m) => '${m[1]} is');
  return t;
}

/// Converts standalone integers in the range 0-999 to English words.
/// Values outside the range are left untouched.
String _numbersToWords(String text) {
  return text.replaceAllMapped(RegExp(r'\b\d+\b'), (Match m) {
    final int n = int.parse(m[0]!);
    return _intToWords(n);
  });
}

const List<String> _ones = <String>[
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
  'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
  'sixteen', 'seventeen', 'eighteen', 'nineteen',
];

const List<String> _tens = <String>[
  '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty',
  'ninety',
];

String _intToWords(int n) {
  if (n < 0 || n > 999) return '$n';
  if (n < 20) return _ones[n];
  if (n < 100) {
    final String head = _tens[n ~/ 10];
    final int rest = n % 10;
    return rest == 0 ? head : '$head ${_ones[rest]}';
  }
  final String head = '${_ones[n ~/ 100]} hundred';
  final int rest = n % 100;
  if (rest == 0) return head;
  return '$head ${_intToWords(rest)}';
}

/// True when [s] ends with a doublable consonant pair (`runn`, `stopp`).
bool _doubledConsonant(String s) {
  if (s.length < 2) return false;
  final String a = s[s.length - 1];
  final String b = s[s.length - 2];
  return a == b && 'bdglmnprt'.contains(a);
}
