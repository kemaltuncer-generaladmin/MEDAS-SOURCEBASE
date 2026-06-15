import 'package:flutter/material.dart';

import '../../design_system/sb_colors.dart';
import '../../models/models.dart';
import '../../models/study_models.dart';

/// Port of SBOutputStyle: per-kind accent, icon and template metadata.
class SBOutputStyle {
  SBOutputStyle._();

  static Color accent(GeneratedKind kind) => outputColor(kind);

  static String icon(GeneratedKind kind) => outputIcon(kind);

  static String outputIcon(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard => 'rectangle.on.rectangle',
        GeneratedKind.question => 'questionmark.circle',
        GeneratedKind.summary => 'doc.text',
        GeneratedKind.examMorningSummary => 'alarm',
        GeneratedKind.algorithm => 'arrow.triangle.branch',
        GeneratedKind.comparison || GeneratedKind.table => 'tablecells',
        GeneratedKind.clinicalScenario => 'cross.case',
        GeneratedKind.learningPlan => 'calendar.badge.clock',
        GeneratedKind.podcast => 'headphones',
        GeneratedKind.infographic => 'chart.bar',
        GeneratedKind.mindMap => 'point.3.connected.trianglepath.dotted',
      };

  static Color outputColor(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard => SBColors.blue,
        GeneratedKind.question => SBColors.cyan,
        GeneratedKind.summary => SBColors.violet,
        GeneratedKind.examMorningSummary => SBColors.amber,
        GeneratedKind.algorithm => SBColors.orange,
        GeneratedKind.comparison || GeneratedKind.table => SBColors.indigo,
        GeneratedKind.clinicalScenario => SBColors.rose,
        GeneratedKind.learningPlan => SBColors.green,
        GeneratedKind.podcast => SBColors.magenta,
        GeneratedKind.infographic => SBColors.teal,
        GeneratedKind.mindMap => SBColors.lime,
      };

  static String outputKindLabel(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard => 'Flashcard',
        GeneratedKind.question => 'Soru',
        GeneratedKind.summary => 'Özet',
        GeneratedKind.examMorningSummary => 'Sınav Sabahı',
        GeneratedKind.algorithm => 'Algoritma',
        GeneratedKind.comparison || GeneratedKind.table => 'Tablo',
        GeneratedKind.clinicalScenario => 'Klinik Senaryo',
        GeneratedKind.learningPlan => 'Öğrenme Planı',
        GeneratedKind.podcast => 'Podcast',
        GeneratedKind.infographic => 'İnfografik',
        GeneratedKind.mindMap => 'Zihin Haritası',
      };

  /// Distinctive template name per kind.
  static String templateName(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard => 'Flashcard Destesi',
        GeneratedKind.question => 'Soru Bankası',
        GeneratedKind.summary => 'Yüksek Getirili Özet',
        GeneratedKind.examMorningSummary => 'Sınav Sabahı Kartı',
        GeneratedKind.algorithm => 'Karar Algoritması',
        GeneratedKind.comparison || GeneratedKind.table => 'Kıyas Tablosu',
        GeneratedKind.clinicalScenario => 'Klinik Vaka Dosyası',
        GeneratedKind.learningPlan => 'Çalışma Planı',
        GeneratedKind.podcast => 'Sesli Anlatım',
        GeneratedKind.infographic => 'İnfografik Poster',
        GeneratedKind.mindMap => 'Zihin Haritası',
      };

  /// One-line purpose shown under the header.
  static String templatePurpose(GeneratedKind kind) => switch (kind) {
        GeneratedKind.flashcard =>
          'Aktif hatırlama ile öğrenene kadar tekrar et.',
        GeneratedKind.question =>
          'Çeldiricili sorularla kendini sına, gerekçeleri oku.',
        GeneratedKind.summary =>
          'Kaynaktaki sınav-kritik noktaları hızlı tara.',
        GeneratedKind.examMorningSummary =>
          'Sınavdan hemen önce son tekrar için kısa kart.',
        GeneratedKind.algorithm =>
          'Karar adımlarını yukarıdan aşağı takip et.',
        GeneratedKind.comparison ||
        GeneratedKind.table =>
          'Konuları aynı ölçütlerle yan yana ayırt et.',
        GeneratedKind.clinicalScenario =>
          'Vakayı oku, karar noktalarında muhakeme yap.',
        GeneratedKind.learningPlan =>
          'Günlere bölünmüş plana göre çalış ve işaretle.',
        GeneratedKind.podcast =>
          'Dinleyerek tekrar et; metni de takip edebilirsin.',
        GeneratedKind.infographic => 'Tek bakışta taranabilir görsel özet.',
        GeneratedKind.mindMap => 'Merkez kavramdan dallara ilişkileri kur.',
      };

  /// Color + icon for a callout style.
  static (Color, String) callout(SBCalloutStyle style, Color accent) =>
      switch (style) {
        SBCalloutStyle.plain => (accent, 'circle.fill'),
        SBCalloutStyle.mustKnow => (SBColors.blue, 'star.fill'),
        SBCalloutStyle.redFlag => (
            SBColors.red,
            'exclamationmark.triangle.fill'
          ),
        SBCalloutStyle.confused => (SBColors.purple, 'questionmark.circle'),
        SBCalloutStyle.tip => (SBColors.green, 'checkmark.circle.fill'),
        SBCalloutStyle.objective => (SBColors.cyan, 'target'),
      };
}
