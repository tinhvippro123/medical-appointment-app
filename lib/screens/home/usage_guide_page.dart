import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class UsageGuidePage extends StatelessWidget {
  const UsageGuidePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hướng dẫn sử dụng')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _GuideSection(
                icon: Icons.badge_outlined,
                title: 'Tạo hồ sơ bệnh nhân',
                text:
                    '1. Mở tab Hồ sơ bệnh nhân và bấm nút +.\n'
                    '2. Nhập thông tin của bạn hoặc người thân rồi bấm Lưu hồ sơ.\n'
                    '3. Khi cần sửa, bấm vào hồ sơ đã lưu.',
              ),
              const _GuideSection(
                icon: Icons.calendar_month_outlined,
                title: 'Đặt lịch khám',
                text:
                    '1. Từ Trang chủ, chọn Đặt khám và chọn người đi khám.\n'
                    '2. Chọn chuyên khoa, ngày khám, bác sĩ và giờ khám.\n'
                    '3. Kiểm tra thông tin lịch hẹn.\n'
                    '4. Bấm Tiếp tục thanh toán.',
              ),
              const _GuideSection(
                icon: Icons.payments_outlined,
                title: 'Xác nhận và thanh toán',
                text:
                    'Chọn phương thức rồi bấm Xác nhận đặt lịch. '
                    'Nếu chọn Tiền mặt tại quầy, bạn trả phí khi đến trung tâm. '
                    'Nếu chọn VNPay hoặc VietQR, app mở màn thanh toán tương ứng.',
              ),
              const _GuideSection(
                icon: Icons.qr_code_2,
                title: 'Xem lịch khám và mã QR',
                text:
                    'Mở tab Lịch sử khám, chọn lịch đã đặt để xem ngày giờ, '
                    'phòng khám và số thứ tự. Bấm Mã QR để mở mã lịch khám.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/booking/patient'),
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text('Đặt khám ngay'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedAlignment: Alignment.centerLeft,
      children: [Text(text, style: const TextStyle(height: 1.5))],
    ),
  );
}
