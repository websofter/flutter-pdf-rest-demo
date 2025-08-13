import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_file/main.dart';

void main() {
  testWidgets('PDF Viewer app loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PdfViewer(),
    ));

    expect(find.text('Choose a PDF file to open'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.save), findsOneWidget);
  });
}
