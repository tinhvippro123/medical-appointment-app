import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../booking_logic.dart';

/// Lưới chip chọn khung giờ khám 1 giờ theo ngày đã chọn
class BookingSlotGrid extends StatelessWidget {
  const BookingSlotGrid({
    super.key,
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
    required this.emptyMessage,
    this.enabled = true,
  });

  final List<BookingTimeSlot> slots;
  final String? selectedSlot;
  final ValueChanged<String> onSlotSelected;
  final String emptyMessage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffe2e8f0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 32,
              color: AppColors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((slot) {
        final isSelected = selectedSlot == slot.label;
        return ChoiceChip(
          label: Text(slot.label),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected ? AppColors.primary : const Color(0xffcbd5e1),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          labelStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.text,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          onSelected: enabled ? (_) => onSlotSelected(slot.label) : null,
        );
      }).toList(),
    );
  }
}
