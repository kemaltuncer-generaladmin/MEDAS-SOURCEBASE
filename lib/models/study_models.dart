import 'models.dart';

class SBFlashcard {
  final String id;
  final String front;
  final String back;
  final String explanation;
  final String difficulty;
  final String hint;

  SBFlashcard({
    required this.id,
    required this.front,
    required this.back,
    this.explanation = '',
    this.difficulty = '',
    this.hint = '',
  });

  factory SBFlashcard.fromJson(Map<String, dynamic> json, [String defaultId = '']) {
    return SBFlashcard(
      id: json['id'] ?? defaultId,
      front: json['front'] ?? json['question'] ?? json['prompt'] ?? json['term'] ?? json['title'] ?? '',
      back: json['back'] ?? json['answer'] ?? json['definition'] ?? json['text'] ?? '',
      explanation: json['explanation'] ?? json['rationale'] ?? json['note'] ?? '',
      difficulty: json['difficulty'] ?? '',
      hint: json['hint'] ?? json['ipucu'] ?? '',
    );
  }
}

class SBQlinikQuestion {
  final String id;
  final String subject;
  final String topic;
  final String difficulty;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final List<String> optionRationales;
  final List<String> tags;
  final bool isUserGenerated;

  SBQlinikQuestion({
    required this.id,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.optionRationales,
    required this.tags,
    this.isUserGenerated = true,
  });

