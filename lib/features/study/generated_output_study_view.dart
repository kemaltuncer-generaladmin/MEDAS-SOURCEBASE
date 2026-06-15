import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_card.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_effects.dart';
import '../../design_system/sb_empty_state.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_loading_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_premium_visuals.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../design_system/sb_workspace_components.dart';
import '../../models/generated_content_parser.dart';
import '../../models/models.dart';
import '../../models/study_models.dart';
import 'sb_output_style.dart';
import 'sb_pdf_export_controls.dart';

/// Port of GeneratedOutputStudyView: the per-kind study surface.
class GeneratedOutputStudyView extends StatefulWidget {
  const GeneratedOutputStudyView({super.key, required this.outputId});

  final String outputId;

  @override
  State<GeneratedOutputStudyView> createState() =>
      _GeneratedOutputStudyViewState();
}

class _GeneratedOutputStudyViewState extends State<GeneratedOutputStudyView> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<WorkspaceStore>().loadWorkspace();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkspaceStore>();
    final router = context.read<AppRouter>();
    final output = store.generatedOutput(widget.outputId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SBColors.page,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: SBColors.blue),
        title: Text(output?.kind.titleLabel ?? 'Çalışma',
            style: SBTypography.titleMedium.copyWith(color: SBColors.navy)),
      ),
      bottomNavigationBar: output == null ? null : _medicalDisclaimer(),
      body: SBPageBackground(
        tone: SBPageTone.study,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(SBSpacing.lg),
                child: SBLoadingState(
                  icon: 'rectangle.stack',
                  title: 'Çalışma ekranı hazırlanıyor',
                  message: 'Koleksiyon içeriği yükleniyor...',
                ),
              )
            : output != null
                ? _studySurface(output)
                : Padding(
                    padding: const EdgeInsets.all(SBSpacing.lg),
                    child: SBErrorState(
                      title: 'Çalışma bulunamadı',
                      message:
                          'Koleksiyon yenilenmiş olabilir. Koleksiyonlardan tekrar açmayı dene.',
                      actionLabel: 'Koleksiyonlara Dön',
                      onAction: () =>
                          router.replaceCurrent(AppRoute.collections),
                    ),
                  ),
      ),
    );
  }

  Widget _medicalDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.lg, vertical: SBSpacing.sm),
      decoration: BoxDecoration(
        color: SBColors.white.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: SBColors.softLine, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            SBIcon('info.circle.fill', size: 13, color: SBColors.blue),
            const SizedBox(width: SBSpacing.sm),
            Expanded(
              child: Text(
                'Bu çalışma notu seçili kaynaktan hazırlandı. Sınav ve klinik kararlar için güncel kılavuz/ders kitabıyla doğrula.',
                style: SBTypography.caption.copyWith(color: SBColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studySurface(GeneratedOutput output) {
    switch (output.kind) {
      case GeneratedKind.flashcard:
        return _FlashcardStudySurface(output: output);
      case GeneratedKind.question:
        return _QuestionStudySurface(output: output);
      case GeneratedKind.podcast:
        return _PodcastStudySurface(output: output);
      case GeneratedKind.infographic:
        return _InfographicStudySurface(output: output);
      default:
        return _StudyDocumentSurface(output: output);
    }
  }
}

/// Shared gradient hero header used by every study surface.
Widget _studyHeader(
    {required String title,
    required String subtitle,
    required String icon,
    required Color tint}) {
  return SBGradientHero(
    icon: icon,
    title: title,
    message: subtitle,
    tint: tint,
    footer: Wrap(
      spacing: SBSpacing.sm,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
          decoration: BoxDecoration(
            color: SBColors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SBIcon('checkmark.seal', size: 11, color: SBColors.navy),
              const SizedBox(width: SBSpacing.xs),
              Text('Çalışma ekranı',
                  style: SBTypography.caption.copyWith(color: SBColors.navy)),
            ],
          ),
        ),
      ],
    ),
  );
}

// MARK: - Flashcards

class _FlashcardStudySurface extends StatefulWidget {
  const _FlashcardStudySurface({required this.output});

  final GeneratedOutput output;

  @override
  State<_FlashcardStudySurface> createState() =>
      _FlashcardStudySurfaceState();
}

class _FlashcardStudySurfaceState extends State<_FlashcardStudySurface> {
  List<SBFlashcard> _deck = [];
  bool _flipped = false;
  int _knownCount = 0;
  int _totalCount = 0;
  bool _didLoad = false;

  SBFlashcard? get _current => _deck.isNotEmpty ? _deck.first : null;

  bool get _completed => _didLoad && _deck.isEmpty && _totalCount > 0;

  @override
  void initState() {
    super.initState();
    _resetDeck();
  }

  void _resetDeck() {
    setState(() {
      _deck = GeneratedContentParser.flashcards(
          widget.output.content, widget.output.contentText);
      _totalCount = _deck.length;
      _knownCount = 0;
      _flipped = false;
      _didLoad = true;
    });
  }

  void _markKnown() {
    if (_deck.isEmpty) return;
    setState(() {
      _flipped = false;
      _deck = _deck.sublist(1);
      _knownCount =
          (_knownCount + 1) > _totalCount ? _totalCount : _knownCount + 1;
    });
  }

