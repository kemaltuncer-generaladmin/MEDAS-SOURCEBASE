import 'models.dart';
import 'study_models.dart';

class GeneratedContentParser {
  // Lenient parsing helper
  static String firstString(Map<String, dynamic>? dict, List<String> keys) {
    if (dict == null) return '';
    for (var key in keys) {
      if (dict[key] != null) {
        return dict[key].toString();
      }
    }
    return '';
  }

  static int? firstInt(Map<String, dynamic>? dict, List<String> keys) {
    if (dict == null) return null;
    for (var key in keys) {
      if (dict[key] != null) {
        final val = dict[key];
        if (val is int) return val;
        if (val is num) return val.toInt();
        final parsed = int.tryParse(val.toString());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool? boolValue(dynamic val) {
    if (val == null) return null;
    if (val is bool) return val;
    if (val == 'true' || val == '1' || val == 1) return true;
    if (val == 'false' || val == '0' || val == 0) return false;
    return null;
  }

  static List<String> stringArray(dynamic val) {
    if (val == null) return [];
    if (val is List) {
      return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  static List<dynamic>? array(Map<String, dynamic>? dict, List<String> keys) {
    if (dict == null) return null;
    for (var key in keys) {
      if (dict[key] is List) {
        return dict[key] as List;
      }
    }
    return null;
  }

  static List<SBQuestionPrompt> questionPrompts(Map<String, dynamic> response) {
    final payload = response['data'] is Map ? response['data'] as Map<String, dynamic> : response;
    final rawQuestions = array(payload, ['questions', 'items']) ?? (payload['questions'] is List ? payload['questions'] as List : null);
    if (rawQuestions == null) return [];
    
    return rawQuestions.asMap().entries.map((entry) {
      final idx = entry.key;
      final val = entry.value;
      if (val is! Map) return null;
      final dict = Map<String, dynamic>.from(val);
      final text = firstString(dict, ['text', 'question', 'stem']);
      final options = stringArray(dict['options']);
      if (text.isEmpty || options.length != 5) return null;
      
      return SBQuestionPrompt(
        id: firstString(dict, ['id', 'questionId', 'question_id']).isNotEmpty 
            ? firstString(dict, ['id', 'questionId', 'question_id']) 
            : 'question-$idx',
        subject: firstString(dict, ['subject']).isNotEmpty ? firstString(dict, ['subject']) : 'Kullanıcı Kaynağı',
        topic: firstString(dict, ['topic']).isNotEmpty ? firstString(dict, ['topic']) : 'SourceBase',
        difficulty: firstString(dict, ['difficulty']).isNotEmpty ? firstString(dict, ['difficulty']) : 'medium',
        text: text,
        options: options,
        tags: stringArray(dict['tags']),
      );
    }).whereType<SBQuestionPrompt>().toList();
  }

  static SBQuestionAnswerFeedback questionAnswerFeedback(Map<String, dynamic> response, String fallbackQuestionId, int selectedIndex) {
    final payload = response['data'] is Map ? response['data'] as Map<String, dynamic> : response;
    final isCorrect = boolValue(payload['isCorrect'] ?? payload['is_correct'] ?? payload['correct']) ?? false;
    final correctIdx = firstInt(payload, ['correctIndex', 'correct_index', 'correctAnswerIndex', 'correct_answer_index', 'answerIndex', 'answer_index']);
    
    return SBQuestionAnswerFeedback(
      questionId: firstString(payload, ['questionId', 'question_id', 'id']).isNotEmpty
          ? firstString(payload, ['questionId', 'question_id', 'id'])
          : fallbackQuestionId,
      selectedIndex: firstInt(payload, ['selectedIndex', 'selected_index']) ?? selectedIndex,
      isCorrect: isCorrect,
      correctIndex: correctIdx,
      explanation: firstString(payload, ['explanation', 'rationale']),
      optionRationales: stringArray(payload['optionRationales'] ?? payload['option_rationales']),
    );
  }

  static List<SBFlashcard> flashcards(Map<String, dynamic>? content, [String? fallbackText]) {
    final rawCards = array(content, ['cards', 'flashcards']) ?? (content != null && content['cards'] is List ? content['cards'] as List : null);
    if (rawCards == null || rawCards.isEmpty) {
      if (fallbackText != null && fallbackText.trim().isNotEmpty) {
        return [SBFlashcard(id: 'card-0', front: fallbackText.split('\n').first, back: fallbackText)];
      }
      return [];
    }

    return rawCards.asMap().entries.map((entry) {
      final idx = entry.key;
      final val = entry.value;
      if (val is! Map) {
        final text = val.toString().trim();
        return text.isEmpty ? null : SBFlashcard(id: 'card-$idx', front: text, back: '');
      }
      final dict = Map<String, dynamic>.from(val);
      final front = firstString(dict, ['front', 'question', 'prompt', 'term', 'title']).trim();
      final back = firstString(dict, ['back', 'answer', 'definition', 'text']).trim();
      if (front.isEmpty && back.isEmpty) return null;
      
      return SBFlashcard(
        id: firstString(dict, ['id']).isNotEmpty ? firstString(dict, ['id']) : 'card-$idx',
        front: front.isEmpty ? 'Kart ${idx + 1}' : front,
        back: back,
        explanation: firstString(dict, ['explanation', 'rationale', 'note']),
        difficulty: firstString(dict, ['difficulty']),
        hint: firstString(dict, ['hint', 'ipucu']),
      );
    }).whereType<SBFlashcard>().toList();
  }

  static List<SBQlinikQuestion> questions(Map<String, dynamic>? content) {
    final rawQuestions = array(content, ['questions', 'items']) ?? (content != null && content['questions'] is List ? content['questions'] as List : null);
    if (rawQuestions == null) return [];
    
    return rawQuestions.asMap().entries.map((entry) {
      final idx = entry.key;
      final val = entry.value;
      if (val is! Map) return null;
      final dict = Map<String, dynamic>.from(val);
      final options = stringArray(dict['options']);
      final rationales = stringArray(dict['option_rationales'] ?? dict['optionRationales']);
      final text = firstString(dict, ['text', 'question', 'stem']);
      if (text.isEmpty || options.isEmpty) return null;
      
      return SBQlinikQuestion(
        id: firstString(dict, ['id']).isNotEmpty ? firstString(dict, ['id']) : 'question-$idx',
        subject: firstString(dict, ['subject']).isNotEmpty ? firstString(dict, ['subject']) : 'Kullanıcı Kaynağı',
        topic: firstString(dict, ['topic']).isNotEmpty ? firstString(dict, ['topic']) : 'SourceBase',
        difficulty: firstString(dict, ['difficulty']).isNotEmpty ? firstString(dict, ['difficulty']) : 'medium',
        text: text,
        options: options,
        correctIndex: firstInt(dict, ['correct_index', 'correctIndex', 'correctAnswerIndex', 'correct_answer_index', 'answerIndex', 'answer_index', 'correctOptionIndex', 'correct_option_index']) ?? -1,
        explanation: firstString(dict, ['explanation', 'rationale']),
        optionRationales: rationales,
        tags: stringArray(dict['tags']),
        isUserGenerated: boolValue(dict['is_user_generated'] ?? dict['isUserGenerated']) ?? true,
      );
    }).whereType<SBQlinikQuestion>().toList();
  }

  static List<String> sectionItems(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is Map) {
      final items = value['items'] ?? value['bullets'] ?? value['points'] ?? [];
      return sectionItems(items);
    }
    final str = value.toString().trim();
    return str.isNotEmpty ? [str] : [];
  }

  static SBStudyTable? table(Map<String, dynamic>? dict) {
    if (dict == null) return null;
    final tableVal = dict['table'] ?? dict['mini_table'] ?? dict['grid'];
    if (tableVal is! Map) return null;
    final tableDict = Map<String, dynamic>.from(tableVal);
    final headers = stringArray(tableDict['headers'] ?? tableDict['columns']);
    final rawRows = tableDict['rows'] ?? tableDict['data'];
    if (headers.isEmpty || rawRows is! List) return null;
    
    final rows = <List<String>>[];
    for (var r in rawRows) {
      if (r is List) {
        rows.add(r.map((e) => e.toString().trim()).toList());
      } else if (r is Map) {
        // Map row matching headers
        final mapRow = Map<String, dynamic>.from(r);
        final listRow = headers.map((h) => firstString(mapRow, [h, h.toLowerCase(), h.replaceAll(' ', '_')])).toList();
        rows.add(listRow);
      }
    }
    if (rows.isEmpty) return null;
    return SBStudyTable(headers: headers, rows: rows);
  }

  static List<SBDecisionNode> decisionNodes(dynamic value) {
    if (value is! List) return [];
    return value.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      if (item is! Map) return null;
      final d = Map<String, dynamic>.from(item);
      final title = firstString(d, ['title', 'label', 'question', 'node']);
      if (title.isEmpty) return null;
      
      return SBDecisionNode(
        id: firstString(d, ['id']).isNotEmpty ? firstString(d, ['id']) : 'node-$idx',
        title: title,
        detail: firstString(d, ['description', 'detail', 'meaning']),
        yes: firstString(d, ['yes', 'ifYes', 'evet']),
        no: firstString(d, ['no', 'ifNo', 'hayir', 'hayır']),
        substeps: stringArray(d['substeps'] ?? d['subSteps']),
      );
    }).whereType<SBDecisionNode>().toList();
  }

  static List<SBQAPair> qaPairs(dynamic value) {
    if (value is! List) return [];
    return value.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      if (item is! Map) {
        final text = item.toString().trim();
        return text.isEmpty ? null : SBQAPair(id: 'qa-$idx', question: text, answer: '');
      }
      final d = Map<String, dynamic>.from(item);
      final q = firstString(d, ['question', 'q', 'prompt']);
      if (q.isEmpty) return null;
      
      return SBQAPair(
        id: firstString(d, ['id']).isNotEmpty ? firstString(d, ['id']) : 'qa-$idx',
        question: q,
        answer: firstString(d, ['answer', 'a', 'response']),
        explanation: firstString(d, ['explanation', 'rationale', 'detail']),
      );
    }).whereType<SBQAPair>().toList();
  }

