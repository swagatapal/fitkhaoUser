import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';

/// In-app viewer for a remote medical-record document.
///
/// Images render with an [InteractiveViewer] so they fit the screen first and
/// pinch/double-tap to zoom on demand. PDFs load in a WebView wrapped by
/// Google's document viewer (the platform WebView can't render a raw PDF
/// inline). An "open externally" action is always available as a fallback.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.url,
    this.title = 'Document',
    this.isPdf = false,
  });

  final String url;
  final String title;
  final bool isPdf;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  // WebView is only used for PDFs.
  WebViewController? _controller;

  int _progress = 0;
  bool _hasError = false;
  int _imageReloads = 0; // bumped to force an image refetch after an error

  /// Google's viewer renders a PDF that the platform WebView can't show inline.
  String get _pdfViewerUrl {
    final encoded = Uri.encodeComponent(widget.url);
    return 'https://docs.google.com/viewer?embedded=true&url=$encoded';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isPdf) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
            onPageStarted: (_) {
              if (mounted) setState(() => _hasError = false);
            },
            onWebResourceError: (error) {
              // Only surface main-frame failures, not subframe/resource ones.
              if (error.isForMainFrame == false) return;
              if (mounted) setState(() => _hasError = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(_pdfViewerUrl));
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open this document.'),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _reloadPdf() {
    setState(() => _hasError = false);
    _controller?.loadRequest(Uri.parse(_pdfViewerUrl));
  }

  Future<void> _reloadImage() async {
    await NetworkImage(widget.url).evict();
    if (mounted) setState(() => _imageReloads++);
  }

  @override
  Widget build(BuildContext context) {
    // Only the WebView (PDF) path drives the top progress bar.
    final loading = widget.isPdf && _progress < 100 && !_hasError;

    return Scaffold(
      backgroundColor: widget.isPdf ? Colors.white : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppTypography.fontSize16,
            fontWeight: AppTypography.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Lato',
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open externally',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openExternally,
          ),
        ],
        bottom: loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  backgroundColor: AppColors.borderColor.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primaryGreen),
                ),
              )
            : null,
      ),
      body: widget.isPdf ? _buildPdfBody() : _buildImageBody(),
    );
  }

  Widget _buildPdfBody() {
    if (_hasError) {
      return _ErrorView(onRetry: _reloadPdf, onOpenExternally: _openExternally);
    }
    return WebViewWidget(controller: _controller!);
  }

  Widget _buildImageBody() {
    return _ZoomableImage(
      key: ValueKey(_imageReloads),
      url: widget.url,
      onError: _reloadImage,
      onOpenExternally: _openExternally,
    );
  }
}

/// An image that fits the viewport initially and supports pinch + double-tap
/// zoom via [InteractiveViewer].
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    super.key,
    required this.url,
    required this.onError,
    required this.onOpenExternally,
  });

  final String url;
  final VoidCallback onError;
  final VoidCallback onOpenExternally;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _animation;

  static const double _minScale = 1.0;
  static const double _maxScale = 5.0;

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Double-tap toggles between fit (1x) and a 2.5x zoom centred on the tap.
  void _handleDoubleTap(TapDownDetails details) {
    final current = _controller.value.getMaxScaleOnAxis();
    final Matrix4 target;
    if (current > _minScale + 0.01) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      final pos = details.localPosition;
      target = Matrix4.identity()
        ..translateByDouble(-pos.dx * (scale - 1), -pos.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
    }
    _animateTo(target);
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    )..addListener(() {
        _controller.value = _animation!.value;
      });
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      // The empty onDoubleTap keeps the recognizer active for onDoubleTapDown.
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: _minScale,
        maxScale: _maxScale,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        clipBehavior: Clip.none,
        child: SizedBox.expand(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: AppColors.primaryGreen,
                ),
              );
            },
            errorBuilder: (_, __, ___) => _ErrorView(
              dark: true,
              onRetry: widget.onError,
              onOpenExternally: widget.onOpenExternally,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.onRetry,
    required this.onOpenExternally,
    this.dark = false,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenExternally;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white70 : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 44, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(height: AppSizes.spacing12),
            Text(
              "Couldn't load this document.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.fontSize14,
                color: textColor,
                fontFamily: 'Lato',
              ),
            ),
            const SizedBox(height: AppSizes.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry',
                      style: TextStyle(
                          fontFamily: 'Lato', color: AppColors.primaryGreen)),
                ),
                const SizedBox(width: AppSizes.spacing8),
                TextButton(
                  onPressed: onOpenExternally,
                  child: const Text('Open externally',
                      style: TextStyle(
                          fontFamily: 'Lato', color: AppColors.primaryGreen)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