  void _requeue() {
    setState(() {
      _flipped = false;
      if (_deck.length > 1) {
        _deck = [..._deck.sublist(1), _deck.first];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SBSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studyHeader(
            title: widget.output.title,
            subtitle: _totalCount == 0
                ? 'Kartlar bekleniyor'
                : '$_knownCount öğrenildi • ${_deck.length} kart kaldı',
            icon: 'rectangle.on.rectangle',
            tint: SBColors.blue,
          ),
          const SizedBox(height: SBSpacing.lg),
          if (current != null) ...[
            SBPressable(
              onTap: () => setState(() => _flipped = !_flipped),
              child: SBCard(
                radius: 18,
                borderColor: SBColors.blue.withValues(alpha: 0.18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 260),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_flipped ? 'Cevap' : 'Soru',
                                style: SBTypography.caption
                                    .copyWith(color: SBColors.blue)),
                          ),
                          SBIcon('arrow.triangle.2.circlepath',
                              size: 17, color: SBColors.blue),
                        ],
                      ),
                      const SizedBox(height: SBSpacing.lg),
                      Text(
                        _flipped ? current.back : current.front,
                        style:
                            SBTypography.heading3.copyWith(color: SBColors.navy),
                      ),
                      if (_flipped && current.explanation.isNotEmpty) ...[
                        Divider(
                            color: SBColors.softLine, height: SBSpacing.xxl),
                        Text(current.explanation,
                            style: SBTypography.bodyMedium
                                .copyWith(color: SBColors.muted)),
                      ] else if (!_flipped && current.hint.isNotEmpty) ...[
                        const SizedBox(height: SBSpacing.lg),
                        Text(current.hint,
                            style: SBTypography.bodySmall
                                .copyWith(color: SBColors.muted)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: SBSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: SBButton(
                    'Tekrar gör',
                    icon: 'arrow.counterclockwise',
                    variant: SBButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: _requeue,
                  ),
                ),
                const SizedBox(width: SBSpacing.sm),
                Expanded(
                  child: SBButton(
                    'Biliyorum',
                    icon: 'checkmark',
                    fullWidth: true,
                    onPressed: _markKnown,
                  ),
                ),
              ],
            ),
          ] else if (_completed)
            SBEmptyState(
              icon: 'checkmark.seal.fill',
              title: 'Seti tamamladın',
              message:
                  '$_totalCount kartın hepsini öğrendin olarak işaretledin. Tazelemek için baştan başlayabilirsin.',
              badges: const ['Flashcard'],
              actionLabel: 'Baştan başla',
              onAction: _resetDeck,
            )
          else
            const SBEmptyState(
              icon: 'rectangle.stack.badge.exclamationmark',
              title: 'Kart bulunamadı',
              message:
                  'Bu çalışma kart ekranı için hazır değil. Kuyruktan yeniden deneyebilirsin.',
              badges: ['Flashcard'],
            ),
          if (_totalCount > 0 && !_completed) ...[
            const SizedBox(height: SBSpacing.lg),
            SBNotice(
              icon: 'arrow.counterclockwise.circle',
              message:
                  '"Tekrar" dediğin kartlar bilene kadar destenin sonuna eklenir.',
              tint: SBColors.blue,
            ),
          ],
          const SizedBox(height: SBSpacing.lg),
          SBPdfExportControls(output: widget.output),
          const SizedBox(height: 156),
        ],
      ),
    );
  }
}

// MARK: - Questions

class _QuestionStudySurface extends StatefulWidget {
  const _QuestionStudySurface({required this.output});

  final GeneratedOutput output;

  @override
  State<_QuestionStudySurface> createState() => _QuestionStudySurfaceState();
}

