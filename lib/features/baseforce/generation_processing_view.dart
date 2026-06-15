import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/workspace_store.dart';
import '../../design_system/sb_background.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_motion.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import '../../models/models.dart';
import '../study/sb_output_style.dart';

/// Minimal "generation started" screen: kicks off the job, shows a clean
/// 3-second countdown, then hands the user to the queue.
/// Port of GenerationProcessingView.
class GenerationProcessingView extends StatefulWidget {
  const GenerationProcessingView({
    super.key,
    required this.sourceFileId,
    required this.kindRawValue,
    required this.label,
    required this.surface,
    required this.mode,
    this.extraOptions = const {},
  });

  final String sourceFileId;
  final String kindRawValue;
  final String label;
  final String surface;
  final String mode;
  final Map<String, String> extraOptions;

  @override
  State<GenerationProcessingView> createState() =>
      _GenerationProcessingViewState();
}

class _GenerationProcessingViewState extends State<GenerationProcessingView> {
  bool _didStart = false;
  int _countdown = 3;
  String? _errorMessage;

  GeneratedKind get _kind => GeneratedKind.fromString(widget.kindRawValue);

  Color get _accent => SBOutputStyle.outputColor(_kind);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  Future<void> _startIfNeeded() async {
    if (_didStart) return;
    _didStart = true;
    final store = context.read<WorkspaceStore>();

    var source = store.file(widget.sourceFileId) ??
        (store.readyFiles.isNotEmpty ? store.readyFiles.first : null);
    if (source == null) {
      await store.loadWorkspace();
      source = store.file(widget.sourceFileId);
      if (source == null) {
        setState(() => _errorMessage =
            "Bu kaynak üretim için hazır değil. Drive'dan hazır bir kaynak seç.");
        return;
      }
    }
    await _launch(store, source);
  }

  Future<void> _launch(WorkspaceStore store, DriveFile source) async {
    final job = await store.startGeneration(file: source, kind: _kind);
    if (!mounted) return;
    if (job == null) {
      setState(() => _errorMessage =
          store.toastMessage ?? 'Üretim başlatılamadı. Tekrar dene.');
      return;
    }
    SBHaptics.success();
    await _countdownThenQueue();
  }

  Future<void> _countdownThenQueue() async {
    for (var value = 3; value >= 1; value--) {
      if (!mounted) return;
      setState(() => _countdown = value);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    context.read<AppRouter>().replaceCurrent(
        AppRoute.queue(surface: SourceBaseQueueSurface.surfaceFor(_kind)));
  }

  void _restart() {
    setState(() {
      _errorMessage = null;
      _countdown = 3;
      _didStart = false;
    });
    _startIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final router = context.read<AppRouter>();

    return Scaffold(
      appBar: _errorMessage != null
          ? AppBar(
              backgroundColor: SBColors.page,
              elevation: 0,
              leading: BackButton(color: SBColors.blue),
            )
          : null,
      body: SBPageBackground(
        tone: SBPageTone.cool,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Padding(
                padding: const EdgeInsets.all(SBSpacing.xl),
                child: _errorMessage != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SBErrorState(
                            title: 'Üretim başlatılamadı',
                            message: _errorMessage!,
                            actionLabel: 'Tekrar dene',
                            onAction: _restart,
                            context_: SBErrorContext.generation,
                          ),
                          const SizedBox(height: SBSpacing.md),
                          SBButton(
                            'Kuyruğa git',
                            icon: 'clock',
                            variant: SBButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: () => router.replaceCurrent(
                              AppRoute.queue(
                                  surface: SourceBaseQueueSurface.surfaceFor(
                                      _kind)),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SBBreathing(
                            child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 132,
                                height: 132,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _accent.withValues(alpha: 0.22),
                                      _accent.withValues(alpha: 0.06),
                                    ],
                                  ),
                                  border: Border.all(
                                      color:
                                          _accent.withValues(alpha: 0.45),
                                      width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          _accent.withValues(alpha: 0.40),
                                      blurRadius: 34,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: SBMotion.springDuration,
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                        scale: animation,
                                        child: FadeTransition(
                                            opacity: animation,
                                            child: child)),
                                child: Text(
                                  '$_countdown',
                                  key: ValueKey(_countdown),
                                  style: SBTypography.scaled(56,
                                          weight: FontWeight.bold)
                                      .copyWith(color: _accent),
                                ),
                              ),
                            ],
                          ),
                          ),
                          const SizedBox(height: SBSpacing.lg),
                          Text('Üretim başladı',
                              style: SBTypography.titleLarge
                                  .copyWith(color: SBColors.navy)),
                          const SizedBox(height: SBSpacing.xs),
                          Text(
                            '${SBOutputStyle.templateName(_kind)} kuyruğa eklendi. Hazır olunca bildireceğiz.',
                            textAlign: TextAlign.center,
                            style: SBTypography.bodyMedium
                                .copyWith(color: SBColors.muted),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
