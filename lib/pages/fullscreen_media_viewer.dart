import 'package:flutter/material.dart';
import 'package:untitled1/widgets/cached_video_player.dart';
import 'package:untitled1/widgets/zoomable_image_viewer.dart';

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
  bool _showChrome = true;

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
      body: Stack(
        children: [
          PageView.builder(
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
                    fit: BoxFit.contain,
                  ),
                );
              } else {
                return ZoomableImageViewer(
                  imageUrl: url,
                  enableHero: true,
                  heroTag: url,
                  enableSwipeDismiss: true,
                  onTap: () => setState(() => _showChrome = !_showChrome),
                );
              }
            },
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            top: _showChrome ? 0 : -110,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _ChromeButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        "${_currentIndex + 1} / ${widget.urls.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ChromeButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
