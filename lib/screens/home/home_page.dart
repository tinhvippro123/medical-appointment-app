import 'package:flutter/material.dart';
import '../../core/widgets/reveal_content.dart';

import '../account/account_page.dart';
import '../booking/order_history_page.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/healthcare_functions_panel.dart';
import 'widgets/center_information.dart';
import 'widgets/app_bottom_navigation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int selected = 2;
  late final AnimationController tabAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  late final Animation<double> tabCurve = tabAnimation.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  late final Animation<Offset> tabSlide = Tween(
    begin: const Offset(0, .018),
    end: Offset.zero,
  ).animate(tabCurve);
  @override
  void dispose() {
    tabAnimation.dispose();
    super.dispose();
  }

  void selectTab(int value) {
    if (value == selected) return;
    setState(() => selected = value);
    if (MediaQuery.disableAnimationsOf(context)) {
      tabAnimation.value = 1;
    } else {
      tabAnimation.forward(from: 0);
    }
  }

  void open(String title, [IconData icon = Icons.medical_services_outlined]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FeaturePlaceholder(title: title, icon: icon),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: (selected == 2 || selected == 4)
        ? null
        : AppBar(title: Text(AppBottomNavigation.labels[selected])),
    body: SafeArea(
      top: false,
      child: FadeTransition(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1)
            : tabCurve,
        child: SlideTransition(
          position: MediaQuery.disableAnimationsOf(context)
              ? const AlwaysStoppedAnimation(Offset.zero)
              : tabSlide,
          child: IndexedStack(
            index: selected,
            children: [
              const FeatureMessage(
                title: 'Hóa đơn',
                icon: Icons.receipt_long_outlined,
              ),
              if (selected == 1)
                const OrderHistoryPage()
              else
                const SizedBox.shrink(),
              _home(),
              const FeatureMessage(
                title: 'Thông báo',
                icon: Icons.notifications_none_rounded,
              ),
              AccountPage(
                onOpenHistory: () => selectTab(1),
                onOpenBills: () => selectTab(0),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: AppBottomNavigation(
      selected: selected,
      onSelected: selectTab,
    ),
  );
  Widget _home() => SingleChildScrollView(
    key: const PageStorageKey('home-scroll'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeHeader(
          onNotifications: () =>
              open('Thông báo', Icons.notifications_none_rounded),
          onProfile: () => selectTab(4),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RevealContent(
                    child: HealthcareFunctionsPanel(
                      onSelected: (service) {
                        final title = service.title.replaceAll('\n', ' ');
                        if (title == 'Đặt khám') {
                          Navigator.of(context).pushNamed('/booking/patient');
                        } else if (title == 'Lịch sử đặt khám') {
                          selectTab(1);
                        } else if (title == 'Hồ sơ sức khỏe') {
                          Navigator.of(context).pushNamed('/patient-profiles');
                        } else {
                          open(title, service.icon);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const RevealContent(order: 1, child: HeroBanner()),
                  const RevealContent(order: 2, child: CenterInformation()),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
