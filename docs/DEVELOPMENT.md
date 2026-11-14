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
- `features/capture/data/` quản lý CameraController, quyền và luồng lấy frame qua camera. `features/capture/presentation/` quản lý màn chụp và vòng đời.
- `features/processing/domain/` chứa dữ liệu frame độc lập với plugin camera. `features/processing/application/` nhận lô frame, M2 chọn frame giữa và encode JPEG trên isolate. Bộ phân tích AI/OpenCV sau này nhận lô frame ở đây trước khi giải phóng RAM.
- `features/results/` chứa dữ liệu lần đo và màn xác nhận/xem ảnh. `features/history/data/` lưu ảnh đại diện và metadata theo từng lần đo, dùng đổi tên thư mục để tránh hiển thị bản ghi đang lưu hoặc xóa dở.
- `test/` chứa các bài kiểm thử. `android/` và `ios/` chứa cấu hình native và icon từng nền tảng.

## Nguồn tài nguyên prototype M1

- `camera` 0.12.2, BSD-3-Clause. Android tối thiểu API 24 ở baseline camera. [Nguồn](https://pub.dev/packages/camera/versions/0.12.2)
- `image` 4.12.0, MIT. Dùng đổi hướng frame và encode JPEG. [Nguồn](https://pub.dev/packages/image/versions/4.12.0)
- `path_provider` 2.1.6, BSD-3-Clause. Dùng tìm thư mục riêng của app. [Nguồn](https://pub.dev/packages/path_provider/versions/2.1.6)
- `material_ui` 1.11.0, BSD-3-Clause. Nội dung giấy phép có trong màn hình giấy phép Flutter. [Nguồn package](https://pub.dev/packages/material_ui/versions/1.11.0)
- `assets/demo/shrimp-tray.jpg` là ảnh minh họa do OpenAI ImageGen tạo cho prototype M1. Số đếm trong giao diện là dữ liệu mẫu độc lập với ảnh.

## Duyệt khả dụng của prototype M1

Từ màn hình giới thiệu và ảnh thao tác Tomota S3+, lấy ba ý cho ShrimpMetric: dành diện tích cho khay lúc chụp, sắp xếp kết quả theo ảnh gốc → tổng số tôm → ảnh có khung → cỡ tôm, khối lượng và chiều dài, và tách lịch sử từng lần đo khỏi tổng hợp theo thời gian. [Tomota S3+](https://tomota.vn/tomota-s3-plus)

Dùng ISO 9241-11:2018 làm khung đánh giá trong bối cảnh người nuôi thao tác trên điện thoại cạnh ao. Các bước dưới đây là tiêu chí thử của dự án. [ISO 9241-11:2018](https://www.iso.org/standard/63500.html)

- **Hiệu quả:** chụp mẫu, nhận biết trạng thái đang xử lý, đọc đúng số đếm, lưu và mở lại đúng lần đo. Kiểm tra ngày giờ, bật/tắt khung nhận diện, và đối chiếu số lần đo, trung bình và biểu đồ sau khi đổi khoảng ngày.
- **Hiệu suất:** từ Tổng quan đến nút chụp trong hai thao tác, từ Lịch sử đến chi tiết trong một thao tác, từ Tổng quan đến Phân tích trong một thao tác. Ghi thời gian và số thao tác thực tế khi thử với người dùng.
- **Sự hài lòng:** nhờ người dùng mục tiêu thử luồng mẫu và phản hồi về độ dễ đọc, độ rõ của trạng thái xử lý và mức tự tin khi đọc biểu đồ. Cần buổi thử thực tế để đánh giá mục này.

### Bố cục và biểu đồ M1

Tomota S3+ là tham chiếu cho bố cục kết quả từng mẫu. JALA là tham chiếu cho việc tách ghi nhận mẫu và theo dõi theo thời gian. Tổng quan của ShrimpMetric đặt thao tác chụp trước, sau đó hiển thị kết quả gần nhất và biểu đồ cỡ tôm. Phân tích có bộ lọc ngày và chỉ số, trục thời gian, đơn vị và danh sách giá trị để đọc hoặc mở lại từng lần đo. [Tomota S3+](https://tomota.vn/tomota-s3-plus) · [JALA App](https://next.jala.tech/app) · [Apple HIG Charts](https://developer.apple.com/design/human-interface-guidelines/charts)

Kiểu chữ chính dùng cỡ 26 cho tên màn, 19 cho tên mục, 15–16 cho nội dung và thao tác, 13 cho ngày, đơn vị và ghi chú. Nút chụp cao tối thiểu 52 pixel logic. Khi thử với người ít kinh nghiệm, quan sát họ tìm nút chụp, đọc giá trị kèm đơn vị và mở lại một lần đo từ biểu đồ qua danh sách. [Android Accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility)

## Hiệu năng qua từng mốc

- Dựng danh sách lịch sử theo vùng nhìn thấy và giải mã thumbnail theo kích thước hiển thị. Trước khi phát hành lưu trữ thật, kiểm tra với lịch sử lớn, truy vấn phân trang và xóa cả ảnh gốc/thumbnail thuộc bản ghi nếu chúng không còn được tham chiếu.
- Khi thay đổi luồng nặng, đo khởi động, thời gian khung hình khi cuộn, RAM đỉnh và dung lượng bản phát hành. Ghi thiết bị, chế độ build, kịch bản, kích thước dữ liệu và kết quả để so với baseline trước. Với camera/AI, bổ sung độ trễ và nhiệt khi chụp lặp trên Android thật ở profile hoặc release.
- Widget test kiểm tra hành vi UI. Benchmark trên thiết bị mục tiêu dùng để kết luận về tốc độ và bộ nhớ.

Baseline thăm dò M1 trên Android Emulator API 35 x86_64, debug, 4 bản ghi mẫu: một lần mở lạnh qua `adb shell am start -W` báo 3.363 ms, PSS ngay sau khi mở khoảng 270 MiB, APK debug khoảng 136 MiB. Đây là số đo một lần của prototype trên giả lập. Cần đo nhiều lượt ở profile/release trên máy thật, với lịch sử lớn, để đánh giá thời gian khung hình và bộ nhớ.

Khi duyệt thao tác, tách vùng đọc số liệu khỏi nút điều hướng. Kiểm tra chạm vào số liệu ở Tổng quan giữ nguyên màn hình, bấm hàng trong Lịch sử mở đúng mẫu và nút xóa mở xác nhận, và quay lại từ Giấy phép về thẳng Cài đặt. Đây là kiểm thử hành vi giao diện. Đánh giá khả dụng với người dùng mới cần quan sát họ thực hiện các tác vụ mà không được chỉ trước vị trí nút.

## Kiểm tra luồng camera M2

Android Emulator `ShrimpMetric_API35`, Android 35 x86_64, bản debug. Build trên hệ thống tệp Linux của WSL khi Gradle báo lỗi ghi DEX trên ổ Windows. Bản kiểm tra đã chụp offline, lưu một ảnh và ghi nhận 6 frame trong metadata. Đối chiếu màn Kết quả với commit M1 `638e9bb`: dùng lại dòng số mô phỏng, khu vực ảnh và nút lưu đã duyệt. Nguồn ảnh ở AVD là cảnh camera ảo.

Cần xác nhận chất lượng ảnh, tỷ lệ đủ frame, độ trễ, RAM và nhiệt trên điện thoại thật ở chế độ profile hoặc release. AI, OpenCV và phép tổng hợp chỉ số qua nhiều frame sẽ được triển khai theo yêu cầu của từng tính năng.

### Kiểm tra quyền hệ điều hành

Trên Android API 35, dùng `adb shell pm revoke com.ltnguyenlt2k.shrimp_metric android.permission.CAMERA` rồi `adb shell pm clear-permission-flags com.ltnguyenlt2k.shrimp_metric android.permission.CAMERA user-set user-fixed` để mô phỏng lần đầu xin quyền mà giữ lịch sử trên giả lập. Đã xác nhận hộp thoại hệ thống khi bấm Chụp mẫu, hướng dẫn khi từ chối, hỏi lại theo thao tác và mở camera sau khi cấp quyền. Kiểm tra manifest sau khi hợp nhất bằng `adb shell dumpsys package com.ltnguyenlt2k.shrimp_metric`. Camera là quyền runtime hiện dùng. Ảnh lưu trong thư mục riêng của app. Đã rà khai báo camera iOS, còn chờ kiểm thử trên iPhone. [Android runtime permissions](https://developer.android.com/training/permissions/requesting) · [Flutter camera](https://pub.dev/packages/camera)
