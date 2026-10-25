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
    'Lịch sử khám',
    'Hóa đơn',
    'Trang chủ',
    'Thông báo',
    'Tài khoản',
  ];
  static const icons = [
    Icons.history_rounded,
    Icons.receipt_long_outlined,
    Icons.home_rounded,
    Icons.notifications_none_rounded,
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppColors.dark.withValues(alpha: .08),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
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
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xff289afa),
                                                  Color(0xff1465db),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 4,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(
                                                        alpha: active
                                                            ? .25
                                                            : .08,
                                                      ),
                                                  blurRadius: active ? 14 : 4,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
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
