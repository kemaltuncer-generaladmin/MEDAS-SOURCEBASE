import '../../models/models.dart';

/// Minimum MC cost per generation type, mirroring the backend pricing floor.
/// Port of SBGenerationCost.
class SBGenerationCost {
  SBGenerationCost._();

  static double minMC(GeneratedKind kind) => switch (kind) {
        GeneratedKind.summary => 0.5,
        GeneratedKind.examMorningSummary => 1.0,
        GeneratedKind.flashcard => 0.75,
        GeneratedKind.question => 1.0,
        GeneratedKind.algorithm => 1.0,
        GeneratedKind.comparison || GeneratedKind.table => 1.0,
        GeneratedKind.mindMap => 1.0,
        GeneratedKind.clinicalScenario => 2.0,
        GeneratedKind.learningPlan => 1.5,
        GeneratedKind.podcast => 1.5,
        GeneratedKind.infographic => 0.5,
      };

  static double estimateMC(
    GeneratedKind kind, {
    int sourceCount = 1,
    int? requestedCount,
    String? quality,
  }) {
    var mc = switch (kind) {
      GeneratedKind.summary => 1.6,
      GeneratedKind.examMorningSummary => 2.1,
      GeneratedKind.flashcard => 1.8,
      GeneratedKind.question => 3.0,
      GeneratedKind.algorithm => 2.4,
      GeneratedKind.comparison || GeneratedKind.table => 3.2,
      GeneratedKind.mindMap => 2.2,
      GeneratedKind.clinicalScenario => 4.0,
      GeneratedKind.learningPlan => 2.6,
      GeneratedKind.podcast => 3.4,
      GeneratedKind.infographic => 4.8,
    };

    if (requestedCount != null) {
      if (kind == GeneratedKind.flashcard) {
        mc += (requestedCount - 10).clamp(0, 999) * 0.045;
      } else if (kind == GeneratedKind.question) {
        mc += (requestedCount - 10).clamp(0, 999) * 0.085;
      }
    }

    final extraSourceCost = switch (kind) {
      GeneratedKind.comparison || GeneratedKind.table => 0.65,
      GeneratedKind.clinicalScenario ||
      GeneratedKind.podcast ||
      GeneratedKind.infographic =>
        0.5,
      _ => 0.42,
    };
    mc += (sourceCount - 1).clamp(0, 999) * extraSourceCost;

    final qualityValue = (quality ?? '').toLowerCase();
    if (qualityValue.contains('premium')) {
      mc *= 1.45;
    } else if (qualityValue.contains('ekonomik') ||
        qualityValue.contains('economy')) {
      mc *= 0.85;
    }

    final rounded = (mc * 10).ceil() / 10;
    final floor = minMC(kind);
    return rounded > floor ? rounded : floor;
  }

  static String estimateLabel(
    GeneratedKind kind, {
    int sourceCount = 1,
    int? requestedCount,
    String? quality,
  }) {
    final low = estimateMC(kind,
        sourceCount: sourceCount,
        requestedCount: requestedCount,
        quality: quality);
    var high = (low * 1.32 * 10).ceil() / 10;
    if (high < low + 0.3) high = low + 0.3;
    return 'Tahmini ${_format(low)}-${_format(high)} MC';
  }

  static String compactEstimate(
    GeneratedKind kind, {
    int sourceCount = 1,
    int? requestedCount,
    String? quality,
  }) {
    final mc = estimateMC(kind,
        sourceCount: sourceCount,
        requestedCount: requestedCount,
        quality: quality);
    return '≈ ${_format(mc)} MC';
  }

  static String label(
    GeneratedKind kind, {
    int sourceCount = 1,
    int? requestedCount,
    String? quality,
  }) =>
      '${estimateLabel(kind, sourceCount: sourceCount, requestedCount: requestedCount, quality: quality)} · son tutar üretimde netleşir';

  static String minimumLabel(GeneratedKind kind) =>
      'En az ${_format(minMC(kind))} MC · kaynağına göre artabilir';

  static String _format(double mc) {
    final isWhole = mc == mc.roundToDouble();
    final text = isWhole ? mc.round().toString() : mc.toStringAsFixed(1);
    return text.replaceAll('.', ',');
  }
}
