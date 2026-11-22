import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

/// One featured message in the banner.
class AnnouncementSlide {
  const AnnouncementSlide({
    required this.category,
    required this.title,
    required this.icon,
    this.description = '',
    this.cta,
    this.onTap,
  });

  final String category;
  final String title;
  final String description;
  final IconData icon;
  final String? cta;
  final VoidCallback? onTap;
}

/// Featured banner: swipeable slides with indicators, advancing on a timer.
class AnnouncementCarousel extends StatefulWidget {
  const AnnouncementCarousel({super.key, required this.slides});

  final List<AnnouncementSlide> slides;

  @override
  State<AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<AnnouncementCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.slides.length < 2 || !_controller.hasClients) {
        return;
      }
      _controller.animateToPage(
        (_page + 1) % widget.slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant AnnouncementCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Slides can disappear after a refresh.
    if (_page >= widget.slides.length) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();
    // Grows with the user's font size so the text is never clipped.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

    return SizedBox(
      height: 210 * scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Lx.rSection),
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _SlideView(slides[i]),
            ),
            if (slides.length > 1)
              Positioned(
                right: Lx.s20,
                bottom: Lx.s16,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(left: 6),
                          width: i == _page ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView(this.slide);

  final AnnouncementSlide slide;

  @override
  Widget build(BuildContext context) {
    final s = slide;
    return LayoutBuilder(builder: (context, c) {
      // The illustration keeps to the right third; text never runs under it.
      final art = (c.maxWidth * 0.3).clamp(72.0, 120.0);
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Lx.bannerStart, Lx.skyBlue],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -art * 0.25,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: art * 1.5,
                  height: art * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.14),
                  ),
                  child: Icon(s.icon, size: art * 0.8, color: Colors.white),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  Lx.s20, Lx.s12, art * 1.25 + Lx.s8, Lx.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCD34D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_outline_rounded,
                            size: 15, color: Lx.primaryDark),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            s.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lx.metadata.copyWith(
                                color: Lx.primaryDark,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Lx.s8),
                  Flexible(
                    child: Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Lx.sectionHeading.copyWith(color: Colors.white),
                    ),
                  ),
                  if (s.description.isNotEmpty) ...[
                    const SizedBox(height: Lx.s4),
                    Text(
                      s.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Lx.body.copyWith(
                          color: Colors.white.withOpacity(0.92), height: 1.35),
                    ),
                  ],
                  if (s.cta != null) ...[
                    const SizedBox(height: Lx.s12),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: s.onTap,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  s.cta!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Lx.button.copyWith(color: Lx.primaryDark),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 18, color: Lx.primaryDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
