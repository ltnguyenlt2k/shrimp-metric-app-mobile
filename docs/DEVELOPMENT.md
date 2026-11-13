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

Hai AVD dùng ảnh hệ thống Android 35 Google APIs x86_64. `ShrimpMetric_API35` có màn hình 1080 × 2400, còn `ShrimpMetric_Compact_API35` có màn hình 720 × 1600 để kiểm tra bố cục hẹp. Từ thư mục gốc repo trong terminal đã nạp môi trường:

```bash
adb start-server
export SHRIMPMETRIC_SKINS="$(pwd)/tools/android-emulator"
sg kvm -c 'emulator -avd ShrimpMetric_API35 -skindir "$SHRIMPMETRIC_SKINS" -skin phone -gpu swiftshader'
```

Lệnh trên mở cửa sổ Android Emulator riêng trên Windows qua WSLg, với khung thân máy và lớp bo cả bốn góc màn hình đã duyệt. Skin nằm trong `tools/android-emulator/phone` và dành cho AVD chính 1080 × 2400. Dùng AVD Compact với skin mặc định khi kiểm tra bố cục hẹp. Có thể bấm, vuốt, nhập bằng bàn phím và dùng các nút điều khiển ngay trong cửa sổ đó. ADB dùng để cài app và debug.

Dùng một giả lập mỗi lần. Chạy `flutter devices` rồi `flutter run -d <device-id>` trong terminal riêng. Giữ phiên debug mở và nhấn `r` để hot reload các chỉnh sửa Dart/UI, hoặc `R` khi cần chạy lại từ đầu. Khởi động lại phiên build khi thay đổi plugin, dependency hoặc cấu hình native. Mở cấu hình màn hình nhỏ khi đến lượt kiểm tra bố cục. Nếu trình kiểm tra Android báo chưa rõ trạng thái license do proxy môi trường, thử chạy lại với các biến proxy rỗng được bỏ khỏi lệnh đó.

Logo nguồn nằm tại `assets/branding/shrimpmetric-icon.png`. Android và iOS có các ảnh launcher xuất từ nguồn này. Bản iOS cần macOS và Xcode để build và kiểm thử.

## Kiểm tra bố cục trên nhiều màn hình

