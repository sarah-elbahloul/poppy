import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/models/entry.dart';
import 'package:poppy/models/photo.dart';
import 'package:poppy/providers/entries_provider.dart';
import 'package:poppy/services/photos_service.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Entry Detail Screen
//  Location: lib/screens/entry_detail/entry_detail_screen.dart
//
//  Read-only view of a single diary entry.
//  Photos shown in a separate section below the text.
//  Edit button in the app bar opens WriteScreen.
// ─────────────────────────────────────────────────────────────

class EntryDetailScreen extends StatefulWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final _photosService = PhotosService();
  List<Photo> _photos = [];
  bool _loadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    try {
      final photos = await _photosService.fetchForEntry(widget.entryId);
      if (mounted) setState(() => _photos = photos);
    } finally {
      if (mounted) setState(() => _loadingPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final entry = context.watch<EntriesProvider>().getById(widget.entryId);

    // Entry not found — go back
    if (entry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: t.background,
      appBar: _buildAppBar(context, t, entry),
      body: _buildBody(context, t, entry),
    );
  }

  // ── App bar ───────────────────────────────────────────────

  AppBar _buildAppBar(
      BuildContext context,
      PoppyThemeExtension t,
      Entry entry,
      ) {
    return AppBar(
      backgroundColor: t.background,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.textSecondary),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          // Color tag strip indicator
          Container(
            width: kColorStripWidth,
            height: 16,
            decoration: BoxDecoration(
              color: entry.colorTag.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: kSpaceSM),
          Text(
            DateFormat('MMMM d, yyyy').format(entry.createdAt),
            style: TextStyle(
              fontSize: 14,
              color: t.textTertiary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        // Edit button
        IconButton(
          icon: Icon(Icons.edit_outlined, size: 20, color: t.textSecondary),
          onPressed: () =>
              context.push('/write?entryId=${entry.id}'),
          tooltip: 'Edit entry',
        ),
        const SizedBox(width: kSpaceXS),
      ],
    );
  }

  // ── Body ──────────────────────────────────────────────────

  Widget _buildBody(
      BuildContext context,
      PoppyThemeExtension t,
      Entry entry,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: kSpaceXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpaceLG, kSpaceLG, kSpaceLG, kSpaceXS,
            ),
            child: Text(
              entry.title.isEmpty ? 'Untitled' : entry.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: entry.title.isEmpty ? t.textTertiary : t.textPrimary,
                letterSpacing: -0.4,
                height: 1.3,
              ),
            ),
          ),

          // ── Meta row: time + word count ───────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
            child: Row(
              children: [
                Text(
                  DateFormat('h:mm a').format(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: t.textTertiary),
                ),
                const SizedBox(width: kSpaceMD),
                Text(
                  '${entry.wordCount} words',
                  style: TextStyle(fontSize: 12, color: t.textTertiary),
                ),
              ],
            ),
          ),

          Divider(
            height: kSpaceLG * 1.5,
            thickness: 0.5,
            color: t.border,
            indent: kSpaceLG,
            endIndent: kSpaceLG,
          ),

          // ── Content ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
            child: SelectableText(
              entry.content.isEmpty
                  ? 'No content.'
                  : entry.content,
              style: TextStyle(
                fontSize: 15,
                color: entry.content.isEmpty
                    ? t.textTertiary
                    : t.textSecondary,
                height: 1.8,
              ),
            ),
          ),

          // ── Photos section ────────────────────────────────
          if (_loadingPhotos) ...[
            const SizedBox(height: kSpaceLG),
            Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.textTertiary,
                ),
              ),
            ),
          ] else if (_photos.isNotEmpty) ...[
            const SizedBox(height: kSpaceXL),
            Padding(
              padding: const EdgeInsets.only(
                left: kSpaceLG,
                bottom: kSpaceSM,
              ),
              child: Text(
                'Photos',
                style: TextStyle(
                  fontSize: 11,
                  color: t.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Divider(height: 0.5, thickness: 0.5, color: t.border),
            const SizedBox(height: kSpaceMD),
            _PhotoGrid(photos: _photos),
          ],
        ],
      ),
    );
  }
}

// ── Photo grid ─────────────────────────────────────────────────
// Shows photos in a 3-column grid, each tappable to fullscreen.

class _PhotoGrid extends StatelessWidget {
  final List<Photo> photos;

  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: kSpaceSM,
          mainAxisSpacing: kSpaceSM,
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) {
          final photo = photos[i];
          return GestureDetector(
            onTap: () => _openFullscreen(context, i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadiusSM),
              child: photo.signedUrl != null
                  ? CachedNetworkImage(
                imageUrl: photo.signedUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: t.surface),
                errorWidget: (_, __, ___) => Container(
                  color: t.surface,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: t.textTertiary,
                  ),
                ),
              )
                  : Container(color: t.surface),
            ),
          );
        },
      ),
    );
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ── Fullscreen photo viewer ────────────────────────────────────

class _FullscreenPhotoViewer extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;

  const _FullscreenPhotoViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final photo = widget.photos[i];
          return InteractiveViewer(
            child: Center(
              child: photo.signedUrl != null
                  ? CachedNetworkImage(
                imageUrl: photo.signedUrl!,
                fit: BoxFit.contain,
              )
                  : const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          );
        },
      ),
    );
  }
}