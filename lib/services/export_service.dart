import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'telemetry_service.dart';

class ExportService {
  static Future<String> exportAndShare(
    String participantId,
    String prototype,
  ) async {
    final json = await TelemetryService.instance.exportToJson();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filename = 'analytics_${participantId}_${prototype}_$timestamp.json';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Dados de telemetria - $participantId - $prototype',
      ),
    );

    return file.path;
  }
}
