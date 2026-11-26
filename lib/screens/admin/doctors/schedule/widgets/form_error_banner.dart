import 'package:flutter/material.dart';

/// Khung hiển thị thông báo lỗi trả về từ backend ngay trong biểu mẫu
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffef2f2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xfffecaca)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xffdc2626),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xffb91c1c),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
