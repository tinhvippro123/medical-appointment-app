import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/home_demo_data.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/healthcare_functions_panel.dart';
import 'widgets/featured_news.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void open(String title, [IconData icon = Icons.medical_services_outlined]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FeaturePlaceholder(title: title, icon: icon),
        ),
      );
  void announcement(Announcement item) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Thông báo')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              item.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(item.date, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            const Text(
              'Nội dung minh họa giao diện. Thông báo chính thức sẽ được cập nhật từ trung tâm y tế.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: SafeArea(top: false, child: _home()));
  Widget _home() => SingleChildScrollView(
    key: const PageStorageKey('home-scroll'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHeader(
          onNotifications: () =>
              open('Thông báo', Icons.notifications_none_rounded),
          onProfile: () => open('Hồ sơ cá nhân', Icons.account_circle_outlined),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HealthcareFunctionsPanel(
                    onSelected: (service) =>
                        open(service.title.replaceAll('\n', ' '), service.icon),
                  ),
                  const SizedBox(height: 20),
                  const HeroBanner(),
                  FeaturedNews(
                    onAll: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Tin tức nổi bật')),
                          body: ListView(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Nội dung minh họa'),
                              ),
                              for (final item in demoFeaturedNews)
                                ListTile(
                                  title: Text(item.title),
                                  subtitle: Text(item.date),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => announcement(item),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    onSelected: announcement,
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