class _QuestionStudySurfaceState extends State<_QuestionStudySurface> {
  int _index = 0;
  int? _selectedIndex;
  List<SBQuestionPrompt> _questions = [];
  final Map<String, SBQuestionAnswerFeedback> _feedbackByQuestion = {};
  bool _isLoadingSession = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  SBQuestionPrompt? get _current =>
      _index >= 0 && _index < _questions.length ? _questions[_index] : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoadingSession = true;
      _errorMessage = null;
      _selectedIndex = null;
      _feedbackByQuestion.clear();
    });
    final store = context.read<WorkspaceStore>();
    final questions =
        await store.loadQuestionSession(outputId: widget.output.id);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _index = 0;
      _isLoadingSession = false;
      if (questions.isEmpty) {
        _errorMessage =
            'Bu soru seti çözüm ekranı için 5 şıklı formatta hazırlanmadı. Kaynağı yeniden üretmeyi deneyebilirsin.';
      }
    });
  }

  Future<void> _submit(SBQuestionPrompt question, int selectedIndex) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final store = context.read<WorkspaceStore>();
    final feedback = await store.submitQuestionAnswer(
      outputId: widget.output.id,
      questionId: question.id,
      selectedIndex: selectedIndex,
    );
    if (!mounted) return;
    setState(() {
      _feedbackByQuestion[question.id] = feedback;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = context.read<AppRouter>();
    final question = _current;
    final feedback =
        question != null ? _feedbackByQuestion[question.id] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SBSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studyHeader(
            title: widget.output.title,
            subtitle: _isLoadingSession
                ? 'Soru oturumu hazırlanıyor'
                : 'Soru ${_index + 1} / ${_questions.isEmpty ? 1 : _questions.length}',
            icon: 'questionmark.circle',
            tint: SBColors.cyan,
          ),
          const SizedBox(height: SBSpacing.lg),
          if (_isLoadingSession)
            const SBLoadingState(
              icon: 'questionmark.circle',
              title: 'Soru çözümü hazırlanıyor',
              message: 'Sorular cevap anahtarı gösterilmeden yükleniyor...',
            )
          else if (_errorMessage != null)
            SBErrorState(
              title: 'Soru oturumu açılamadı',
              message: _errorMessage!,
              actionLabel: 'Tekrar dene',
              onAction: _loadSession,
            )
          else if (question != null) ...[
            SBCard(
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: SBSpacing.xs,
                    runSpacing: SBSpacing.xs,
                    children: [
                      _tag(question.subject),
                      _tag(question.topic),
                      _tag(question.difficulty),
                    ],
                  ),
                  const SizedBox(height: SBSpacing.md),
                  Text(question.text,
                      style:
                          SBTypography.heading3.copyWith(color: SBColors.navy)),
                ],
              ),
            ),
            const SizedBox(height: SBSpacing.lg),
            for (var i = 0; i < question.options.length; i++) ...[
              _optionButton(question, question.options[i], i),
              const SizedBox(height: SBSpacing.sm),
            ],
            if (feedback != null) ...[
              const SizedBox(height: SBSpacing.sm),
              _resultCard(feedback),
              const SizedBox(height: SBSpacing.lg),
              SBButton(
                _index + 1 == _questions.length
                    ? 'Çalışmayı Bitir'
                    : 'Sonraki Soru',
                icon: 'arrow.right',
                fullWidth: true,
                onPressed: () {
                  if (_index + 1 == _questions.length) {
                    router.replaceCurrent(AppRoute.collections);
                  } else {
                    setState(() {
                      _selectedIndex = null;
                      _index =
                          (_index + 1).clamp(0, _questions.length - 1);
                    });
                  }
                },
              ),
            ] else if (_selectedIndex != null) ...[
              const SizedBox(height: SBSpacing.sm),
              SBButton(
                'Yanıtı gönder',
                icon: 'checkmark.circle',
                isLoading: _isSubmitting,
                fullWidth: true,
                onPressed: () => _submit(question, _selectedIndex!),
              ),
            ],
          ] else
            const SBErrorState(
              title: 'Soru seti çalışma formatında değil',
              message:
                  'Bu üretim 5 şıklı çözüm ekranı için hazır dönmedi. Kaynağı yeniden üretmeyi deneyebilirsin.',
              actionLabel: null,
            ),
          const SizedBox(height: SBSpacing.lg),
          SBPdfExportControls(output: widget.output),
          const SizedBox(height: 156),
        ],
      ),
    );
  }

  Widget _optionButton(
      SBQuestionPrompt question, String option, int optionIndex) {
    final feedback = _feedbackByQuestion[question.id];
    final isAnswered = feedback != null;
    final isSelected =
        _selectedIndex == optionIndex || feedback?.selectedIndex == optionIndex;
    final isCorrect = isAnswered && feedback.correctIndex == optionIndex;
    final isWrongSelection =
        isAnswered && isSelected && feedback.isCorrect == false;
    final optionLetter = String.fromCharCode(65 + optionIndex);

    return SBPressable(
      onTap: isAnswered || _isSubmitting
          ? null
          : () => setState(() => _selectedIndex = optionIndex),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SBSpacing.md),
        decoration: BoxDecoration(
          color: isCorrect
              ? SBColors.greenBg
              : isWrongSelection
                  ? SBColors.red.withValues(alpha: 0.08)
                  : SBColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect
                ? SBColors.green
                : isWrongSelection
                    ? SBColors.red
                    : isSelected
                        ? SBColors.blue
                        : SBColors.softLine,
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isCorrect
                    ? SBColors.green
                    : isWrongSelection
                        ? SBColors.red
                        : SBColors.selectedBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                optionLetter,
                style: SBTypography.labelMedium.copyWith(
                    color: isCorrect || isWrongSelection
                        ? Colors.white
                        : SBColors.blue),
              ),
            ),
            const SizedBox(width: SBSpacing.md),
            Expanded(
              child: Text(option,
                  style:
                      SBTypography.bodyMedium.copyWith(color: SBColors.navy)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(SBQuestionAnswerFeedback feedback) {
    final color = feedback.isCorrect ? SBColors.green : SBColors.red;
    String title;
    if (feedback.isCorrect) {
      title = 'Doğru yanıt';
    } else if (feedback.correctIndex != null) {
      title =
          'Bu seçenek doğru değil. Doğru yanıt: ${String.fromCharCode(65 + feedback.correctIndex!)}';
    } else {
      title = 'Bu seçenek doğru değil';
    }

    return SBCard(
      radius: 16,
      borderColor: color.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: SBTypography.titleSmall.copyWith(color: color)),
          if (feedback.explanation.isNotEmpty) ...[
            const SizedBox(height: SBSpacing.md),
            Text(feedback.explanation,
                style: SBTypography.bodyMedium.copyWith(color: SBColors.navy)),
          ],
          for (var i = 0;
              i < feedback.optionRationales.take(5).length;
              i++) ...[
            const SizedBox(height: SBSpacing.sm),
            Text(
              '${String.fromCharCode(65 + i)} - ${feedback.optionRationales[i]}',
              style: SBTypography.caption.copyWith(color: SBColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      decoration: BoxDecoration(
        color: SBColors.selectedBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child:
          Text(text, style: SBTypography.caption.copyWith(color: SBColors.blue)),
    );
  }
}

// MARK: - Study document (summary, algorithm, table, plan, clinical, mind map…)

enum _StudyWorkspaceLayer {
  all('Tümü', 'square.grid.2x2'),
  learn('Öğren', 'book.closed'),
  flow('Akış', 'arrow.triangle.branch'),
  check('Kontrol', 'checklist');

  const _StudyWorkspaceLayer(this.title, this.icon);

  final String title;
  final String icon;
}

extension _SBStudyBlockLayer on SBStudyBlock {
  _StudyWorkspaceLayer get workspaceLayer => switch (type) {
        SBStudyBlockType.decisions ||
        SBStudyBlockType.steps ||
        SBStudyBlockType.timeline ||
        SBStudyBlockType.mindBranches =>
          _StudyWorkspaceLayer.flow,
        SBStudyBlockType.qa ||
        SBStudyBlockType.quiz ||
        SBStudyBlockType.cards =>
          _StudyWorkspaceLayer.check,
        _ => _StudyWorkspaceLayer.learn,
      };

  int get activeRecallCount => switch (type) {
        SBStudyBlockType.cards => cards?.length ?? 0,
        SBStudyBlockType.quiz => quizQuestions?.length ?? 0,
        SBStudyBlockType.qa => qaPairs?.length ?? 0,
        SBStudyBlockType.calloutList => switch (calloutStyle) {
            SBCalloutStyle.mustKnow ||
            SBCalloutStyle.tip ||
            SBCalloutStyle.confused =>
              items?.length ?? 0,
            _ => 0,
          },
        _ => 0,
      };
}

class _StudyDocumentSurface extends StatefulWidget {
  const _StudyDocumentSurface({required this.output});

  final GeneratedOutput output;

  @override
  State<_StudyDocumentSurface> createState() => _StudyDocumentSurfaceState();
}

class _StudyDocumentSurfaceState extends State<_StudyDocumentSurface> {
  _StudyWorkspaceLayer _selectedLayer = _StudyWorkspaceLayer.all;

  SBStudyDocument get _document => GeneratedContentParser.document(
        widget.output.kind,
        widget.output.content,
        widget.output.title,
        widget.output.contentText,
      );

  Color get _accent => SBOutputStyle.accent(widget.output.kind);

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final visibleBlocks = _selectedLayer == _StudyWorkspaceLayer.all
        ? document.blocks
        : document.blocks
            .where((b) => b.workspaceLayer == _selectedLayer)
            .toList();
    final activeRecallCount =
        document.blocks.fold(0, (sum, b) => sum + b.activeRecallCount);
    final flowCount = document.blocks
        .where((b) => b.workspaceLayer == _StudyWorkspaceLayer.flow)
        .length;
    final tableCount = document.blocks
        .where((b) => b.type == SBStudyBlockType.table)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SBSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studyHeader(
            title: document.title,
            subtitle: document.subtitle.isEmpty
                ? widget.output.kind.titleLabel
                : document.subtitle,
            icon: SBOutputStyle.icon(widget.output.kind),
            tint: _accent,
          ),
          const SizedBox(height: SBSpacing.lg),
          _templateIdentity(),
          const SizedBox(height: SBSpacing.lg),
          SBMetricRibbon(items: [
            SBMetricRibbonItem(
                icon: 'rectangle.stack',
                value:
                    '${document.blocks.isEmpty ? 1 : document.blocks.length}',
                label: 'çalışma bloğu',
                tint: _accent),
            SBMetricRibbonItem(
                icon: 'brain.head.profile',
                value: '$activeRecallCount',
                label: 'aktif tekrar',
                tint: SBColors.green),
            SBMetricRibbonItem(
                icon: 'arrow.triangle.branch',
                value: '$flowCount',
                label: 'akış/karar',
                tint: SBColors.orange),
            SBMetricRibbonItem(
                icon: 'tablecells',
                value: '$tableCount',
                label: 'tablo',
                tint: SBColors.cyan),
          ]),
          const SizedBox(height: SBSpacing.lg),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final layer in _StudyWorkspaceLayer.values)
                _layerChip(layer),
            ],
          ),
          if (document.summary.isNotEmpty) ...[
            const SizedBox(height: SBSpacing.lg),
            _summaryPanel(document),
          ],
          const SizedBox(height: SBSpacing.lg),
          if (visibleBlocks.isEmpty)
            SBEmptyState(
              icon: _selectedLayer.icon,
              title: '${_selectedLayer.title} katmanı boş',
              message:
                  'Bu üretimde bu katmana ait özel blok yok. Tüm katmana dönerek içeriğin tamamını görebilirsin.',
              badges: const ['Çalışma', 'Katman'],
            )
          else
            for (final block in visibleBlocks) ...[
              _blockView(block),
              const SizedBox(height: SBSpacing.lg),
            ],
          SBPdfExportControls(output: widget.output),
          const SizedBox(height: 156),
        ],
      ),
    );
  }

  Widget _templateIdentity() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SBSpacing.md),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              SBIconTile(
                  icon: SBOutputStyle.icon(widget.output.kind),
                  tint: _accent,
                  size: 40,
                  radius: 12),
              const SizedBox(width: SBSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SBOutputStyle.templateName(widget.output.kind)
                          .toUpperCase(),
                      style:
                          SBTypography.labelSmall.copyWith(color: _accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      SBOutputStyle.templatePurpose(widget.output.kind),
                      style:
                          SBTypography.caption.copyWith(color: SBColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: SBSpacing.sm,
          bottom: SBSpacing.sm,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layerChip(_StudyWorkspaceLayer layer) {
    final isSelected = _selectedLayer == layer;
    return GestureDetector(
      onTap: () {
        SBHaptics.selection();
        setState(() => _selectedLayer = layer);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SBSpacing.md, vertical: SBSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? _accent : SBColors.white,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: isSelected ? _accent : SBColors.softLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SBIcon(layer.icon,
                size: 12, color: isSelected ? Colors.white : SBColors.navy),
            const SizedBox(width: SBSpacing.xs),
            Text(layer.title,
                style: SBTypography.labelSmall.copyWith(
                    color: isSelected ? Colors.white : SBColors.navy)),
          ],
        ),
      ),
    );
  }

  Widget _summaryPanel(SBStudyDocument document) {
    return SBCard(
      radius: 18,
      borderColor: _accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SBIconTile(
                  icon: 'quote.bubble.fill',
                  tint: _accent,
                  size: 38,
                  radius: 11),
              const SizedBox(width: SBSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Çalışma Özeti',
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy)),
                  const SizedBox(height: 2),
                  Text(widget.output.kind.titleLabel,
                      style:
                          SBTypography.caption.copyWith(color: SBColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: SBSpacing.md),
          Text(document.summary,
              style: SBTypography.bodyMedium
                  .copyWith(color: SBColors.navy, height: 1.3)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String icon, Color color) {
    return Row(
      children: [
        SBIconTile(icon: icon, tint: color, size: 30, radius: 9),
        const SizedBox(width: SBSpacing.sm),
        Expanded(
          child: Text(title,
              style: SBTypography.titleSmall.copyWith(color: SBColors.navy)),
        ),
      ],
    );
  }

  Widget _blockView(SBStudyBlock block) {
    switch (block.type) {
      case SBStudyBlockType.paragraph:
        return _paragraphPanel(block.text ?? '');
      case SBStudyBlockType.calloutList:
        return _calloutCard(block.title ?? '', block.items ?? [],
            block.calloutStyle ?? SBCalloutStyle.plain);
      case SBStudyBlockType.steps:
        return _stepsCard(block.title ?? '', block.items ?? []);
      case SBStudyBlockType.decisions:
        return _decisionsCard(block.title ?? '', block.decisionNodes ?? []);
      case SBStudyBlockType.table:
        return _tableCard(block.title ?? '', block.table);
      case SBStudyBlockType.keyValues:
        return _keyValuesCard(block.title ?? '', block.keyValues ?? []);
      case SBStudyBlockType.qa:
        return _qaCard(block.title ?? '', block.qaPairs ?? []);
      case SBStudyBlockType.timeline:
        return _timelineCard(block.title ?? '', block.timelineEntries ?? []);
      case SBStudyBlockType.mindBranches:
        return _mindCard(block.title ?? '', block.mindBranches ?? []);
      case SBStudyBlockType.image:
        return _imageBlock(block.url, block.title ?? '');
      case SBStudyBlockType.audio:
        return _audioTranscriptCard(block.podcastSegments ?? []);
      case SBStudyBlockType.cards:
        return _cardsPreview(block.cards ?? []);
      case SBStudyBlockType.quiz:
        return _quizPreview(block.quizQuestions ?? []);
    }
  }

  Widget _paragraphPanel(String text) {
    return SBCard(
      radius: 16,
      borderColor: _accent.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle('Kaynak Notu', 'text.alignleft', _accent),
          const SizedBox(height: SBSpacing.sm),
          Text(text,
              style: SBTypography.bodyMedium
                  .copyWith(color: SBColors.navy, height: 1.3)),
        ],
      ),
    );
  }

  Widget _calloutCard(String title, List<String> items, SBCalloutStyle style) {
    final (color, icon) = SBOutputStyle.callout(style, _accent);
    return SBCard(
      radius: 17,
      borderColor: color.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, icon, color),
          const SizedBox(height: SBSpacing.md),
          for (var i = 0; i < items.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.field.withValues(
                    alpha: style == SBCalloutStyle.plain ? 0.55 : 0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style:
                            SBTypography.caption.copyWith(color: color)),
                  ),
                  const SizedBox(width: SBSpacing.sm),
                  Expanded(
                    child: Text(items[i],
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.navy)),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1) const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _stepsCard(String title, List<String> items) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, 'list.number', _accent),
          const SizedBox(height: SBSpacing.md),
          for (var i = 0; i < items.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration:
                        BoxDecoration(color: _accent, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: SBTypography.labelSmall
                            .copyWith(color: Colors.white)),
                  ),
                  const SizedBox(width: SBSpacing.md),
                  Expanded(
                    child: Text(items[i],
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.navy)),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1) const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _decisionsCard(String title, List<SBDecisionNode> nodes) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, 'arrow.triangle.branch', _accent),
          const SizedBox(height: SBSpacing.md),
          for (var n = 0; n < nodes.length; n++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.md),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: _accent.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nodes[n].title,
                      style: SBTypography.labelMedium
                          .copyWith(color: SBColors.navy)),
                  if (nodes[n].detail?.isNotEmpty == true) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Text(nodes[n].detail!,
                        style: SBTypography.bodySmall
                            .copyWith(color: SBColors.muted)),
                  ],
                  const SizedBox(height: SBSpacing.xs),
                  Wrap(
                    spacing: SBSpacing.sm,
                    runSpacing: SBSpacing.xs,
                    children: [
                      if (nodes[n].yes?.isNotEmpty == true)
                        _branchPill('Evet → ${nodes[n].yes}', SBColors.green),
                      if (nodes[n].no?.isNotEmpty == true)
                        _branchPill('Hayır → ${nodes[n].no}', SBColors.red),
                    ],
                  ),
                  for (final sub in nodes[n].substeps) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: SBSpacing.xs),
                        Expanded(
                          child: Text(sub,
                              style: SBTypography.bodySmall
                                  .copyWith(color: SBColors.navy)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (n < nodes.length - 1) const SizedBox(height: SBSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _branchPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SBSpacing.sm, vertical: SBSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: SBTypography.caption.copyWith(color: color)),
    );
  }

  Widget _keyValuesCard(String title, List<SBKeyValue> pairs) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, 'person.text.rectangle', _accent),
          const SizedBox(height: SBSpacing.md),
          Wrap(
            spacing: SBSpacing.sm,
            runSpacing: SBSpacing.sm,
            children: [
              for (final pair in pairs)
                Container(
                  width: 160,
                  padding: const EdgeInsets.all(SBSpacing.sm),
                  decoration: BoxDecoration(
                    color: SBColors.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pair.key,
                          style:
                              SBTypography.caption.copyWith(color: _accent)),
                      const SizedBox(height: 4),
                      Text(pair.value,
                          style: SBTypography.bodyMedium
                              .copyWith(color: SBColors.navy)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qaCard(String title, List<SBQAPair> pairs) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, 'questionmark.bubble', _accent),
          const SizedBox(height: SBSpacing.md),
          for (var i = 0; i < pairs.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: _accent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: SBTypography.caption
                                .copyWith(color: Colors.white)),
                      ),
                      const SizedBox(width: SBSpacing.sm),
                      Expanded(
                        child: Text(pairs[i].question,
                            style: SBTypography.labelMedium
                                .copyWith(color: SBColors.navy)),
                      ),
                    ],
                  ),
                  if (pairs[i].answer.isNotEmpty) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Text(pairs[i].answer,
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.green)),
                  ],
                  if (pairs[i].explanation?.isNotEmpty == true) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Text(pairs[i].explanation!,
                        style: SBTypography.bodySmall
                            .copyWith(color: SBColors.muted)),
                  ],
                ],
              ),
            ),
            if (i < pairs.length - 1) const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _timelineCard(String title, List<SBTimelineEntry> entries) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, 'calendar', _accent),
          const SizedBox(height: SBSpacing.md),
          for (var e = 0; e < entries.length; e++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.md),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entries[e].title,
                            style: SBTypography.labelMedium
                                .copyWith(color: SBColors.navy)),
                      ),
                      if (entries[e].meta?.isNotEmpty == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: SBSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(entries[e].meta!,
                              style: SBTypography.caption
                                  .copyWith(color: Colors.white)),
                        ),
                    ],
                  ),
                  for (final item in entries[e].items) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Text('• $item',
                        style: SBTypography.bodySmall
                            .copyWith(color: SBColors.navy)),
                  ],
                ],
              ),
            ),
            if (e < entries.length - 1)
              const SizedBox(height: SBSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _mindCard(String title, List<SBMindBranch> branches) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(
              title, 'point.3.connected.trianglepath.dotted', _accent),
          const SizedBox(height: SBSpacing.md),
          for (var b = 0; b < branches.length; b++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.md),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branches[b].label,
                      style:
                          SBTypography.labelMedium.copyWith(color: _accent)),
                  for (final child in branches[b].children) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Text('• $child',
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.navy)),
                  ],
                  if (branches[b].tags.isNotEmpty) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Wrap(
                      spacing: SBSpacing.xs,
                      runSpacing: SBSpacing.xs,
                      children: [
                        for (final tag in branches[b].tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: SBSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: SBColors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(tag,
                                style: SBTypography.caption
                                    .copyWith(color: SBColors.muted)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (b < branches.length - 1)
              const SizedBox(height: SBSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _imageBlock(String? url, String caption) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return SBCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              color: SBColors.field,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Padding(
                  padding: EdgeInsets.all(SBSpacing.md),
                  child: SBInlineError(
                    message:
                        'Görsel bağlantısı açılmadı. Metin içeriği gösterilmeye devam eder.',
                    isWarning: true,
                  ),
                ),
              ),
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: SBSpacing.sm),
            Text(caption,
                style: SBTypography.caption.copyWith(color: SBColors.muted)),
          ],
        ],
      ),
    );
  }

  Widget _tableCard(String title, SBStudyTable? table) {
    if (table == null) return const SizedBox.shrink();
    return SBCard(
      radius: 17,
      borderColor: SBColors.orange.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle(title, 'tablecells', _accent),
          const SizedBox(height: SBSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final header in table.headers)
                      Container(
                        width: 130,
                        margin: const EdgeInsets.only(
                            right: SBSpacing.sm, bottom: SBSpacing.sm),
                        padding: const EdgeInsets.all(SBSpacing.sm),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(header,
                            style: SBTypography.labelSmall
                                .copyWith(color: Colors.white)),
                      ),
                  ],
                ),
                for (var r = 0; r < table.rows.length; r++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cell in table.rows[r])
                        Container(
                          width: 130,
                          margin: const EdgeInsets.only(
                              right: SBSpacing.sm, bottom: SBSpacing.sm),
                          padding: const EdgeInsets.all(SBSpacing.sm),
                          decoration: BoxDecoration(
                            color:
                                r.isEven ? SBColors.field : SBColors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(cell,
                              style: SBTypography.bodySmall
                                  .copyWith(color: SBColors.navy)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardsPreview(List<SBFlashcard> cards) {
    return SBCard(
      radius: 17,
      borderColor: SBColors.blue.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle('Aktif Hatırlama Kartları', 'rectangle.on.rectangle',
              SBColors.blue),
          const SizedBox(height: SBSpacing.md),
          for (var i = 0; i < cards.take(6).length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kart ${i + 1}',
                      style:
                          SBTypography.caption.copyWith(color: SBColors.blue)),
                  const SizedBox(height: SBSpacing.xs),
                  Text(cards[i].front,
                      style: SBTypography.labelMedium
                          .copyWith(color: SBColors.navy)),
                  if (cards[i].hint.isNotEmpty) ...[
                    const SizedBox(height: SBSpacing.xs),
                    Text(cards[i].hint,
                        style: SBTypography.caption
                            .copyWith(color: SBColors.muted)),
                  ],
                ],
              ),
            ),
            if (i < cards.take(6).length - 1)
              const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _quizPreview(List<SBQlinikQuestion> questions) {
    return SBCard(
      radius: 17,
      borderColor: SBColors.cyan.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle('Kontrol Soruları', 'checklist', SBColors.cyan),
          const SizedBox(height: SBSpacing.md),
          for (var i = 0; i < questions.take(5).length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${questions[i].text}',
                      style: SBTypography.labelMedium
                          .copyWith(color: SBColors.navy)),
                  const SizedBox(height: SBSpacing.sm),
                  Wrap(
                    spacing: SBSpacing.xs,
                    runSpacing: SBSpacing.xs,
                    children: [
                      for (var o = 0; o < questions[i].options.length; o++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: SBSpacing.sm,
                              vertical: SBSpacing.xs),
                          decoration: BoxDecoration(
                            color: SBColors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${String.fromCharCode(65 + o)}) ${questions[i].options[o]}',
                            style: SBTypography.caption
                                .copyWith(color: SBColors.muted),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (i < questions.take(5).length - 1)
              const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _audioTranscriptCard(List<SBPodcastSegment> segments) {
    return SBCard(
      radius: 17,
      borderColor: _accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionTitle('Anlatım Bölümleri', 'waveform', _accent),
          const SizedBox(height: SBSpacing.md),
          for (var s = 0; s < segments.length; s++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(segments[s].title,
                      style: SBTypography.labelMedium
                          .copyWith(color: SBColors.navy)),
                  const SizedBox(height: SBSpacing.xs),
                  Text(segments[s].text,
                      style: SBTypography.bodySmall
                          .copyWith(color: SBColors.muted)),
                ],
              ),
            ),
            if (s < segments.length - 1)
              const SizedBox(height: SBSpacing.sm),
          ],
        ],
      ),
    );
  }
}

