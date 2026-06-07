import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:poppy/core/core.dart';

/// A utility screen used to export the [PoppyLogo] as a high-resolution PNG.
///
/// This is intended for development use to generate assets for the app.
class PoppyLogoExporter extends StatefulWidget {
  const PoppyLogoExporter({super.key});

  @override
  State<PoppyLogoExporter> createState() => _PoppyLogoExporterState();
}

class _PoppyLogoExporterState extends State<PoppyLogoExporter> {
  final GlobalKey _logoKey = GlobalKey();

  /// Captures the [RepaintBoundary] as an image and triggers a download in the browser.
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

    // Trigger download in the browser.
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
              padding: const EdgeInsets.all(100),
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
