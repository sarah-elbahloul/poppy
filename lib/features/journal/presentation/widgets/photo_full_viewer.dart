import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/data/models/photo.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Photo Viewer Screen
// ─────────────────────────────────────────────────────────────

/// Represents an item to be displayed in the photo viewer.
class PhotoViewerItem {
  final String? networkUrl;
  final String? localPath;
  final Uint8List? bytes;

  const PhotoViewerItem({
    this.networkUrl,
    this.localPath,
    this.bytes,
  });

  factory PhotoViewerItem.fromPhoto(dynamic photo) {
    if (photo is Photo) {
      return PhotoViewerItem(
        networkUrl: photo.signedUrl,
        localPath: photo.localPath,
      );
    }
    return PhotoViewerItem(
      networkUrl: photo?.signedUrl as String?,
      localPath: photo?.localPath as String?,
    );
  }

  factory PhotoViewerItem.fromXFile(XFile xFile, {Uint8List? bytes}) {
    return PhotoViewerItem(
      localPath: xFile.path,
      bytes: bytes,
    );
  }

  bool get hasImage =>
      (networkUrl?.isNotEmpty ?? false) ||
      (localPath?.isNotEmpty ?? false) ||
      (bytes != null);
}

/// A fullscreen photo viewer with zoom, download, and delete.
class PhotoFullViewer extends StatefulWidget {
  final List<PhotoViewerItem> photos;
  final int initialIndex;
  final ValueChanged<int>? onDelete;

  const PhotoFullViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onDelete,
  });

  static Future<void> open(
    BuildContext context, {
    required List<PhotoViewerItem> photos,
    int initialIndex = 0,
    ValueChanged<int>? onDelete,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoFullViewer(
          photos: photos,
          initialIndex: initialIndex,
          onDelete: onDelete,
        ),
      ),
    );
  }

  @override
  State<PhotoFullViewer> createState() => _PhotoFullViewerState();
}

