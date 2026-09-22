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