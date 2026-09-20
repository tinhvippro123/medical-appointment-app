# 🏥 Medical Appointment App

Ứng dụng Flutter đăng ký khám chữa bệnh với trung tâm y tế.

## 🛠️ Tech Stack

- **Framework:** Flutter 3.44+ (Dart)
- **Local Storage:** SQLite
- **State Management:** Provider / Riverpod
- **Architecture:** Feature-based Multi-Module + Clean Architecture

## 📁 Cấu Trúc Project

```
lib/
├── core/                          → Dùng chung (themes, network, widgets)
├── features/
│   ├── auth/                      → 👤 Xác thực (Thành viên A)
│   │   ├── data/                  → models, datasources, repositories
│   │   ├── domain/                → entities, usecases
│   │   └── presentation/          → screens, widgets, providers
│   ├── department/                → 🏢 Chuyên khoa (Thành viên B)
│   ├── doctor/                    → 👨‍⚕️ Bác sĩ (Thành viên C)
│   ├── booking/                   → 📅 Đặt lịch (Thành viên D)
│   ├── home/                      → 🏠 Trang chủ (Thành viên C)
│   └── profile/                   → 👤 Hồ sơ (Thành viên A)
└── main.dart
```

## 👥 Team Ownership

| Feature Module | Owner | Màn hình |
|----------------|-------|----------|
| core/ | Team Lead (A) | Shared components |
| features/auth/ | Thành viên A | Login, Register, Change Password |
| features/profile/ | Thành viên A | Profile, User Management |
| features/department/ | Thành viên B | Admin CRUD Chuyên khoa |
| features/doctor/ | Thành viên B + C | Admin CRUD (B), List & Detail (C) |
| features/home/ | Thành viên C | Trang chủ, Search, Filter |
| features/booking/ | Thành viên D | Booking, Cart, Checkout, History |

## 🚀 Getting Started

```bash
git clone <repository-url>
cd medical-appointment-app
flutter pub get
flutter run
```

## 📱 Màn Hình Chính

1. Splash Screen - Màn hình chào
2. Login / Register - Đăng nhập / Đăng ký
3. Home - Trang chủ (DS chuyên khoa, bác sĩ nổi bật)
4. Doctor List - Danh sách bác sĩ theo chuyên khoa
5. Doctor Detail - Chi tiết bác sĩ + lịch làm việc
6. Search - Tìm kiếm bác sĩ
7. Booking - Chọn ngày giờ khám
8. Cart - Giỏ hàng lịch hẹn
9. Checkout - Xác nhận đặt lịch
10. Appointment History - Lịch sử khám bệnh
11. Profile - Thông tin cá nhân
12. Admin Screens - Quản lý (chuyên khoa, bác sĩ, lịch hẹn)

## 🌿 Git Workflow

```
main → develop → feature/ten-chuc-nang
```
