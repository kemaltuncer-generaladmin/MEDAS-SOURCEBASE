import 'package:flutter/material.dart';

import '../../design_system/sb_colors.dart';
import '../../models/models.dart';
import 'sourcelab_tool_flow_view.dart';

/// Port of InfographicView.
class InfographicView extends StatelessWidget {
  const InfographicView({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceLabToolFlowView(
      title: 'İnfografik',
      subtitle: 'Kaynağı tek bakışta hatırlanacak görsel özete çevir.',
      kind: GeneratedKind.infographic,
      outputLabel: 'İnfografik',
      icon: 'chart.bar.doc.horizontal',
      tint: SBColors.cyan,
      controls: const ['Klinik', 'Sınav', 'Dikey', 'Kare', 'Yoğun', 'Sade'],
      previewSections: const [
        'Canlı görsel',
        'Ana mesaj',
        '5+ bilgi bloğu',
        'Kırmızı bayrak',
        'Hızlı kontrol',
        'Kaynak notu'
      ],
    );
  }
}
