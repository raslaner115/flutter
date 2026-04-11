import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ZoomableImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? localPath;
  final bool enableHero;
  final String? heroTag;
  final bool enableSwipeDismiss;
  final VoidCallback? onTap;

  const ZoomableImageViewer({
    super.key,
    required this.imageUrl,
    this.localPath,
    this.enableHero = false,
    this.heroTag,
    this.enableSwipeDismiss = false,
    this.onTap,
  });

  @override
  State<ZoomableImageViewer> createState() => _ZoomableImageViewerState();
}

class _ZoomableImageViewerState extends State<ZoomableImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 1;
  static const double _maxScale = 4;
  static const double _doubleTapScale = 2.6;

  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  AnimationController? _animationController;

  Animation<Matrix4>? _zoomAnimation;
  bool _isZoomed = false;
  double _verticalDragOffset = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final animation = _zoomAnimation;
        if (animation == null) return;
        _transformationController.value = animation.value;
      });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    final controller = _animationController;
    if (controller == null) {
      _transformationController.value = target;
      return;
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    controller
      ..stop()
      ..reset()
      ..forward();
  }

  void _handleDoubleTap(Size viewportSize) {
    final tapPosition = _doubleTapDetails?.localPosition;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    if (tapPosition == null || currentScale > 1.05) {
      _animateTo(Matrix4.identity());
      setState(() => _isZoomed = false);
      return;
    }

    final scenePoint = _transformationController.toScene(tapPosition);
    final dx = viewportSize.width / 2 - (scenePoint.dx * _doubleTapScale);
    final dy = viewportSize.height / 2 - (scenePoint.dy * _doubleTapScale);

    final zoomedMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(_doubleTapScale);

    _animateTo(zoomedMatrix);
    setState(() => _isZoomed = true);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();

    if (scale <= 1.02) {
      _transformationController.value = Matrix4.identity();
      if (mounted) {
        setState(() => _isZoomed = false);
      }
      return;
    }

    if (scale > _maxScale) {
      final clampedMatrix = Matrix4.copy(_transformationController.value)
        ..scale(_maxScale / scale);
      _animateTo(clampedMatrix);
      if (mounted) {
        setState(() => _isZoomed = true);
      }
      return;
    }

    if (mounted) {
      setState(() => _isZoomed = scale > 1.02);
    }
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final nextZoomed = scale > 1.02;
    if (nextZoomed != _isZoomed && mounted) {
      setState(() => _isZoomed = nextZoomed);
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.enableSwipeDismiss || _isZoomed) return;

    setState(() {
      _verticalDragOffset += details.delta.dy;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!widget.enableSwipeDismiss || _isZoomed) return;

    final shouldDismiss = _verticalDragOffset.abs() > 120;
    if (shouldDismiss) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _verticalDragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = widget.localPath != null && widget.localPath!.isNotEmpty;
    final dragOpacity = widget.enableSwipeDismiss
        ? (1 - (_verticalDragOffset.abs() / 320)).clamp(0.55, 1.0)
        : 1.0;
    final dragScale = widget.enableSwipeDismiss && !_isZoomed
        ? (1 - (_verticalDragOffset.abs() / 1800)).clamp(0.92, 1.0)
        : 1.0;

    Widget image = hasLocal
        ? Image.file(
            File(widget.localPath!),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          )
        : CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (context, _) => const _ImageLoadingPlaceholder(),
            errorWidget: (context, _, __) => const _ImageErrorPlaceholder(),
          );

    if (widget.enableHero) {
      image = Hero(tag: widget.heroTag ?? widget.imageUrl, child: image);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTap: () => _handleDoubleTap(viewportSize),
          onVerticalDragUpdate: _handleVerticalDragUpdate,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            color: Colors.black.withOpacity(dragOpacity),
            child: Transform.translate(
              offset: Offset(0, _verticalDragOffset),
              child: Transform.scale(
                scale: dragScale,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  panEnabled: true,
                  scaleEnabled: true,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(1000),
                  clipBehavior: Clip.none,
                  onInteractionUpdate: _handleInteractionUpdate,
                  onInteractionEnd: _handleInteractionEnd,
                  child: SizedBox(
                    width: viewportSize.width,
                    height: viewportSize.height,
                    child: Center(child: image),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      ),
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, color: Colors.white70, size: 52),
          SizedBox(height: 10),
          Text(
            'Unable to load image',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
