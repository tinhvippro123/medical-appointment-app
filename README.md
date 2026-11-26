# Medical Appointment App

Ứng dụng Flutter đặt lịch khám bệnh cho bệnh nhân và quản trị phòng khám, kết nối REST API ASP.NET Core 10.

## Công nghệ sử dụng

- **Framework:** Flutter (Dart)
- **Kết nối API:** `http` qua `ApiClient` (JWT Bearer Token)
- **Lưu trữ cục bộ:** `shared_preferences`, `sqflite`
- **Đăng nhập bên thứ ba:** `google_sign_in`, `flutter_facebook_auth`
- **Thanh toán:** VNPay Sandbox, VietQR (`qr_flutter`)

## Cấu trúc thư mục

```text
lib/
├── config/         # Cấu hình baseUrl kết nối API
├── core/           # ApiClient, ApiException, theme, widget dùng chung & route guard
├── helpers/        # Validate form, JWT session helper, SQLite helper
├── models/         # Data models (Auth, Department, Doctor, Room, Order, PatientProfile...)
├── repositories/   # Các repository gọi API backend
├── screens/        # Giao diện theo từng phân hệ (auth, home, doctors, booking, cart, payment, account, admin...)
├── services/       # Social auth service (Google, Facebook)
└── main.dart       # Khởi tạo ứng dụng và định tuyến
```

## Chạy ứng dụng & Kiểm thử

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

> Lưu ý: Đảm bảo backend `medical-appointment-api` đang chạy (mặc định `http://localhost:5041`, hoặc truyền `--dart-define=API_BASE_URL=http://<IP>:5041` khi chạy trên điện thoại thật).
