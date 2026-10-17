import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  static const labels = [
    'Trang chủ',
    'Lịch hẹn',
    'Mã khám',
    'Sức khỏe',
    'Tin tức',
  ];
  static const icons = [
    Icons.home_rounded,
    Icons.calendar_month_outlined,
    Icons.qr_code_rounded,
    Icons.monitor_heart_outlined,
    Icons.feed_outlined,
  ];
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: AppColors.dark.withValues(alpha: .07),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
            5,
            (index) => Expanded(
              child: Semantics(
                selected: selected == index,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index == 2)
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xffe3f0ff),
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: .25,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.qr_code_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          )
                        else
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected == index
                                  ? AppColors.light
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              icons[index],
                              color: selected == index
                                  ? AppColors.primary
                                  : AppColors.muted,
                              size: 25,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected == index
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