// MARK: - Podcast

class _PodcastStudySurface extends StatefulWidget {
  const _PodcastStudySurface({required this.output});

  final GeneratedOutput output;

  @override
  State<_PodcastStudySurface> createState() => _PodcastStudySurfaceState();
}

class _PodcastStudySurfaceState extends State<_PodcastStudySurface> {
  bool _isPlaying = false;
  double _speed = 1;

  List<SBPodcastSegment> get _segments {
    final document = GeneratedContentParser.document(
        GeneratedKind.podcast, widget.output.content, widget.output.title);
    for (final block in document.blocks) {
      if (block.type == SBStudyBlockType.audio) {
        return block.podcastSegments ?? [];
      }
    }
    return [];
  }

  String? get _audioUrl {
    final document = GeneratedContentParser.document(
        GeneratedKind.podcast, widget.output.content, widget.output.title);
    for (final block in document.blocks) {
      if (block.type == SBStudyBlockType.audio) return block.url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    final hasAudio = _audioUrl?.isNotEmpty == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SBSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studyHeader(
            title: widget.output.title,
            subtitle: 'Medasi Podcast',
            icon: 'waveform',
            tint: SBColors.purple,
          ),
          const SizedBox(height: SBSpacing.lg),
          SBMetricRibbon(items: [
            SBMetricRibbonItem(
                icon: 'list.bullet.rectangle',
                value: '${segments.length}',
                label: 'bölüm',
                tint: SBColors.purple),
            SBMetricRibbonItem(
                icon: 'timer',
                value: 'metin',
                label: 'süre',
                tint: SBColors.blue),
            SBMetricRibbonItem(
                icon: 'speedometer',
                value: '${_speed}x',
                label: 'oynatım',
                tint: SBColors.orange),
          ]),
          const SizedBox(height: SBSpacing.lg),
          SBCard(
            radius: 18,
            borderColor: SBColors.purple.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: hasAudio
                          ? () => setState(() => _isPlaying = !_isPlaying)
                          : null,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: hasAudio
                              ? SBColors.purple
                              : SBColors.softLine,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: SBSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasAudio
                                ? 'Sesli anlatım hazır'
                                : 'Sesli anlatım hazır değil',
                            style: SBTypography.titleSmall
                                .copyWith(color: SBColors.navy),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasAudio
                                ? 'Medasi oynatıcı'
                                : 'Aşağıdaki anlatım metnini okuyabilirsin.',
                            style: SBTypography.caption
                                .copyWith(color: SBColors.muted),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<double>(
                      enabled: hasAudio,
                      onSelected: (value) =>
                          setState(() => _speed = value),
                      itemBuilder: (context) => [
                        for (final item in [0.75, 1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem(value: item, child: Text('${item}x')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: SBSpacing.sm,
                            vertical: SBSpacing.xs),
                        decoration: BoxDecoration(
                          color: hasAudio
                              ? SBColors.purple.withValues(alpha: 0.1)
                              : SBColors.field,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_speed}x',
                          style: SBTypography.labelSmall.copyWith(
                              color: hasAudio
                                  ? SBColors.purple
                                  : SBColors.muted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SBSpacing.lg),
                SBNotice(
                  icon: 'waveform.badge.exclamationmark',
                  message:
                      'Ses dosyası henüz hazır değil. Transkript hazır; ses tamamlandığında buradan dışa aktarılacak.',
                  tint: SBColors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: SBSpacing.lg),
          for (var i = 0; i < segments.length; i++) ...[
            SBCard(
              radius: 16,
              borderColor: SBColors.purple.withValues(alpha: 0.14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: SBColors.purple, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('${i + 1}',
                            style: SBTypography.caption
                                .copyWith(color: Colors.white)),
                      ),
                      const SizedBox(width: SBSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(segments[i].title,
                                style: SBTypography.titleSmall
                                    .copyWith(color: SBColors.navy)),
                            if (segments[i].durationLabel.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(segments[i].durationLabel,
                                  style: SBTypography.caption
                                      .copyWith(color: SBColors.muted)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SBSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SBSpacing.sm),
                    decoration: BoxDecoration(
                      color: SBColors.field,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(segments[i].text,
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.navy)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SBSpacing.lg),
          ],
          SBPdfExportControls(output: widget.output),
          const SizedBox(height: 156),
        ],
      ),
    );
  }
}

// MARK: - Infographic

class _InfographicStudySurface extends StatelessWidget {
  const _InfographicStudySurface({required this.output});

  final GeneratedOutput output;

  List<String> get _blocks {
    final raw = output.content?['sections'];
    final blocks = <String>[];
    if (raw is List) {
      for (final section in raw) {
        if (section is Map) {
          final items = section['items'] ?? section['bullets'];
          if (items is List) {
            blocks.addAll(items.map((e) => e.toString()));
          }
        }
      }
    }
    return blocks;
  }

  String? get _imageUrl {
    final url = output.content?['image_url'] ?? output.content?['imageUrl'];
    return url is String && url.isNotEmpty ? url : null;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks;
    final imageUrl = _imageUrl;
    final hasImage = imageUrl != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SBSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _studyHeader(
            title: output.title,
            subtitle: hasImage
                ? 'Paylaşılabilir Medasi infografik'
                : 'Metin bloklarıyla güvenli infografik',
            icon: 'photo.on.rectangle',
            tint: SBColors.cyan,
          ),
          const SizedBox(height: SBSpacing.lg),
          SBMetricRibbon(items: [
            SBMetricRibbonItem(
                icon: hasImage ? 'photo' : 'doc.richtext.fill',
                value: hasImage ? 'görsel' : 'blok',
                label: 'format',
                tint: SBColors.cyan),
            SBMetricRibbonItem(
                icon: 'rectangle.stack',
                value: '${blocks.isEmpty ? 1 : blocks.length}',
                label: 'bilgi bloğu',
                tint: SBColors.blue),
            SBMetricRibbonItem(
                icon: 'checkmark.seal',
                value: 'PDF',
                label: 'export',
                tint: SBColors.green),
          ]),
          const SizedBox(height: SBSpacing.lg),
          SBCard(
            radius: 18,
            borderColor: SBColors.cyan.withValues(alpha: 0.22),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: SBColors.field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(SBSpacing.lg),
                  child: hasImage
                      ? Image.network(imageUrl, fit: BoxFit.contain)
                      : _fallbackBody(blocks),
                ),
                Padding(
                  padding: const EdgeInsets.all(SBSpacing.md),
                  child: Text(
                    'MEDASI',
                    style: SBTypography.scaled(18, weight: FontWeight.w900)
                        .copyWith(
                            color: SBColors.blue.withValues(alpha: 0.22)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SBSpacing.lg),
          SBNotice(
            icon: 'photo.badge.exclamationmark',
            message:
                'Paylaşılabilir görsel henüz hazır değil. Görsel tamamlandığında buradan doğrudan paylaşılacak.',
            tint: SBColors.cyan,
          ),
          const SizedBox(height: SBSpacing.lg),
          SBPdfExportControls(output: output),
          const SizedBox(height: 156),
        ],
      ),
    );
  }

  Widget _fallbackBody(List<String> blocks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SBIconTile(
                icon: 'text.alignleft',
                tint: Color(0xFF08C7D6),
                size: 38,
                radius: 11),
            const SizedBox(width: SBSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Metin infografik',
                      style: SBTypography.titleSmall
                          .copyWith(color: SBColors.navy)),
                  const SizedBox(height: 3),
                  Text('Görsel beklenmeden okunabilir çalışma.',
                      style: SBTypography.caption
                          .copyWith(color: SBColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: SBSpacing.md),
        if (blocks.isEmpty)
          const SBInlineError(
            message:
                'İnfografik içeriği boş döndü. Kaynağı yeniden üretmeyi deneyebilirsin.',
            isWarning: true,
          )
        else
          for (var i = 0; i < blocks.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SBSpacing.sm),
              decoration: BoxDecoration(
                color: SBColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: SBColors.cyan.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: SBTypography.labelSmall
                            .copyWith(color: SBColors.cyan)),
                  ),
                  const SizedBox(width: SBSpacing.sm),
                  Expanded(
                    child: Text(blocks[i],
                        style: SBTypography.bodyMedium
                            .copyWith(color: SBColors.navy)),
                  ),
                ],
              ),
            ),
            if (i < blocks.length - 1) const SizedBox(height: SBSpacing.sm),
          ],
      ],
    );
  }
}
