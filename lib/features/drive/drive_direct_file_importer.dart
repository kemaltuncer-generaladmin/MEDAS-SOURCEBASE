import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/workspace_store.dart';
import '../../models/models.dart';

/// Opens the platform file picker and uploads the selected source to SourceBase.
Future<void> showDriveDirectFileImporter(
  BuildContext context, {
  DriveDestination? initialDestination,
  required void Function(bool uploaded) onComplete,
}) async {
  final store = context.read<WorkspaceStore>();

  if (!store.hasLoadedWorkspace) {
    await store.loadWorkspace();
  }

  // Resolve destination, creating defaults when the drive is empty.
  var destination = (initialDestination != null && initialDestination.isUsable)
      ? initialDestination
      : store.preferredUploadDestination;

  if (destination == null) {
    final course = store.workspace.primaryCourse ??
        await store.createCourse(
            title: 'Yeni Ders', iconName: 'book.closed');
    if (course == null) {
      store.toast('Yükleme için ders ve bölüm oluşturulamadı.');
      return;
    }
    var section =
        course.sections.isNotEmpty ? course.sections.first : null;
    section ??=
        await store.createSection(courseId: course.id, title: 'Genel');
    if (section == null) {
      store.toast('Yükleme için ders ve bölüm oluşturulamadı.');
      return;
    }
    destination = DriveDestination(
      courseId: course.id,
      sectionId: section.id,
      courseTitle: course.title,
      sectionTitle: section.title,
    );
  }

  if (!context.mounted) return;

  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'pptx', 'ppt', 'docx', 'doc', 'zip'],
    allowMultiple: false,
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    store.toast('Dosya seçilmedi.');
    onComplete(false);
    return;
  }

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    store.toast('Dosya içeriği okunamadı.');
    onComplete(false);
    return;
  }

  await store.uploadPickedFile(
    PickedDriveFile(
      name: file.name,
      path: file.path ?? file.name,
      sizeBytes: file.size,
      contentType: _contentType(file.extension ?? file.name),
      bytes: bytes,
    ),
    destination: destination,
  );
  onComplete(true);
}

String _contentType(String extensionOrName) {
  final ext = extensionOrName.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}
