import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  static const labels = [
    'Đặt khám',
    'Lịch sử khám',
    'Trang chủ',
    'Hồ sơ bệnh nhân',
    'Tài khoản',
  ];
  static const icons = [
    Icons.calendar_month_outlined,
    Icons.history_rounded,
    Icons.home_rounded,
    Icons.badge_outlined,
    Icons.person_outline_rounded,
  ];
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xffe2eaf3))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(labels.length, (index) {
                final active = selected == index;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: labels[index],
                    child: InkWell(
                      key: ValueKey('bottom-nav-$index'),
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 48,
                              child: Center(
                                child: AnimatedScale(
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  scale: active ? 1.08 : 1,
                                  child: index == 2
                                      ? Transform.translate(
                                          offset: const Offset(0, -14),
                                          child: AnimatedContainer(
                                            duration: duration,
                                            width: 62,
                                            height: 62,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 4,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.home_rounded,
                                              size: 29,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : AnimatedContainer(
                                          duration: duration,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? AppColors.light
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            icons[index],
                                            size: 25,
                                            color: active
                                                ? AppColors.primary
                                                : const Color(0xff7187a4),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            AnimatedDefaultTextStyle(
                              duration: duration,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.25,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: active
                                    ? AppColors.primary
                                    : const Color(0xff7187a4),
                              ),
                              child: Text(
                                labels[index],
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
