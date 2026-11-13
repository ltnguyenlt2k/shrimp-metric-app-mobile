# Phát triển ShrimpMetric

## Toolchain

Baseline dùng Flutter 3.50.0, JDK 17 và Android SDK 36. Cài Flutter và các thành phần Android theo hướng dẫn chính thức. Dùng cùng một môi trường để chạy Flutter, Java và Android SDK. [Thiết lập Android](https://docs.flutter.dev/platform-integration/android/setup)

Trong WSL của workspace này, bộ công cụ nằm dưới `~/.local/share/shrimpmetric`. Nạp môi trường ở đầu mỗi terminal:

```bash
source "$HOME/.local/share/shrimpmetric/env.sh"
flutter doctor -v
flutter devices
```

Để dùng Android Emulator trên Windows, cấu hình Flutter/Android SDK trên Windows và chạy lệnh Flutter trong PowerShell. Nếu dùng emulator Linux trong WSL, kiểm tra quyền truy cập và tăng tốc bằng `emulator -accel-check`. Thiết bị Android thật dùng để kiểm chứng camera và hiệu năng.

## Chạy từ thư mục repo

```text
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

Mở repo trong phiên Codex hoặc Claude Code. Dùng `$shrimpmetric-mobile` trong Codex hoặc `/shrimpmetric-mobile` trong Claude Code. Nội dung skill dùng chung nằm ở `.agents/skills/shrimpmetric-mobile/SKILL.md`.

M1 bàn giao prototype có thể bấm qua các màn hình bằng dữ liệu mẫu. Dùng [roadmap](ROADMAP.md) và [kế hoạch](PLAN.md) khi duyệt bố cục và điều hướng.

## Mở cửa sổ Android Emulator trực tiếp

Hai AVD dùng ảnh hệ thống Android 35 Google APIs x86_64. `ShrimpMetric_API35` có màn hình 1080 × 2400, còn `ShrimpMetric_Compact_API35` có màn hình 720 × 1600 để kiểm tra bố cục hẹp. Từ terminal đã nạp môi trường:

```bash
adb start-server
sg kvm -c 'emulator -avd ShrimpMetric_API35 -gpu swiftshader'
```

Lệnh trên mở cửa sổ Android Emulator riêng trên Windows qua WSLg. Có thể bấm, vuốt, nhập bằng bàn phím và dùng các nút điều khiển ngay trong cửa sổ đó. ADB dùng để cài app và debug.

Dùng một giả lập mỗi lần. Chạy `flutter devices` rồi `flutter run -d <device-id>` trong terminal riêng. Giữ phiên debug mở và nhấn `r` để hot reload các chỉnh sửa Dart/UI, hoặc `R` khi cần chạy lại từ đầu. Khởi động lại phiên build khi thay đổi plugin, dependency hoặc cấu hình native. Mở cấu hình màn hình nhỏ khi đến lượt kiểm tra bố cục. Nếu trình kiểm tra Android báo chưa rõ trạng thái license do proxy môi trường, thử chạy lại với các biến proxy rỗng được bỏ khỏi lệnh đó.

Logo nguồn nằm tại `assets/branding/shrimpmetric-icon.png`. Android và iOS có các ảnh launcher xuất từ nguồn này. Bản iOS cần macOS và Xcode để build và kiểm thử.

## Vị trí mã nguồn

- `lib/main.dart` khởi động app.
- `lib/app/` chứa cấu hình toàn app, điều hướng và giao diện dùng chung khi cần.
- `lib/features/<tính-năng>/presentation/` chứa các màn hình và trạng thái giao diện của tính năng. Đặt widget riêng trong `presentation/widgets/` khi cần tách. Ví dụ màn hình tổng quan ở `lib/features/overview/presentation/overview_screen.dart`.
- Đặt phần xử lý dữ liệu, camera hoặc AI cạnh tính năng dùng nó khi triển khai. Chỉ đưa một widget hay dịch vụ vào thư mục dùng chung khi có nhiều tính năng cần dùng.
- `test/` chứa các bài kiểm thử. `android/` và `ios/` chứa cấu hình native và icon từng nền tảng.
