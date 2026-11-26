# 📱 Medical Appointment App

Ứng dụng Flutter đăng ký khám chữa bệnh với trung tâm y tế.

## 📚 Tài liệu

| Tài liệu | Mô tả |
|-----------|-------|
| [Kiến trúc dự án](docs/ARCHITECTURE.md) | Giải thích Clean Architecture, cấu trúc feature |
| [Hướng dẫn Commit và PR](docs/CONTRIBUTING.md) | Quy trình commit, đặt tên branch, tạo Pull Request |

## 🛠️ Tech Stack

- **Framework:** Flutter 3.44+ (Dart)
- **Local Storage:** SQLite
- **State Management:** Provider / Riverpod
- **Architecture:** Feature-based Multi-Module + Clean Architecture

## 📁 Cấu Trúc Project

```
lib/
├ core/                          → Dùng chung (themes, network, widgets)
├ features/
│   ├ auth/                      → 🔐 Xác thực (Tính)
│   │   ├ data/                  → models, datasources, repositories
│   │   ├ domain/                → entities, usecases
│   │   └ presentation/          → screens, widgets, providers
│   ├ department/                → 🏥 Chuyên khoa (Triết)
│   ├ doctor/                    → 🩺 Bác sĩ (Thịnh)
│   ├ booking/                   → 📅 Đặt lịch (Thuận)
│   ├ home/                      → 🏠 Trang chủ (Thịnh)
│   └ profile/                   → 👤 Hồ sơ (Tính)
└ main.dart
```

## 👥 Nhóm phát triển

| Feature Module | Thành viên | Màn hình |
|----------------|-----------|----------|
| core/ | Tính (Team Lead) | Shared components |
| features/auth/ | Tính | Login, Register, Đổi mật khẩu |
| features/profile/ | Tính | Profile, Quản lý User |
| features/department/ | Triết | Admin CRUD Chuyên khoa |
| features/doctor/ | Triết + Thịnh | Admin CRUD (Triết), Danh sách & Chi tiết (Thịnh) |
| features/home/ | Thịnh | Trang chủ, Tìm kiếm |
| features/booking/ | Thuận | Đặt lịch, Giỏ hàng, Checkout, Lịch sử |

## 🚀 Chạy project

```bash
git clone https://github.com/tinhvippro123/medical-appointment-app.git
cd medical-appointment-app
git checkout develop
flutter pub get
flutter run
```

## 📱 Màn Hình Chính

1. Splash Screen — Màn hình chào
2. Login / Register — Đăng nhập / Đăng ký
3. Home — Trang chủ (DS chuyên khoa, bác sĩ nổi bật)
4. Doctor List — Danh sách bác sĩ theo chuyên khoa
5. Doctor Detail — Chi tiết bác sĩ + lịch làm việc
6. Search — Tìm kiếm bác sĩ
7. Booking — Chọn ngày giờ khám
8. Cart — Giỏ hàng lịch hẹn
9. Checkout — Xác nhận đặt lịch
10. Appointment History — Lịch sử khám bệnh
11. Profile — Thông tin cá nhân
12. Admin Screens — Quản lý (chuyên khoa, bác sĩ, lịch hẹn)

## 🌿 Git Workflow

```
main → develop → feature/tên-chức-năng
```
## Trang chủ Y tế Hiệp Phước

Chạy `flutter pub get`, sau đó `flutter run`. Home dùng dữ liệu cục bộ, không
cần API. Có 6 chức năng: Đặt khám, Lịch sử đặt khám, Hóa đơn, Hồ sơ sức khỏe,
Lắng nghe khách hàng, Hướng dẫn sử dụng. Các chức năng nghiệp vụ hiện mở
màn hình chờ phát triển. Header và thanh điều hướng hiện tại được giữ lại.

Icon dịch vụ dùng ảnh minh họa pastel trong ô vuông bo góc, nhãn màu xanh đậm.
Các file nằm tại `assets/images/services/`. Banner ảnh tòa nhà bo góc, tỷ lệ
2.55:1, không phủ chữ, dùng `assets/images/health_center_banner.png`.
Các ảnh được đóng gói trong app, không tải online; không thêm dependency.
Ảnh khuôn viên là minh họa tạo mới, không phải ảnh cơ sở Hiệp Phước thực tế.
Thông tin prompt và nguồn tạo lưu trong `assets/images/ARTWORK.md`.

Home hiện dùng dữ liệu cục bộ, chưa gọi API.

Kiểm tra bằng `flutter analyze` và `flutter test`.

Nút sắp xếp mở trang riêng: nhấn giữ và kéo thả 6 chức năng, Cài đặt lại để
khôi phục mặc định, Lưu thay đổi để áp dụng và lưu vào shared_preferences.
Quay lại khi chưa lưu không thay đổi Home. Lockfile giữ plugin Apple
shared_preferences_foundation 2.5.0 tương thích để widget tests Windows không
phụ thuộc compiler Objective-C/native assets của bản 2.6.0.

## Admin: Quản lý chuyên khoa

Màn riêng tại route `/admin/departments`. Mở bằng
`Navigator.pushNamed(context, '/admin/departments')` từ menu admin khi tích hợp
phân quyền. Để kiểm tra giao diện trực tiếp:

```bash
flutter run --route=/admin/departments --dart-define=API_BASE_URL=http://192.168.1.10:5041
```

Thay địa chỉ bằng API truy cập được từ thiết bị. Android emulator mặc định
`http://10.0.2.2:5041`; web/desktop mặc định localhost:5041. Header Bearer lấy
token từ SessionHepler nếu có. Route chưa được gắn vào menu bệnh nhân;
phân quyền admin cần được tích hợp với luồng đăng nhập và bảo vệ ở server.

Danh sách gọi GET /api/departments; form dùng POST/PUT; ảnh JPG/PNG tối đa
5 MB gửi multipart field `file` tới POST /api/departments/{id}/image.
DELETE /api/departments/{id} xử lý mã DEPARTMENT_HAS_DOCTORS bằng SnackBar.
Nếu thông tin đã lưu nhưng ảnh lỗi, form giữ ID vừa tạo và ảnh đã chọn để
thử lại, không tạo trùng chuyên khoa. Quay lại lúc này sẽ tải lại danh sách.

Thêm image_picker cho thư viện/camera và khai báo quyền sử dụng ảnh/camera iOS.
Máy ảnh thật và API/database cần kiểm tra tích hợp trên thiết bị.
