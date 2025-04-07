import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(Read4everApp());

class Read4everApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Read4ever',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SentenceReader(),
    );
  }
}
//test

class Sentence {
  final String chinese;
  final String translation;
  final List<String> tokens;

  Sentence({required this.chinese, required this.translation, required this.tokens});

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      chinese: json['chinese'],
      translation: json['translation'],
      tokens: List<String>.from(json['tokens']),
    );
  }
}

class WordScores {
  Map<String, int> scores = {};

  void increment(String word) {
    scores[word] = (scores[word] ?? 0) + 1;
  }

  int get(String word) => scores[word] ?? 0;

  int getSentenceScore(List<String> tokens) {
    return tokens.fold(0, (sum, w) => sum + get(w));
  }

  Map<String, dynamic> toJson() => scores;

  WordScores.fromJson(Map<String, dynamic> json) {
    scores = Map<String, int>.from(json);
  }

  WordScores();
}

class SentenceReader extends StatefulWidget {
  @override
  _SentenceReaderState createState() => _SentenceReaderState();
}

class _SentenceReaderState extends State<SentenceReader> {
  List<Sentence> allSentences = [];
  int currentIndex = 0;
  WordScores wordScores = WordScores();
  Set<String> selectedWords = {};
  bool showTranslation = false;
  Map<String, Map<String, String>> hskGlossary = {};

  @override
  void initState() {
    super.initState();
    initApp();
  }

  Future<void> initApp() async {
    wordScores = await loadScores();
    allSentences = await loadSentences(wordScores);
    hskGlossary = await loadHSK1Glossary();
    setState(() {});
  }

  Future<List<Sentence>> loadSentences(WordScores wordScores) async {
    final String jsonString = await rootBundle.loadString('assets/sentences.json');
    final List<dynamic> rawList = jsonDecode(jsonString);
    List<Sentence> sentences = rawList.map((e) => Sentence.fromJson(e)).toList();
    sentences.sort((a, b) => wordScores
        .getSentenceScore(a.tokens)
        .compareTo(wordScores.getSentenceScore(b.tokens)));
    return sentences;
  }

  Future<Map<String, Map<String, String>>> loadHSK1Glossary() async {
    final String jsonString = await rootBundle.loadString('assets/hsk1.json');
    final List<dynamic> rawList = jsonDecode(jsonString);
    final Map<String, Map<String, String>> glossary = {};
    for (final item in rawList) {
      glossary[item['word']] = {
        'meaning': item['meaning'],
        'pinyin': item['pinyin']
      };
    }
    return glossary;
  }

  Future<WordScores> loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('word_scores');
    if (jsonString == null) return WordScores();
    return WordScores.fromJson(jsonDecode(jsonString));
  }

  Future<void> saveScores() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('word_scores', jsonEncode(wordScores.toJson()));
  }

  void onSubmit() {
    for (final word in selectedWords) {
      wordScores.increment(word);
    }
    saveScores();
    loadNextSentence();
  }

  void loadNextSentence() async {
    wordScores = await loadScores();
    allSentences = await loadSentences(wordScores);
    setState(() {
      currentIndex = (currentIndex + 1) % allSentences.length;
      selectedWords.clear();
      showTranslation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (allSentences.isEmpty) return Scaffold(body: Center(child: CircularProgressIndicator()));

    final sentence = allSentences[currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('Read4ever')),
body: Center(
  child: SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(sentence.chinese, style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
          SizedBox(height: 12),
          if (showTranslation) ...[
            Text(sentence.translation, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: sentence.tokens.map((word) {
                final isSelected = selectedWords.contains(word);
                final gloss = hskGlossary[word] != null
                    ? "${hskGlossary[word]!['pinyin']} - ${hskGlossary[word]!['meaning']}"
                    : "$word (not in HSK1)";
                return Tooltip(
                  message: gloss,
                  child: ChoiceChip(
                    label: Text(word),
                    selected: isSelected,
                    onSelected: (selectedNow) {
                      setState(() {
                        if (selectedNow) selectedWords.add(word);
                        else selectedWords.remove(word);
                      });
                    },
                  ),
                );
              }).toList(),
            )
          ] else
            Text('(Press reveal to continue)', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 32),
          ElevatedButton(
            child: Text(showTranslation ? 'Submit' : 'Reveal'),
            onPressed: () {
              setState(() {
                if (showTranslation) {
                  onSubmit();
                } else {
                  showTranslation = true;
                }
              });
            },
          )
        ],
      ),
    ),
  ),
),
    );
  }
}