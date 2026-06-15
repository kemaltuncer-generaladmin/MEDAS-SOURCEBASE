import 'package:flutter/material.dart';

import '../../design_system/sb_colors.dart';
import '../../models/models.dart';
import 'sourcelab_tool_flow_view.dart';

/// Port of PlanView.
class PlanView extends StatelessWidget {
  const PlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceLabToolFlowView(
      title: 'Öğrenme Planı',
      subtitle: 'Kaynağı günlük plana çevir.',
      kind: GeneratedKind.learningPlan,
      outputLabel: 'Öğrenme Planı',
      icon: 'calendar.badge.clock',
      tint: SBColors.green,
      controls: const ['3 gün', '7 gün', '14 gün', 'Günde 45 dk', 'Günde 90 dk'],
      previewSections: const ['Hedef', 'Günlük bloklar', 'Tekrar', 'Son kontrol'],
    );
  }
}
