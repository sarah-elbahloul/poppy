import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

/// Usage:
///
/// 1. Replace `PoppyLogo` import with your actual import.
/// 2. Open this page in your app.
/// 3. Press the export button.
/// 4. The PNG will be written to the app documents directory.
///
/// NOTE:
/// On Android/iOS you will usually want to use
/// path_provider to obtain a writable location.

class PoppyLogoExporter extends StatefulWidget {
  const PoppyLogoExporter({super.key});

  @override
  State<PoppyLogoExporter> createState() => _PoppyLogoExporterState();
}

class _PoppyLogoExporterState extends State<PoppyLogoExporter> {
  final GlobalKey _logoKey = GlobalKey();

  Future<void> exportPng() async {
    final boundary =
    _logoKey.currentContext!.findRenderObject()
    as RenderRepaintBoundary;

    final ui.Image image = await boundary.toImage(
      pixelRatio: 2,
    );

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final Uint8List pngBytes =
    byteData!.buffer.asUint8List();

    final blob = html.Blob([pngBytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..download = '${image.height}x${image.width}.png'
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Poppy Logo'),
      ),
        body: Center(
          child: RepaintBoundary(
            key: _logoKey,
            child: Container(
              width: 1024,
              height: 1024,
              color: Colors.transparent,
              padding: EdgeInsetsGeometry.all(100),
              child: const PoppyLogo(
                size: 1024,
                background: Colors.transparent,
              ),
            ),
          ),
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: exportPng,
        child: const Icon(Icons.download),
      ),
    );
  }
}