  static List<SBTimelineEntry> timelineEntries(dynamic value) {
    if (value is! List) return [];
    return value.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      if (item is! Map) {
        final text = item.toString().trim();
        return text.isEmpty ? null : SBTimelineEntry(id: 'session-$idx', title: text, items: []);
      }
      final d = Map<String, dynamic>.from(item);
      final title = firstString(d, ['title', 'day', 'label', 'name']);
      final minutes = firstInt(d, ['estimatedMinutes', 'minutes', 'estimated_minutes']);
      final meta = minutes != null ? '$minutes dk' : firstString(d, ['duration', 'meta']);
      
      return SBTimelineEntry(
        id: firstString(d, ['id']).isNotEmpty ? firstString(d, ['id']) : 'session-$idx',
        title: title.isEmpty ? 'Oturum ${idx + 1}' : title,
        meta: meta.isEmpty ? null : meta,
        items: stringArray(d['activities'] ?? d['tasks'] ?? d['items']),
      );
    }).whereType<SBTimelineEntry>().toList();
  }

  static List<SBMindBranch> mindBranches(dynamic value) {
    if (value is! List) return [];
    return value.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      if (item is! Map) return null;
      final d = Map<String, dynamic>.from(item);
      final label = firstString(d, ['label', 'title', 'name', 'topic']);
      if (label.isEmpty) return null;
      
      return SBMindBranch(
        id: firstString(d, ['id']).isNotEmpty ? firstString(d, ['id']) : 'branch-$idx',
        label: label,
        children: stringArray(d['children'] ?? d['subbranches'] ?? d['sub_branches'] ?? d['items']),
        tags: stringArray(d['tags']),
      );
    }).whereType<SBMindBranch>().toList();
  }

  static String getLabel(String key) {
    switch (key) {
      case 'must_know':
      case 'mustKnow':
        return 'Mutlaka Bil';
      case 'commonly_confused':
      case 'commonlyConfused':
        return 'Sık Karışanlar';
      case 'clinical_tus_tips':
      case 'clinicalTusTips':
        return 'Klinik / TUS İpuçları';
      case 'red_flags':
      case 'redFlags':
        return 'Kırmızı Bayraklar';
      case 'clinical_notes':
      case 'clinicalNotes':
        return 'Klinik Notlar';
      case 'key_takeaways':
      case 'keyTakeaways':
        return 'Anahtar Kazanımlar';
      case 'teaching_points':
      case 'teachingPoints':
        return 'Öğretim Noktaları';
      default:
        return key;
    }
  }

  static SBStudyDocument document(GeneratedKind kind, Map<String, dynamic>? content, String fallbackTitle, [String? fallbackText]) {
    final dict = content;
    final title = firstString(dict, ['title', 'name', 'headline', 'centralTopic']).isNotEmpty
        ? firstString(dict, ['title', 'name', 'headline', 'centralTopic'])
        : fallbackTitle;
    
    final blocks = <SBStudyBlock>[];
    var summary = firstString(dict, ['summary', 'overview', 'description', 'fullText']);

    void callout(String label, String key, SBCalloutStyle style) {
      final items = sectionItems(dict?[key]);
      if (items.isNotEmpty) {
        blocks.add(SBStudyBlock.calloutList('${kind.name}-$key', label, items, style));
      }
    }

    void steps(String label, String key) {
      final items = sectionItems(dict?[key]);
      if (items.isNotEmpty) {
        blocks.add(SBStudyBlock.steps('${kind.name}-$key', label, items));
      }
    }

    if (dict != null) {
      switch (kind) {
        case GeneratedKind.flashcard:
          final cardsList = flashcards(content, fallbackText);
          if (cardsList.isNotEmpty) {
            blocks.add(SBStudyBlock.cards('cards', cardsList));
          }
          callout('Kaynakta Eksik Kalanlar', 'source_gaps', SBCalloutStyle.redFlag);

        case GeneratedKind.question:
          final qList = questions(content);
          if (qList.isNotEmpty) {
            blocks.add(SBStudyBlock.quiz('quiz', qList));
          }
          callout('Kaynakta Eksik Kalanlar', 'source_gaps', SBCalloutStyle.redFlag);

        case GeneratedKind.summary:
          callout('Ana Konular', 'mainTopics', SBCalloutStyle.plain);
          callout('Yüksek Verimli Noktalar', 'high_yield_points', SBCalloutStyle.mustKnow);
          callout('Yüksek Verimli Noktalar', 'highYieldPoints', SBCalloutStyle.mustKnow);
          callout('Mutlaka Bil', 'mustKnow', SBCalloutStyle.mustKnow);
          callout('Mutlaka Bil', 'must_know', SBCalloutStyle.mustKnow);
          callout('Kırmızı Bayraklar', 'redFlags', SBCalloutStyle.redFlag);
          callout('Kırmızı Bayraklar', 'red_flags', SBCalloutStyle.redFlag);
          callout('Sık Karışanlar', 'commonlyConfused', SBCalloutStyle.confused);
          callout('Sık Karışanlar', 'commonly_confused', SBCalloutStyle.confused);
          final tbl = table(dict);
          if (tbl != null) {
            blocks.add(SBStudyBlock.table('mini_table', 'Mini Tablo', tbl));
          }
          steps('Klinik Karar Akışı', 'clinicalDecisionFlow');
          steps('Klinik Karar Akışı', 'clinical_decision_flow');
          callout('Sınav Tuzakları', 'examTraps', SBCalloutStyle.tip);
          callout('Anahtar Terimler', 'keyTerms', SBCalloutStyle.tip);
          final selfCheck = qaPairs(dict['self_check'] ?? dict['quick_check']);
          if (selfCheck.isNotEmpty) {
            blocks.add(SBStudyBlock.qa('self_check', 'Kendini Kontrol Et', selfCheck));
          }

        case GeneratedKind.examMorningSummary:
          callout('Mutlaka Bil', 'must_know', SBCalloutStyle.mustKnow);
          callout('Sık Karışanlar', 'commonly_confused', SBCalloutStyle.confused);
          callout('Klinik / TUS İpuçları', 'clinical_tus_tips', SBCalloutStyle.tip);
          callout('Kırmızı Bayraklar', 'red_flags', SBCalloutStyle.redFlag);
          steps('Algoritma Akışı', 'algorithm_flow');
          final tbl = table(dict);
          if (tbl != null) {
            blocks.add(SBStudyBlock.table('mini_table', 'Hızlı Tablo', tbl));
          }
          final selfCheck = qaPairs(dict['self_check']);
          if (selfCheck.isNotEmpty) {
            blocks.add(SBStudyBlock.qa('self_check', 'Kendini Kontrol Et', selfCheck));
          }

        case GeneratedKind.algorithm:
          final start = firstString(dict, ['starting_point', 'startingPoint', 'entry', 'entry_point', 'entryPoint']);
          if (start.isNotEmpty) {
            blocks.add(SBStudyBlock.paragraph('start', 'Başlangıç: $start'));
          }
          final nodes = decisionNodes(dict['decision_nodes'] ?? dict['decisionNodes'] ?? dict['nodes']);
          if (nodes.isNotEmpty) {
            blocks.add(SBStudyBlock.decisions('decision_nodes', 'Karar Düğümleri', nodes));
          }
          final actionItems = sectionItems(dict['action_steps'] ?? dict['actionSteps'] ?? dict['steps']);
          if (actionItems.isNotEmpty) {
            blocks.add(SBStudyBlock.steps('algorithm-actions', 'Eylem Adımları', actionItems));
          }
          callout('Akış Dalları', 'branches', SBCalloutStyle.plain);
          callout('Kritik Eşikler', 'critical_thresholds', SBCalloutStyle.mustKnow);
          callout('Kritik Eşikler', 'criticalThresholds', SBCalloutStyle.mustKnow);
          callout('Kırmızı Bayraklar', 'red_flags', SBCalloutStyle.redFlag);
          callout('Kırmızı Bayraklar', 'redFlags', SBCalloutStyle.redFlag);
          callout('Sınav İpuçları', 'exam_tips', SBCalloutStyle.tip);
          callout('Notlar', 'notes', SBCalloutStyle.plain);

        case GeneratedKind.comparison:
        case GeneratedKind.table:
          final tbl = table(dict);
          if (tbl != null) {
            blocks.add(SBStudyBlock.table('comparison', 'Karşılaştırma', tbl));
          }
          callout('Ayırt Edici İpuçları', 'distinguishing_tips', SBCalloutStyle.tip);
          callout('Klinik Notlar', 'clinical_notes', SBCalloutStyle.plain);
          callout('Sık Karışanlar', 'commonly_confused', SBCalloutStyle.confused);
          callout('Kırmızı Bayraklar', 'red_flags', SBCalloutStyle.redFlag);
          callout('Kısa Sonuç', 'short_takeaway', SBCalloutStyle.mustKnow);

        case GeneratedKind.clinicalScenario:
          final patientInfo = firstString(dict, ['patientInfo', 'patient_info', 'patient', 'patientSnapshot', 'patient_snapshot']);
          final chiefComplaint = firstString(dict, ['chiefComplaint', 'chief_complaint', 'complaint']);
          final decisionPoint = firstString(dict, ['decisionPoint', 'decision_point']);
          final kv = <SBKeyValue>[];
          if (patientInfo.isNotEmpty) kv.add(SBKeyValue(key: 'Hasta', value: patientInfo));
          if (chiefComplaint.isNotEmpty) kv.add(SBKeyValue(key: 'Başvuru Şikayeti', value: chiefComplaint));
          if (decisionPoint.isNotEmpty) kv.add(SBKeyValue(key: 'Karar Noktası', value: decisionPoint));
          if (kv.isNotEmpty) {
            blocks.add(SBStudyBlock.keyValues('patient', 'Vaka Bilgisi', kv));
          }
          final stem = firstString(dict, ['caseStem', 'case_stem', 'history', 'case', 'scenario']);
          if (stem.isNotEmpty) {
            blocks.add(SBStudyBlock.paragraph('stem', stem));
          }
          callout('Fizik Muayene', 'physicalExam', SBCalloutStyle.plain);
          callout('Fizik Muayene', 'physical_exam', SBCalloutStyle.plain);
          callout('Lab / Görüntüleme', 'labsImaging', SBCalloutStyle.plain);
          callout('Lab / Görüntüleme', 'labs_imaging', SBCalloutStyle.plain);
          callout('Bulgular', 'findings', SBCalloutStyle.mustKnow);
          callout('Problem Temsili', 'problemRepresentation', SBCalloutStyle.mustKnow);
          callout('Problem Temsili', 'problem_representation', SBCalloutStyle.mustKnow);
          callout('Ayırıcı Tanı', 'differentialDiagnosis', SBCalloutStyle.confused);
          callout('Ayırıcı Tanı', 'differential_diagnosis', SBCalloutStyle.confused);
          callout('Tanısal Gerekçe', 'diagnosticJustification', SBCalloutStyle.tip);
          callout('Tanısal Gerekçe', 'diagnostic_justification', SBCalloutStyle.tip);
          final nodes = decisionNodes(dict['decision_nodes'] ?? dict['decisionNodes']);
          if (nodes.isNotEmpty) {
            blocks.add(SBStudyBlock.decisions('clinical_decision_nodes', 'Karar Noktaları', nodes));
          }
          callout('Kırmızı Bayraklar', 'red_flags', SBCalloutStyle.redFlag);
          final qa = qaPairs(dict['questions']);
          if (qa.isNotEmpty) {
            blocks.add(SBStudyBlock.qa('questions', 'Sorular', qa));
          }
          callout('Öğrenme Hedefleri', 'learningObjective', SBCalloutStyle.objective);
          callout('Öğrenme Hedefleri', 'learning_objective', SBCalloutStyle.objective);
          callout('Öğretim Noktaları', 'teachingPoints', SBCalloutStyle.tip);
          callout('Öğretim Noktaları', 'teaching_points', SBCalloutStyle.tip);

        case GeneratedKind.learningPlan:
          final duration = firstString(dict, ['duration']);
          if (duration.isNotEmpty) {
            blocks.add(SBStudyBlock.paragraph('duration', 'Süre: $duration'));
          }
          final sessions = timelineEntries(dict['sessions'] ?? dict['study_sessions'] ?? dict['studySessions']);
          if (sessions.isNotEmpty) {
            blocks.add(SBStudyBlock.timeline('sessions', 'Çalışma Oturumları', sessions));
          }
          callout('Bugün Başla', 'startToday', SBCalloutStyle.mustKnow);
          callout('Bugün Başla', 'start_today', SBCalloutStyle.mustKnow);
          callout('Günlük Hedefler', 'dailyGoals', SBCalloutStyle.objective);
          callout('Günlük Hedefler', 'daily_goals', SBCalloutStyle.objective);
          steps('Yapılacaklar', 'checklist');
          callout('Tekrar Günleri', 'reviewDays', SBCalloutStyle.plain);
          callout('Tekrar Günleri', 'review_days', SBCalloutStyle.plain);
          callout('Zayıf Noktalar', 'weakPoints', SBCalloutStyle.redFlag);
          callout('Zayıf Noktalar', 'weak_points', SBCalloutStyle.redFlag);

        case GeneratedKind.podcast:
          final segments = array(dict, ['segments', 'chapters']) ?? [];
          final parsedSegments = segments.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            if (item is! Map) return null;
            final itemDict = Map<String, dynamic>.from(item);
            final text = firstString(itemDict, ['text', 'script', 'body', 'content']);
            if (text.isEmpty) return null;
            return SBPodcastSegment(
              id: firstString(itemDict, ['id']).isNotEmpty ? firstString(itemDict, ['id']) : 'segment-$idx',
              title: firstString(itemDict, ['title', 'heading']).isNotEmpty
                  ? firstString(itemDict, ['title', 'heading'])
                  : 'Bölüm ${idx + 1}',
              text: text,
              durationLabel: firstString(itemDict, ['duration', 'durationLabel', 'duration_label']),
            );
          }).whereType<SBPodcastSegment>().toList();
          
          final audioUrl = firstString(dict, ['audio_url', 'audioUrl', 'url']);
          blocks.add(SBStudyBlock.audio('audio', audioUrl.isNotEmpty ? audioUrl : null, parsedSegments));
          callout('Kısa Özet', 'recap', SBCalloutStyle.mustKnow);
          callout('Aktif Hatırlama', 'active_recall_prompts', SBCalloutStyle.tip);
          callout('Kaynak Sınırları', 'source_limits', SBCalloutStyle.redFlag);

        case GeneratedKind.infographic:
          final imageUrl = firstString(dict, ['image_url', 'imageUrl', 'url']);
          if (imageUrl.isNotEmpty) {
            blocks.add(SBStudyBlock.image('image', imageUrl, title));
          }
          callout('Ana Mesaj', 'main_message', SBCalloutStyle.mustKnow);
          final rawSections = array(dict, ['sections']) ?? [];
          for (var i = 0; i < rawSections.length; i++) {
            final value = rawSections[i];
            if (value is Map) {
              final sectionObj = Map<String, dynamic>.from(value);
              final heading = firstString(sectionObj, ['heading', 'title']).isNotEmpty
                  ? firstString(sectionObj, ['heading', 'title'])
                  : 'Bölüm ${i + 1}';
              final bullets = sectionItems(sectionObj['bullets'] ?? sectionObj['items']);
              if (bullets.isNotEmpty) {
                blocks.add(SBStudyBlock.calloutList('info-$i', heading, bullets, SBCalloutStyle.plain));
              }
            }
          }
          callout('Uyarılar', 'warnings', SBCalloutStyle.redFlag);
          callout('Kırmızı Bayraklar', 'red_flags', SBCalloutStyle.redFlag);
          callout('Kaynak Notu', 'source_note', SBCalloutStyle.plain);

        case GeneratedKind.mindMap:
          final center = firstString(dict, ['centralTopic', 'central_topic', 'topic']);
          if (center.isNotEmpty) {
            blocks.add(SBStudyBlock.paragraph('center', 'Merkez Konu: $center'));
          }
          final branches = mindBranches(dict['branches']);
          if (branches.isNotEmpty) {
            blocks.add(SBStudyBlock.mindBranches('branches', 'Dallar', branches));
          }
          callout('Kritik Bağlantılar', 'criticalConnections', SBCalloutStyle.mustKnow);
          callout('Kritik Bağlantılar', 'critical_connections', SBCalloutStyle.mustKnow);
          callout('Sık Karışanlar', 'commonly_confused', SBCalloutStyle.confused);
          callout('Klinik / TUS İpuçları', 'clinicalTusTips', SBCalloutStyle.tip);
      }
    }

    if (blocks.isEmpty) {
      if (summary.trim().isEmpty && fallbackText != null) {
        summary = fallbackText;
      }
      if (summary.isNotEmpty) {
        blocks.add(SBStudyBlock.paragraph('fallback-summary', summary));
      } else {
        blocks.add(SBStudyBlock.paragraph('fallback-empty', 'Bu çalışma ekranı için kaynak içeriği henüz hazırlanmadı.'));
      }
    }

    final subtitle = dict != null ? firstString(dict, ['duration', 'patientInfo', 'sourceName', 'infographic_type']) : '';
    return SBStudyDocument(kind: kind, title: title, subtitle: subtitle, summary: summary, blocks: blocks);
  }
}