  factory SBQlinikQuestion.fromJson(Map<String, dynamic> json, [String defaultId = '']) {
    return SBQlinikQuestion(
      id: json['id'] ?? defaultId,
      subject: json['subject'] ?? 'Kullanıcı Kaynağı',
      topic: json['topic'] ?? 'SourceBase',
      difficulty: json['difficulty'] ?? 'medium',
      text: json['text'] ?? json['question'] ?? json['stem'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? json['correctIndex'] ?? json['correctAnswerIndex'] ?? json['correct_answer_index'] ?? -1,
      explanation: json['explanation'] ?? json['rationale'] ?? '',
      optionRationales: List<String>.from(json['option_rationales'] ?? json['optionRationales'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      isUserGenerated: json['is_user_generated'] ?? json['isUserGenerated'] ?? true,
    );
  }

  bool get isQlinikCompatibleFiveChoice =>
      options.length == 5 &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      text.trim().isNotEmpty &&
      explanation.trim().isNotEmpty &&
      options.every((e) => e.trim().isNotEmpty);
}

class SBQuestionPrompt {
  final String id;
  final String subject;
  final String topic;
  final String difficulty;
  final String text;
  final List<String> options;
  final List<String> tags;

  SBQuestionPrompt({
    required this.id,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.text,
    required this.options,
    required this.tags,
  });

  factory SBQuestionPrompt.fromJson(Map<String, dynamic> json, [String defaultId = '']) {
    return SBQuestionPrompt(
      id: json['id'] ?? json['questionId'] ?? json['question_id'] ?? defaultId,
      subject: json['subject'] ?? 'Kullanıcı Kaynağı',
      topic: json['topic'] ?? 'SourceBase',
      difficulty: json['difficulty'] ?? 'medium',
      text: json['text'] ?? json['question'] ?? json['stem'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class SBQuestionAnswerFeedback {
  final String questionId;
  final int selectedIndex;
  final bool isCorrect;
  final int? correctIndex;
  final String explanation;
  final List<String> optionRationales;

  SBQuestionAnswerFeedback({
    required this.questionId,
    required this.selectedIndex,
    required this.isCorrect,
    this.correctIndex,
    required this.explanation,
    required this.optionRationales,
  });

  factory SBQuestionAnswerFeedback.fromJson(Map<String, dynamic> json, String fallbackId, int fallbackIndex) {
    return SBQuestionAnswerFeedback(
      questionId: json['questionId'] ?? json['question_id'] ?? json['id'] ?? fallbackId,
      selectedIndex: json['selectedIndex'] ?? json['selected_index'] ?? fallbackIndex,
      isCorrect: json['isCorrect'] ?? json['is_correct'] ?? json['correct'] ?? false,
      correctIndex: json['correctIndex'] ?? json['correct_index'] ?? json['correctAnswerIndex'] ?? json['correct_answer_index'],
      explanation: json['explanation'] ?? json['rationale'] ?? '',
      optionRationales: List<String>.from(json['optionRationales'] ?? json['option_rationales'] ?? []),
    );
  }
}

class SBStudySection {
  final String id;
  final String title;
  final List<String> items;

  SBStudySection({
    required this.id,
    required this.title,
    required this.items,
  });
}

class SBStudyTable {
  final List<String> headers;
  final List<List<String>> rows;

  SBStudyTable({
    required this.headers,
    required this.rows,
  });
}

class SBPodcastSegment {
  final String id;
  final String title;
  final String text;
  final String durationLabel;

  SBPodcastSegment({
    required this.id,
    required this.title,
    required this.text,
    this.durationLabel = '',
  });
}

class SBDecisionNode {
  final String id;
  final String title;
  final String? detail;
  final String? yes;
  final String? no;
  final List<String> substeps;

  SBDecisionNode({
    required this.id,
    required this.title,
    this.detail,
    this.yes,
    this.no,
    required this.substeps,
  });
}

class SBQAPair {
  final String id;
  final String question;
  final String answer;
  final String? explanation;

  SBQAPair({
    required this.id,
    required this.question,
    required this.answer,
    this.explanation,
  });
}

class SBKeyValue {
  final String key;
  final String value;

  SBKeyValue({required this.key, required this.value});
}

class SBTimelineEntry {
  final String id;
  final String title;
  final String? meta;
  final List<String> items;

  SBTimelineEntry({
    required this.id,
    required this.title,
    this.meta,
    required this.items,
  });
}

class SBMindBranch {
  final String id;
  final String label;
  final List<String> children;
  final List<String> tags;

  SBMindBranch({
    required this.id,
    required this.label,
    required this.children,
    required this.tags,
  });
}

enum SBCalloutStyle { plain, mustKnow, redFlag, confused, tip, objective }

enum SBStudyBlockType {
  paragraph,
  calloutList,
  steps,
  cards,
  quiz,
  table,
  decisions,
  qa,
  keyValues,
  timeline,
  audio,
  image,
  mindBranches,
}

class SBStudyBlock {
  final SBStudyBlockType type;
  final String id;
  final String? title;
  final String? text;
  final List<String>? items;
  final List<SBFlashcard>? cards;
  final List<SBQlinikQuestion>? quizQuestions;
  final SBStudyTable? table;
  final List<SBDecisionNode>? decisionNodes;
  final List<SBQAPair>? qaPairs;
  final List<SBKeyValue>? keyValues;
  final List<SBTimelineEntry>? timelineEntries;
  final List<SBMindBranch>? mindBranches;
  final String? url;
  final SBCalloutStyle? calloutStyle;
  final List<SBPodcastSegment>? podcastSegments;

  SBStudyBlock({
    required this.type,
    required this.id,
    this.title,
    this.text,
    this.items,
    this.cards,
    this.quizQuestions,
    this.table,
    this.decisionNodes,
    this.qaPairs,
    this.keyValues,
    this.timelineEntries,
    this.mindBranches,
    this.url,
    this.calloutStyle,
    this.podcastSegments,
  });

  factory SBStudyBlock.paragraph(String id, String text) => SBStudyBlock(type: SBStudyBlockType.paragraph, id: id, text: text);
  factory SBStudyBlock.calloutList(String id, String title, List<String> items, SBCalloutStyle style) =>
      SBStudyBlock(type: SBStudyBlockType.calloutList, id: id, title: title, items: items, calloutStyle: style);
  factory SBStudyBlock.steps(String id, String title, List<String> items) => SBStudyBlock(type: SBStudyBlockType.steps, id: id, title: title, items: items);
  factory SBStudyBlock.cards(String id, List<SBFlashcard> cards) => SBStudyBlock(type: SBStudyBlockType.cards, id: id, cards: cards);
  factory SBStudyBlock.quiz(String id, List<SBQlinikQuestion> questions) => SBStudyBlock(type: SBStudyBlockType.quiz, id: id, quizQuestions: questions);
  factory SBStudyBlock.table(String id, String title, SBStudyTable table) => SBStudyBlock(type: SBStudyBlockType.table, id: id, title: title, table: table);
  factory SBStudyBlock.decisions(String id, String title, List<SBDecisionNode> nodes) => SBStudyBlock(type: SBStudyBlockType.decisions, id: id, title: title, decisionNodes: nodes);
  factory SBStudyBlock.qa(String id, String title, List<SBQAPair> pairs) => SBStudyBlock(type: SBStudyBlockType.qa, id: id, title: title, qaPairs: pairs);
  factory SBStudyBlock.keyValues(String id, String title, List<SBKeyValue> pairs) => SBStudyBlock(type: SBStudyBlockType.keyValues, id: id, title: title, keyValues: pairs);
  factory SBStudyBlock.timeline(String id, String title, List<SBTimelineEntry> entries) => SBStudyBlock(type: SBStudyBlockType.timeline, id: id, title: title, timelineEntries: entries);
  factory SBStudyBlock.audio(String id, String? url, List<SBPodcastSegment> segments) => SBStudyBlock(type: SBStudyBlockType.audio, id: id, url: url, podcastSegments: segments);
  factory SBStudyBlock.image(String id, String url, String? title) => SBStudyBlock(type: SBStudyBlockType.image, id: id, url: url, title: title);
  factory SBStudyBlock.mindBranches(String id, String title, List<SBMindBranch> branches) => SBStudyBlock(type: SBStudyBlockType.mindBranches, id: id, title: title, mindBranches: branches);
}

class SBStudyDocument {
  final GeneratedKind kind;
  final String title;
  final String subtitle;
  final String summary;
  final List<SBStudyBlock> blocks;

  SBStudyDocument({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.blocks,
  });
}
