import 'package:flutter/material.dart';

// Nội dung minh họa, chưa kết nối nguồn thông báo chính thức.
class Announcement {
  const Announcement(this.title, this.date, this.icon, this.color);
  final String title, date;
  final IconData icon;
  final Color color;
}

const demoAnnouncements = [
  Announcement(
    'Thông báo tiêm chủng mở rộng tháng 10/2026',
    '15/10/2026',
    Icons.vaccines_outlined,
    Color(0xff10b69c),
  ),
  Announcement(
    'Tăng cường phòng chống sốt xuất huyết trong mùa mưa',
    '12/10/2026',
    Icons.health_and_safety_outlined,
    Color(0xff1677e8),
  ),
];

class HealthService {
  const HealthService(this.title, this.icon, this.color, this.asset);
  final String title, asset;
  final IconData icon;
  final Color color;
}

const homeServices = [
  HealthService(
    'Đặt khám',
    Icons.calendar_month_outlined,
    Color(0xff1677e8),
    'assets/images/services/booking.png',
  ),
  HealthService(
    'Lịch sử\nđặt khám',
    Icons.history_rounded,
    Color(0xff10b69c),
    'assets/images/services/history.png',
  ),
  HealthService(
    'Hóa đơn',
    Icons.receipt_long_outlined,
    Color(0xfff45454),
    'assets/images/services/invoice.png',
  ),
  HealthService(
    'Hồ sơ\nsức khỏe',
    Icons.folder_shared_outlined,
    Color(0xff7755f5),
    'assets/images/services/health.png',
  ),
  HealthService(
    'Lắng nghe\nkhách hàng',
    Icons.support_agent_outlined,
    Color(0xffff7a32),
    'assets/images/services/support.png',
  ),
  HealthService(
    'Hướng dẫn\nsử dụng',
    Icons.menu_book_outlined,
    Color(0xff1677e8),
    'assets/images/services/guide.png',
  ),
];
// Dữ liệu mẫu cho giao diện, chưa phải tin chính thức của trung tâm.
const demoFeaturedNews = [
  Announcement(
    'Cùng tham gia cuộc thi tìm hiểu quy định pháp luật về phòng, chống tác hại của thuốc lá',
    '18/10/2026',
    Icons.campaign_outlined,
    Color(0xff1677e8),
  ),
  Announcement(
    'Thông báo về việc tìm chủ sở hữu của tài sản do người bệnh, thân nhân để quên',
    '17/10/2026',
    Icons.article_outlined,
    Color(0xff1677e8),
  ),
  ...demoAnnouncements,
];
