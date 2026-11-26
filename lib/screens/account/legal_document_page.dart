import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<({String heading, String body})> sections;

  factory LegalDocumentPage.termsOfService() => const LegalDocumentPage(
    title: 'Điều khoản dịch vụ',
    sections: [
      (
        heading: '1. Phạm vi cung cấp dịch vụ',
        body:
            'Ứng dụng Y tế Hiệp Phước hỗ trợ người dân đăng ký tài khoản, quản lý hồ sơ sức khỏe và đặt lịch khám trực tuyến tại Trung tâm Y tế Xã Hiệp Phước.',
      ),
      (
        heading: '2. Trách nhiệm thông tin người bệnh',
        body:
            'Người dùng cam kết cung cấp chính xác họ tên, ngày sinh, số điện thoại và thông tin thẻ BHYT (nếu có) để phục vụ đối chiếu tại quầy tiếp nhận.',
      ),
      (
        heading: '3. Lịch hẹn và thanh toán',
        body:
            'Phiếu khám sau khi xác nhận sẽ được cấp số thứ tự dự kiến theo khung giờ làm việc của bác sĩ. Phí khám có thể thanh toán tại quầy hoặc trực tuyến qua VietQR / VNPay.',
      ),
    ],
  );

  factory LegalDocumentPage.privacyPolicy() => const LegalDocumentPage(
    title: 'Chính sách bảo mật',
    sections: [
      (
        heading: '1. Bảo mật dữ liệu y tế cá nhân',
        body:
            'Thông tin tài khoản, hồ sơ khám bệnh và lịch sử đặt khám của người dùng được mã hóa xác thực bằng JWT và chỉ phục vụ hoạt động khám chữa bệnh tại Trung tâm.',
      ),
      (
        heading: '2. Bảo vệ mật khẩu & mã xác thực',
        body:
            'Mật khẩu người dùng được băm một chiều bằng BCrypt. Mã OTP xác thực chỉ có hiệu lực trong 5 phút và tự hủy ngay sau khi sử dụng.',
      ),
      (
        heading: '3. Quyền kiểm soát thông tin',
        body:
            'Người dùng có toàn quyền xem, chỉnh sửa thông tin cá nhân, cập nhật hồ sơ người thân hoặc thay đổi mật khẩu bất kỳ lúc nào trong mục Cá nhân.',
      ),
    ],
  );

  factory LegalDocumentPage.usageRules() => const LegalDocumentPage(
    title: 'Quy định sử dụng',
    sections: [
      (
        heading: '1. Thời gian có mặt tại phòng khám',
        body:
            'Người bệnh vui lòng có mặt trước khung giờ đã đặt từ 15 phút để xuất trình mã QR phiếu khám tại quầy tiếp nhận.',
      ),
      (
        heading: '2. Thay đổi hoặc hủy lịch hẹn',
        body:
            'Trường hợp bận đột xuất, vui lòng thông báo sớm để nhường khung giờ khám cho bệnh nhân khác và không đặt trùng khung giờ trên cùng một hồ sơ.',
      ),
      (
        heading: '3. Quy tắc sử dụng tài khoản',
        body:
            'Không chia sẻ mật khẩu hoặc mã OTP cho người khác. Một tài khoản có thể tạo nhiều hồ sơ để đặt lịch khám hộ cha mẹ, con nhỏ trong gia đình.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xff0b57d0)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xff0b57d0),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = sections[index];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.heading,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
