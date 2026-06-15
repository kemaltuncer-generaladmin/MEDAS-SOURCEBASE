import 'package:flutter/material.dart';

import '../../design_system/sb_colors.dart';
import '../../models/models.dart';
import 'sourcelab_tool_flow_view.dart';

/// Port of MindMapView.
class MindMapView extends StatelessWidget {
  const MindMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceLabToolFlowView(
      title: 'Zihin Haritası',
      subtitle: 'Kavram ilişkilerini çıkar.',
      kind: GeneratedKind.mindMap,
      outputLabel: 'Zihin Haritası',
      icon: 'point.3.connected.trianglepath.dotted',
      tint: SBColors.purple,
      controls: const [
        '3 ana dal',
        '5 ana dal',
        'Klinik ilişki',
        'Tanı odaklı',
        'Kısa etiketler'
      ],
      previewSections: const [
        'Merkez',
        'Ana dallar',
        'Alt kavramlar',
        'Karıştırılanlar'
      ],
    );
  }
}
