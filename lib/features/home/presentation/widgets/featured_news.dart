import 'package:flutter/material.dart';
import '../../data/home_demo_data.dart';

class FeaturedNews extends StatefulWidget {
  const FeaturedNews({
    super.key,
    required this.onAll,
    required this.onSelected,
  });
  final VoidCallback onAll;
  final ValueChanged<Announcement> onSelected;
  @override
  State<FeaturedNews> createState() => _FeaturedNewsState();
}

class _FeaturedNewsState extends State<FeaturedNews> {
  final controller = PageController();
  int current = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = (demoFeaturedNews.length + 1) ~/ 2;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final cardHeight = 108.0 + (scale - 1).clamp(0.0, 4.0) * 82;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tin tức nổi bật',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onAll,
                child: const Text(
                  'Xem thêm',
                  style: TextStyle(color: Color(0xff125bb5)),
                ),
              ),
            ],
          ),
          const Text(
            'Nội dung minh họa',
            style: TextStyle(fontSize: 10, color: Color(0xff64748b)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight * 2 + 12,
            child: PageView.builder(
              controller: controller,
              itemCount: pageCount,
              onPageChanged: (index) => setState(() => current = index),
              itemBuilder: (context, page) => Column(
                children: [
                  for (var offset = 0; offset < 2; offset++) ...[
                    if (offset > 0) const SizedBox(height: 12),
                    if (page * 2 + offset < demoFeaturedNews.length)
                      SizedBox(
                        height: cardHeight,
                        child: _NewsCard(
                          item: demoFeaturedNews[page * 2 + offset],
                          index: page * 2 + offset,
                          onTap: () => widget.onSelected(
                            demoFeaturedNews[page * 2 + offset],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (index) => Semantics(
                button: true,
                selected: current == index,
                label: 'Trang tin ${index + 1}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => controller.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 6,
                      width: current == index ? 20 : 5,
                      decoration: BoxDecoration(
                        color: current == index
                            ? const Color(0xff125bd5)
                            : const Color(0xffd0d3d7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.index,
    required this.onTap,
  });
  final Announcement item;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsets.only(right: 10),
              color: const Color(0xff125bd5),
            ),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 78,
                  child: index.isOdd
                      ? Image.asset(
                          'assets/images/health_center_banner.png',
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        )
                      : ColoredBox(
                          color: const Color(0xffeaf7fc),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              index == 0
                                  ? 'assets/images/services/guide.png'
                                  : 'assets/images/services/health.png',
                              fit: BoxFit.contain,
                              cacheWidth: 256,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Text(
                item.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xff125bb5), size: 22),
          ],
        ),
      ),
    ),
  );
}