class _PhotoFullViewerState extends State<PhotoFullViewer>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentIndex;
  late List<PhotoViewerItem> _photos;

  final List<TransformationController> _transformationControllers = [];

  bool _isDownloading = false;
  bool _showControls = true;

  late final AnimationController _controlsAnimation;
  late final Animation<double> _controlsOpacity;

  Timer? _hideControlsTimer;

  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;
  static const double _doubleTapScale = 2.5;
  static const Duration _controlsHideDelay = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
    _currentIndex = widget.initialIndex.clamp(0, _photos.isEmpty ? 0 : _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _initTransformationControllers();

    _controlsAnimation = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _controlsOpacity = CurvedAnimation(
      parent: _controlsAnimation,
      curve: AppCurve.standard,
    );
    _controlsAnimation.forward();

    _scheduleHideControls();
  }

  void _initTransformationControllers() {
    for (int i = 0; i < _photos.length; i++) {
      final controller = TransformationController();
      controller.addListener(_onTransformationChanged);
      _transformationControllers.add(controller);
    }
  }

  void _onTransformationChanged() {
    if (_currentIndex >= _transformationControllers.length) return;

    final scale = _transformationControllers[_currentIndex]
        .value
        .getMaxScaleOnAxis();

    if (scale > 1.01) {
      _cancelHideControls();
    } else {
      _scheduleHideControls();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _pageController.dispose();
    _controlsAnimation.dispose();
    for (final controller in _transformationControllers) {
      controller.removeListener(_onTransformationChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsHideDelay, () {
      if (mounted && _showControls) {
        _setControlsVisible(false);
      }
    });
  }

  void _cancelHideControls() {
    _hideControlsTimer?.cancel();
  }

  void _setControlsVisible(bool visible) {
    if (_showControls == visible) return;
    setState(() => _showControls = visible);
    if (visible) {
      _controlsAnimation.forward();
      _scheduleHideControls();
    } else {
      _controlsAnimation.reverse();
    }
  }

  void _toggleControls() {
    _setControlsVisible(!_showControls);
  }

  void _resetZoom(int index) {
    if (index < 0 || index >= _transformationControllers.length) return;
    _animateTransformation(
      _transformationControllers[index],
      Matrix4.identity(),
    );
  }

  void _handleDoubleTap(TapDownDetails details, int index) {
    if (index < 0 || index >= _transformationControllers.length) return;
    final controller = _transformationControllers[index];
    final currentScale = controller.value.getMaxScaleOnAxis();

    if (currentScale > _minScale + 0.1) {
      _animateTransformation(controller, Matrix4.identity());
    } else {
      _animateZoomToPoint(controller, details.localPosition);
    }
  }

  void _animateZoomToPoint(
    TransformationController controller,
    Offset focalPoint,
  ) {
    const scale = _doubleTapScale;

    final Matrix4 nextTransform = Matrix4.identity()
      ..translate(
        -focalPoint.dx * (scale - 1),
        -focalPoint.dy * (scale - 1),
      )
      ..scale(scale);

    _animateTransformation(controller, nextTransform);
  }

  void _animateTransformation(
      TransformationController controller,
      Matrix4 target,
      ) {
    final start = controller.value.clone();

    final animation = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );

    final tween = Matrix4Tween(
      begin: start,
      end: target,
    );

    animation.addListener(() {
      controller.value = tween.evaluate(CurvedAnimation(
        parent: animation,
        curve: AppCurve.enter,
      ));
    });

    animation.forward().then((_) {
      animation.dispose();
    });
  }

  Future<void> _downloadPhoto() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final photo = _photos[_currentIndex];
      File? sourceFile;

      if (photo.localPath != null && photo.localPath!.isNotEmpty) {
        sourceFile = File(photo.localPath!);
      } else if (photo.networkUrl != null && photo.networkUrl!.isNotEmpty) {
        sourceFile = await _downloadNetworkImage(photo.networkUrl!);
      } else if (photo.bytes != null) {
        sourceFile = await _bytesToTempFile(photo.bytes!);
      }

      if (sourceFile == null) {
        if (mounted) PoppySnackbar.error(context, 'No photo to download');
        return;
      }

      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        if (mounted) PoppySnackbar.error(context, 'Cannot access downloads folder');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${downloadsDir.path}/poppy_photo_$timestamp.jpg';
      await sourceFile.copy(destPath);

      if (mounted) PoppySnackbar.success(context, 'Photo saved to downloads');
    } catch (e) {
      if (mounted) PoppySnackbar.error(context, 'Failed to download photo');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<File> _downloadNetworkImage(String url) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      return (await _bytesToTempFile(bytes));
    } finally {
      httpClient.close();
    }
  }

  Future<File> _bytesToTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/poppy_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
      final dirs = await getExternalStorageDirectories();
      return dirs?.first;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _confirmDelete() async {
    if (widget.onDelete == null) return;

    final confirmed = await PoppyDialog.showDestructive(
      context,
      title: 'Delete photo?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
    );

    if (confirmed != true) return;

    final deleteIndex = _currentIndex;
    widget.onDelete!(deleteIndex);

    if (mounted) {
      setState(() {
        _photos.removeAt(deleteIndex);
        final controller = _transformationControllers.removeAt(deleteIndex);
        controller.removeListener(_onTransformationChanged);
        controller.dispose();

        if (_photos.isEmpty) {
          Navigator.of(context).pop();
        } else {
          _currentIndex = _currentIndex.clamp(0, _photos.length - 1);
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      _resetZoom(_currentIndex);
    }
    setState(() => _currentIndex = index);
    _scheduleHideControls();
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.photoViewerBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleControls,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _photos.length,
                itemBuilder: (context, index) => _PhotoPage(
                  item: _photos[index],
                  transformationController: _transformationControllers[index],
                  onDoubleTapDown: (details) => _handleDoubleTap(details, index),
                ),
              ),
            ),
          ),
          _buildTopBar(),
          if (_isDownloading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _controlsOpacity,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xDD000000), Colors.transparent],
              stops: [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _ActionButton(
                    icon: AppIcons.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1} / ${_photos.length}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  _ActionButton(
                    icon: AppIcons.delete,
                    onPressed: _confirmDelete,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ActionButton(
                    icon: AppIcons.import,
                    isLoading: _isDownloading,
                    onPressed: _isDownloading ? null : _downloadPhoto,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
      ),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  final PhotoViewerItem item;
  final TransformationController transformationController;
  final void Function(TapDownDetails) onDoubleTapDown;

  const _PhotoPage({
    required this.item,
    required this.transformationController,
    required this.onDoubleTapDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: onDoubleTapDown,
      child: InteractiveViewer(
        transformationController: transformationController,
        minScale: _PhotoFullViewerState._minScale,
        maxScale: _PhotoFullViewerState._maxScale,
        panEnabled: true,
        scaleEnabled: true,
        child: Center(
          child: _buildImage(context),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (!item.hasImage) return const _PhotoErrorPlaceholder();

    if (item.bytes != null) {
      return Image.memory(
        item.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _PhotoErrorPlaceholder(),
      );
    }

    if (item.networkUrl != null && item.networkUrl!.isNotEmpty) {
      return Image.network(
        item.networkUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          if (item.localPath != null && item.localPath!.isNotEmpty) {
            return Image.file(
              File(item.localPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const _PhotoErrorPlaceholder(),
            );
          }
          return const _PhotoErrorPlaceholder();
        },
      );
    }

    if (item.localPath != null && item.localPath!.isNotEmpty) {
      return Image.file(
        File(item.localPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _PhotoErrorPlaceholder(),
      );
    }

    return const _PhotoErrorPlaceholder();
  }
}

class _PhotoErrorPlaceholder extends StatelessWidget {
  const _PhotoErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          AppIcons.imageBroken,
          color: Colors.white54,
          size: AppIconSize.xl,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Failed to load photo',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final Widget iconWidget = isLoading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: AppColors.white,
              strokeWidth: 2,
            ),
          )
        : Icon(
            icon,
            color: AppColors.white,
            size: AppIconSize.sm,
          );

    return Material(
      color: t.background.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: iconWidget,
        ),
      ),
    );
  }
}
