import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:untitled1/widgets/cached_video_player.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const FullscreenMediaViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  bool _isPathVideo(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') || lowerUrl.contains('.mov') || lowerUrl.contains('.avi') || lowerUrl.contains('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("${_currentIndex + 1} / ${widget.urls.length}", style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final url = widget.urls[index];
          if (_isPathVideo(url)) {
            return Center(
              child: CachedVideoPlayer(
                url: url,
                play: true,
              ),
            );
          } else {
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
