import 'package:flutter/material.dart';

import '../../design_system/sb_colors.dart';
import '../../models/models.dart';
import 'sourcelab_tool_flow_view.dart';

/// Port of PodcastView.
class PodcastView extends StatelessWidget {
  const PodcastView({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceLabToolFlowView(
      title: 'Dinleme Tekrarı',
      subtitle: 'Kaynağı yolda dinlenecek konu anlatımına çevir.',
      kind: GeneratedKind.podcast,
      outputLabel: 'Dinleme tekrarı',
      icon: 'waveform',
      tint: SBColors.purple,
      controls: const [
        'Tek anlatıcı',
        'İki anlatıcı',
        '8 dk',
        '15 dk',
        'Sakin'
      ],
      previewSections: const [
        'Kısa giriş',
        'Kavram anlatımı',
        'Klinik örnek',
        'Son tekrar soruları'
      ],
    );
  }
}