Pixel 6 là cấu hình chạy hằng ngày. Redmi Note 14 và moto g55 5G cũng có màn hình 1080 × 2400. Galaxy A56 5G dùng 1080 × 2340. Các thông số vật lý này giúp chọn cấu hình tham chiếu, còn bố cục Flutter dựa trên không gian khả dụng theo pixel logic. [Xiaomi](https://www.mi.com/global/product/redmi-note-14/specs/) · [Motorola](https://en-us.support.motorola.com/app/answers/detail/a_id/183716/~/specifications---moto-g55-5g) · [Samsung](https://www.samsung.com/au/smartphones/galaxy-a/galaxy-a56-5g-awesome-graphite-128gb-sm-a566bzkkats/)

| Cấu hình kiểm thử | Kích thước logic xấp xỉ trước khi trừ vùng hệ thống |
|---|---|
| AVD Compact, 720 × 1600 ở 320 dpi | 360 × 800 |
| AVD chính, 1080 × 2400 ở 420 dpi | 411 × 914 |
| Viewport kiểm thử rộng và thấp hơn, tỷ lệ 19.5:9 | 450 × 975 |

Viewport thứ ba là kích thước kiểm thử đề xuất, có thể dùng trong widget test hoặc mô phỏng trên cùng AVD. Chạy từng AVD một và dùng lại bản debug để kiểm tra hai cấu hình. Kích thước cửa sổ giả lập trên Windows chỉ ảnh hưởng mức phóng khi xem.

Khi duyệt UI, kiểm tra giờ, sóng, pin và thanh điều hướng ngay trên cửa sổ giả lập. Có thể bật vùng khuyết camera trên AVD chính bằng `adb -s <device-id> shell cmd overlay enable-exclusive --category com.android.internal.display.cutout.emulation.hole`, sau đó mở lại app. Đây là cấu hình Android cục bộ để kiểm tra vùng an toàn. Ngày thường xuất hiện ở màn hình chính hoặc màn hình khóa, còn thanh trạng thái trong app hiển thị giờ.

Dùng `LayoutBuilder` cho không gian của từng vùng và `MediaQuery` khi cần thông tin toàn cửa sổ. Dùng `SafeArea` cho nút và nội dung cần tránh vùng khuyết hoặc thanh hệ thống. Khi thiếu chỗ, cho nội dung xuống dòng, xếp dọc hoặc cuộn. Giữ tỷ lệ ảnh và kiểm tra khung căn mẫu khi camera được tích hợp. Duyệt chữ tiếng Việt ở cỡ mặc định và cỡ lớn, thao tác với bàn phím mở, và khả năng chạm tới các nút chính. [Flutter adaptive layouts](https://docs.flutter.dev/ui/adaptive-responsive/general) · [SafeArea và MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery)

## Vị trí mã nguồn

- `lib/main.dart` khởi động app.
- `lib/app/` chứa cấu hình toàn app, điều hướng và giao diện dùng chung khi cần.
- `lib/features/<tính-năng>/presentation/` chứa các màn hình và trạng thái giao diện của tính năng. Đặt widget riêng trong `presentation/widgets/` khi cần tách. Ví dụ màn hình tổng quan ở `lib/features/overview/presentation/overview_screen.dart`.
- Đặt phần xử lý dữ liệu, camera hoặc AI cạnh tính năng dùng nó khi triển khai. Chỉ đưa một widget hay dịch vụ vào thư mục dùng chung khi có nhiều tính năng cần dùng.
- `test/` chứa các bài kiểm thử. `android/` và `ios/` chứa cấu hình native và icon từng nền tảng.

## Nguồn tài nguyên prototype M1

- `material_ui` 1.11.0, BSD-3-Clause. Nội dung giấy phép có trong màn hình giấy phép Flutter. [Nguồn package](https://pub.dev/packages/material_ui/versions/1.11.0)
- `assets/demo/shrimp-tray.jpg` là ảnh minh họa do OpenAI ImageGen tạo cho prototype M1. Số đếm trong giao diện là dữ liệu mẫu độc lập với ảnh.

## Duyệt khả dụng của prototype M1

Từ màn hình giới thiệu và ảnh thao tác Tomota S3+, lấy ba ý cho ShrimpMetric: dành diện tích cho khay lúc chụp, sắp xếp kết quả theo ảnh gốc → tổng số tôm → ảnh có khung → cỡ tôm, khối lượng và chiều dài, và tách lịch sử từng lần đo khỏi tổng hợp theo thời gian. [Tomota S3+](https://tomota.vn/tomota-s3-plus)

Dùng ISO 9241-11:2018 làm khung đánh giá trong bối cảnh người nuôi thao tác trên điện thoại cạnh ao. Các bước dưới đây là tiêu chí thử của dự án. [ISO 9241-11:2018](https://www.iso.org/standard/63500.html)

- **Hiệu quả:** chụp mẫu, nhận biết trạng thái đang xử lý, đọc đúng số đếm, lưu và mở lại đúng lần đo. Kiểm tra ngày giờ, bật/tắt khung nhận diện, và đối chiếu số lần đo, trung bình và biểu đồ sau khi đổi khoảng ngày.
- **Hiệu suất:** từ Tổng quan đến nút chụp trong hai thao tác, từ Lịch sử đến chi tiết trong một thao tác, từ Tổng quan đến Phân tích trong một thao tác. Ghi thời gian và số thao tác thực tế khi thử với người dùng.
- **Sự hài lòng:** nhờ người dùng mục tiêu thử luồng mẫu và phản hồi về độ dễ đọc, độ rõ của trạng thái xử lý và mức tự tin khi đọc biểu đồ. Cần buổi thử thực tế để đánh giá mục này.
