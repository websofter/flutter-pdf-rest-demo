import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class SaveHelper {
  static Future<void> save(List<int> bytes, String fileName) async {
    String? saveLocation = await FilePicker.platform.saveFile(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      allowedExtensions: <String>['pdf'],
    );

    if (Platform.isWindows || Platform.isMacOS) {
      if (saveLocation != null) {
        final File file = File(saveLocation);
        if (file.existsSync()) {
          await file.delete();
        }
        await file.writeAsBytes(bytes);
      }
    }
  }
}
