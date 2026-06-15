import 'models.dart';

class DisciplineTool {
  final GeneratedKind kind;
  final String title;
  final String subtitle;
  final String icon;

  DisciplineTool({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  String get id => "${kind.rawValue}-$title";
}

class DisciplineOptionProfile {
  final String heroSubtitle;
  final List<DisciplineTool> mainKinds;
  final List<DisciplineTool> deepKinds;
  final String aiPersonaHint;

  DisciplineOptionProfile({
    required this.heroSubtitle,
    required this.mainKinds,
    required this.deepKinds,
    required this.aiPersonaHint,
  });

  static DisciplineOptionProfile getProfile(String? department) {
    switch ((department ?? '').trim()) {
      case "Diş Hekimliği":
        return dishekimligi;
      case "Hemşirelik":
        return hemsirelik;
      case "Ebelik":
        return ebelik;
      case "Veterinerlik":
        return veterinerlik;
      case "Tıp":
      default:
        return tip;
    }
  }

  // Tıp
  static final tip = DisciplineOptionProfile(
    heroSubtitle: "Flashcard, soru, özet, akış, tablo ve klinik tekrarları tek yerden başlat.",
    mainKinds: [
      DisciplineTool(kind: GeneratedKind.question, title: "Soru", subtitle: "TUS tarzı soru pratiği", icon: "questionmark.circle"),
      DisciplineTool(kind: GeneratedKind.summary, title: "Yüksek Getirili Özet", subtitle: "Kısa ve net tekrar", icon: "doc.text"),
      DisciplineTool(kind: GeneratedKind.algorithm, title: "Akış", subtitle: "Karar adımlarını sadeleştir", icon: "arrow.triangle.branch"),
      DisciplineTool(kind: GeneratedKind.comparison, title: "Karşılaştırma", subtitle: "Konuları yan yana kıyasla", icon: "tablecells"),
      DisciplineTool(kind: GeneratedKind.flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
    ],
    deepKinds: [
      DisciplineTool(kind: GeneratedKind.clinicalScenario, title: "Klinik Senaryo", subtitle: "Ayırıcı tanı pratiği", icon: "cross.case"),
      DisciplineTool(kind: GeneratedKind.examMorningSummary, title: "Sınav Sabahı", subtitle: "7 dakikalık kritik tarama", icon: "bolt"),
      DisciplineTool(kind: GeneratedKind.learningPlan, title: "Öğrenme Planı", subtitle: "Bugün, 72 saat, 7 gün", icon: "checklist"),
      DisciplineTool(kind: GeneratedKind.mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkilerini ayır", icon: "point.3.connected.trianglepath.dotted"),
      DisciplineTool(kind: GeneratedKind.infographic, title: "İnfografik", subtitle: "Tek bakışlık görsel hafıza", icon: "chart.bar.doc.horizontal"),
      DisciplineTool(kind: GeneratedKind.podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic"),
    ],
    aiPersonaHint: "Tıp öğrencisi: TUS/USMLE tarzı; vaka, algoritma ve yüksek getirili klinik bilgi odaklı.",
  );

  // Diş Hekimliği
  static final dishekimligi = DisciplineOptionProfile(
    heroSubtitle: "DUS odaklı çalış: soru kampı, branş karşılaştırmaları ve yüksek getirili özetler.",
    mainKinds: [
      DisciplineTool(kind: GeneratedKind.question, title: "DUS Soru Kampı", subtitle: "5 şıklı klinik soru", icon: "questionmark.circle"),
      DisciplineTool(kind: GeneratedKind.comparison, title: "Materyal / Sınıflama", subtitle: "Branş bazlı karşılaştırma", icon: "tablecells"),
      DisciplineTool(kind: GeneratedKind.summary, title: "DUS Yüksek Getirili", subtitle: "Branş branş özet", icon: "doc.text"),
      DisciplineTool(kind: GeneratedKind.flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
      DisciplineTool(kind: GeneratedKind.algorithm, title: "Tedavi Akışı", subtitle: "Klinik karar adımları", icon: "arrow.triangle.branch"),
    ],
    deepKinds: [
      DisciplineTool(kind: GeneratedKind.clinicalScenario, title: "Klinik Vaka (Diş)", subtitle: "Restoratif · endo · cerrahi", icon: "cross.case"),
      DisciplineTool(kind: GeneratedKind.examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
      DisciplineTool(kind: GeneratedKind.mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
      DisciplineTool(kind: GeneratedKind.learningPlan, title: "Öğrenme Planı", subtitle: "Günlere bölünmüş", icon: "checklist"),
      DisciplineTool(kind: GeneratedKind.infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
      DisciplineTool(kind: GeneratedKind.podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic"),
    ],
    aiPersonaHint: "Diş hekimliği öğrencisi: DUS tarzı; ağız-diş-çene klinik branşları (restoratif, endodonti, protetik, cerrahi, periodontoloji, ortodonti, pedodonti, radyoloji) odaklı.",
  );

  // Hemşirelik
  static final hemsirelik = DisciplineOptionProfile(
    heroSubtitle: "Bakım planı, ilaç dozu ve klinik uygulama odaklı çalış — TUS değil, KPSS ve klinik pratiğe göre.",
    mainKinds: [
      DisciplineTool(kind: GeneratedKind.summary, title: "Yüksek Getirili Özet", subtitle: "Sınav ve kliniğe hızlı tekrar", icon: "doc.text"),
      DisciplineTool(kind: GeneratedKind.comparison, title: "Bakım Planı (NANDA/NIC/NOC)", subtitle: "Tanı · Girişim · Çıktı", icon: "list.bullet.clipboard"),
      DisciplineTool(kind: GeneratedKind.algorithm, title: "Bakım Akışı / İlaç Dozu", subtitle: "Karar ve doz hesabı adımları", icon: "arrow.triangle.branch"),
      DisciplineTool(kind: GeneratedKind.flashcard, title: "Flashcard", subtitle: "Vital değer, ilaç, tanı kartları", icon: "rectangle.on.rectangle"),
      DisciplineTool(kind: GeneratedKind.question, title: "Soru", subtitle: "KPSS ve klinik soru pratiği", icon: "questionmark.circle"),
    ],
    deepKinds: [
      DisciplineTool(kind: GeneratedKind.clinicalScenario, title: "Klinik Vaka", subtitle: "Bakım odaklı vaka", icon: "cross.case"),
      DisciplineTool(kind: GeneratedKind.learningPlan, title: "Öğrenme Planı", subtitle: "Günlere bölünmüş", icon: "checklist"),
      DisciplineTool(kind: GeneratedKind.mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
      DisciplineTool(kind: GeneratedKind.examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
      DisciplineTool(kind: GeneratedKind.infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
      DisciplineTool(kind: GeneratedKind.podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic"),
    ],
    aiPersonaHint: "Hemşirelik öğrencisi: insan hekimliği teşhis ağırlığı YERİNE hemşirelik bakım süreci — bakım planı (NANDA/NIC/NOC: tanı, girişim, çıktı), ilaç dozu/hesaplama (mg/kg, damla/dk, infüzyon hızı), vital takip ve klinik uygulama odaklı. Sınav hedefi TUS değil KPSS/klinik pratik.",
  );

  // Ebelik
  static final ebelik = DisciplineOptionProfile(
    heroSubtitle: "Gebelik takibi, doğum eylemi ve partograf odaklı çalış — KPSS ve klinik pratik için.",
    mainKinds: [
      DisciplineTool(kind: GeneratedKind.algorithm, title: "Partograf / Doğum Eylemi", subtitle: "Evre 1-2-3-4 karar tahtası", icon: "arrow.triangle.branch"),
      DisciplineTool(kind: GeneratedKind.summary, title: "Antenatal / Neonatal Özet", subtitle: "Trimester ve yenidoğan", icon: "doc.text"),
      DisciplineTool(kind: GeneratedKind.flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
      DisciplineTool(kind: GeneratedKind.comparison, title: "Karşılaştırma", subtitle: "Evre / izlem kıyaslama", icon: "tablecells"),
      DisciplineTool(kind: GeneratedKind.question, title: "Soru", subtitle: "KPSS ve klinik soru pratiği", icon: "questionmark.circle"),
    ],
    deepKinds: [
      DisciplineTool(kind: GeneratedKind.clinicalScenario, title: "Gebelik / Doğum Vakası", subtitle: "Obstetrik senaryo", icon: "cross.case"),
      DisciplineTool(kind: GeneratedKind.learningPlan, title: "Antenatal İzlem Planı", subtitle: "Trimester takibi", icon: "checklist"),
      DisciplineTool(kind: GeneratedKind.mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
      DisciplineTool(kind: GeneratedKind.examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
      DisciplineTool(kind: GeneratedKind.infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
      DisciplineTool(kind: GeneratedKind.podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic"),
    ],
    aiPersonaHint: "Ebelik öğrencisi: gebelik takibi (antenatal), doğum eylemi evreleri, partograf (servikal dilatasyon, fetal/maternal izlem), postpartum/lohusa bakımı ve neonatal bakım (APGAR) odaklı. Sınav hedefi KPSS/klinik pratik.",
  );

  // Veterinerlik
  static final veterinerlik = DisciplineOptionProfile(
    heroSubtitle: "Tür bazlı çalış — büyükbaş, küçükbaş, kanatlı, egzotik. Karşılaştırma, saha vakası ve zoonoz odaklı.",
    mainKinds: [
      DisciplineTool(kind: GeneratedKind.comparison, title: "Tür Karşılaştırma", subtitle: "Büyükbaş · küçükbaş · kanatlı · egzotik", icon: "tablecells"),
      DisciplineTool(kind: GeneratedKind.summary, title: "Yüksek Getirili Özet", subtitle: "Kısa ve net tekrar", icon: "doc.text"),
      DisciplineTool(kind: GeneratedKind.flashcard, title: "Flashcard", subtitle: "Tekrar kartları", icon: "rectangle.on.rectangle"),
      DisciplineTool(kind: GeneratedKind.algorithm, title: "Zoonoz / Karar Akışı", subtitle: "Tanıma ve yönetim adımları", icon: "arrow.triangle.branch"),
      DisciplineTool(kind: GeneratedKind.question, title: "Soru", subtitle: "Uzmanlık ve saha soru pratiği", icon: "questionmark.circle"),
    ],
    deepKinds: [
      DisciplineTool(kind: GeneratedKind.clinicalScenario, title: "Saha Vakası", subtitle: "Tür özelinde pratik", icon: "cross.case"),
      DisciplineTool(kind: GeneratedKind.mindMap, title: "Zihin Haritası", subtitle: "Kavram ilişkileri", icon: "point.3.connected.trianglepath.dotted"),
      DisciplineTool(kind: GeneratedKind.examMorningSummary, title: "Sınav Sabahı", subtitle: "Kritik tarama", icon: "bolt"),
      DisciplineTool(kind: GeneratedKind.learningPlan, title: "Öğrenme Planı", subtitle: "Bugün, 72 saat, 7 gün", icon: "checklist"),
      DisciplineTool(kind: GeneratedKind.infographic, title: "İnfografik", subtitle: "Görsel hafıza", icon: "chart.bar.doc.horizontal"),
      DisciplineTool(kind: GeneratedKind.podcast, title: "Podcast", subtitle: "Dinlenebilir tekrar", icon: "mic"),
    ],
    aiPersonaHint: "Veteriner hekimlik öğrencisi: tür farkları (büyükbaş/küçükbaş/kanatlı/egzotik; doz, anatomi, semptom değişir), saha pratiği ve zoonoz odaklı; hasta = hayvan, insan hekimliği varsayma.",
  );
}

extension GeneratedKindExtension on GeneratedKind {
  bool get isDeepKind {
    switch (this) {
      case GeneratedKind.clinicalScenario:
      case GeneratedKind.examMorningSummary:
      case GeneratedKind.learningPlan:
      case GeneratedKind.podcast:
      case GeneratedKind.infographic:
      case GeneratedKind.mindMap:
        return true;
      default:
        return false;
    }
  }
}
