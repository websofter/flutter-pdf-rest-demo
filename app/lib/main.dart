import 'dart:io';
import 'helper/save_helper.dart'
    if (dart.library.html) 'helper/save_helper_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PdfViewer(),
  ));
}

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(onPressed: _openFile, icon: const Icon(Icons.folder_open)),
          IconButton(onPressed: _saveFile, icon: const Icon(Icons.save)),
          Spacer()
        ],
      ),
      body: _pdfBytes != null
          ? SfPdfViewer.memory(
              _pdfBytes!,
              controller: _pdfViewerController,
            )
          : const Center(
              child: Text(
              'Choose a PDF file to open',
            )),
    );
  }

  /// Open a PDF file from the local device's storage.
  Future<void> _openFile() async {
    FilePickerResult? filePickerResult = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (filePickerResult != null) {
      if (kIsWeb) {
        _pdfBytes = filePickerResult.files.single.bytes;
      } else {
        _pdfBytes =
            await File(filePickerResult.files.single.path!).readAsBytes();
      }
    }
    setState(() {});
  }

  /// Save a PDF file to the desired local device's storage location.
  Future<void> _saveFile() async {
    if (_pdfViewerController.pageCount > 0) {
      List<int> bytes = await _pdfViewerController.saveDocument();
      SaveHelper.save(bytes, 'Saved.pdf');
    }
  }
}
