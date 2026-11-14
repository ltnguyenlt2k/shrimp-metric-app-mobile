# Kế hoạch triển khai app phân tích mẫu tôm

Đọc cùng [roadmap](ROADMAP.md), [các ADR](ADR.md) và [ghi chú yêu cầu](../APP-NOTES.md). Tài liệu này mô tả công việc sẽ thực hiện khi được yêu cầu triển khai.

## Mục tiêu và phạm vi

App Flutter cho iPhone và Android, phát triển và kiểm thử Android trước vì hiện chưa có Mac. Tham khảo S3T cho đếm và đánh giá mẫu, S3+ cho lịch sử và hướng theo dõi tăng trưởng. Bản đầu ưu tiên trải nghiệm hoàn chỉnh từ chụp đến lưu và xem lại. Đếm là chỉ số AI đầu tiên đề xuất. Chiều dài, độ đồng đều và khối lượng đi sau dữ liệu kiểm chứng. [Tomota S3T](https://tomota.vn/tomota-s3t) · [Tomota S3+](https://tomota.vn/tomota-s3-plus)

## 0. Chuẩn bị môi trường và quy trình dùng chung

1. Kiểm tra Flutter stable, Android Studio, SDK, platform tools, JDK đi kèm phù hợp và tăng tốc giả lập trên Windows. Xem điều khoản Android SDK khi thiết lập. Ghi phiên bản đã xác nhận và dùng cùng bộ công cụ cho Flutter, Gradle và adb. Nếu agent chạy trong WSL, kiểm chứng cách gọi bộ công cụ Windows và kết nối đúng thiết bị trước khi chuẩn hóa quy trình.
2. Dùng `flutter doctor -v`, `flutter devices` và `adb devices` để xác nhận Android toolchain. Tạo hai cấu hình màn hình điện thoại khác kích thước, có ít nhất một máy Android thật để thử camera và hiệu năng. Chạy thử project mẫu trước khi bắt đầu khung sản phẩm.
3. Chuẩn bị một nguồn skill dự án cho Codex và Claude Code, với hướng dẫn dùng chung về phát triển Flutter, thiết kế, kiểm thử, bảo mật và đo hiệu năng. Đặt nội dung vào vị trí mà mỗi agent hỗ trợ khi thiết lập. Dùng cùng ảnh mẫu được phép sử dụng và cùng lệnh kiểm tra. Ghi kết quả kiểm thử kèm phiên bản app, thiết bị, lệnh và ảnh màn hình khi phù hợp. [Thiết lập Android](https://docs.flutter.dev/platform-integration/android/setup) · [Flutter cho coding agent](https://docs.flutter.dev/ai/get-started)

## 1. Prototype giao diện tổng thể và duyệt bố cục

1. Duyệt màn hình Tổng quan, Chụp mẫu, Kết quả, Lịch sử và Cài đặt bằng dữ liệu mẫu. Định hình màu, chữ tiếng Việt, khoảng cách và thành phần theo tình huống dùng ngoài hiện trường. Ưu tiên ảnh mẫu, số liệu dễ đọc, thao tác chụp rõ ràng. Dùng thẻ, màu nhấn và chuyển động khi có tác dụng cụ thể.
2. Tạo điều hướng và theme Flutter dùng chung, cấu trúc bản dịch ngay từ đầu, lưu lựa chọn ngôn ngữ. Cài đặt có Hiệu chỉnh camera, Ngôn ngữ và Thông tin app gồm phiên bản và giấy phép. Dashboard hiển thị hành động chụp, lần đo gần nhất và lối vào lịch sử.
3. Thiết kế các trạng thái trống, tải, lỗi, bị từ chối quyền, chưa có AI, ước tính AI và đã xác nhận. Bố trí theo chiều rộng và chiều cao khả dụng bằng pixel logic. Kiểm tra các cấu hình hẹp, chuẩn và rộng theo [hướng dẫn phát triển](DEVELOPMENT.md), với cỡ chữ lớn, vùng an toàn, tương phản và TalkBack. [Flutter adaptive UI](https://docs.flutter.dev/ui/adaptive-responsive)

**Bàn giao M1** · Một prototype có thể bấm qua các màn hình chính trên Android Emulator, dùng dữ liệu mẫu. Duyệt bố cục, thứ tự thông tin và luồng điều hướng từ Tổng quan → Chụp mẫu → Kết quả → Lịch sử, cùng lối vào Cài đặt. Camera thật, hiệu chỉnh, lưu lịch sử và AI thuộc các mốc sau. Bắt đầu M2 sau khi người dùng duyệt bố cục tổng thể.

## 2. Luồng chụp, xác nhận và lưu cục bộ

1. Chỉ xin quyền khi vào luồng chụp. Mở preview theo thao tác, lấy 5–6 frame cách quãng trong khoảng 1,8 giây và hiển thị một ảnh đại diện, cho chụp lại, xử lý mất quyền và vòng đời khi rời màn hình hoặc đưa app xuống nền. Giải phóng camera khi kết thúc phiên chụp. Dùng cùng bộ ảnh mẫu để kiểm tra luồng trên giả lập và chụp thật để kiểm tra chất lượng đầu vào.
2. M2 lưu một JPEG đại diện khi xác nhận, dùng bản decode kích thước nhỏ cho danh sách. Các frame còn lại chỉ tồn tại trong phiên xử lý. Chính sách giữ ảnh gốc để huấn luyện thuộc luồng đóng góp. Chuẩn hóa chiều xoay ảnh và kích thước đầu vào xử lý. Có giới hạn ảnh và kiểm tra điều kiện chụp phù hợp với quy trình mẫu. Hiệu chỉnh ban đầu có thể hướng dẫn căn khung và ánh sáng. Chỉ quy đổi ra mm khi có mốc vật lý cùng mặt phẳng hoặc thiết lập được xác thực.
3. Giữ màn Kết quả và Lịch sử của baseline M1 (638e9bb). Ảnh từ camera thay ảnh minh họa ở vị trí có sẵn. Số đếm và chỉ số vẫn mô phỏng, lưu trong lịch sử với nguồn mô phỏng. Chỉ thay đổi giao diện khi người dùng duyệt. Lịch sử hỗ trợ chi tiết và xóa mẫu. Kiểm tra lưu thất bại, thiếu ảnh, hết dung lượng, thao tác lặp và dữ liệu còn đọc được sau nâng cấp.
4. Hiện nút **Đóng góp mẫu** trên kết quả đã lưu và trang chi tiết lịch sử. Hành vi đề xuất là mở thông báo “Tính năng đang được chuẩn bị. Ảnh của bạn vẫn lưu trên thiết bị.” Chạm nút không gửi ảnh, tạo hàng đợi hoặc ghi trạng thái đã đóng góp.

## 3. AI đếm tôm trên thiết bị và bản thử Android

1. Chuẩn bị bộ ảnh có quyền sử dụng, số đếm kiểm chứng và nhãn vị trí nếu model cần. Xác định quy trình chụp, cách tính sai số và tập đánh giá giữ riêng theo lô hoặc trại trước khi tối ưu.
2. Đánh giá LiteRT và thư viện tích hợp trên cả Android và iOS về giấy phép, hỗ trợ phiên bản hệ điều hành, ABI và định dạng model. Dùng bộ phân tích mẫu cho phát triển UI, thay bằng model đã kiểm chứng ở cùng điểm tích hợp. Cố định hợp đồng tiền xử lý, đầu vào và hậu xử lý theo phiên bản model.
3. Chạy xử lý ngoài luồng UI khi phù hợp, giới hạn một lượt mỗi lần và tránh giữ nhiều bản sao ảnh lớn. Đo từ bấm chụp tới có kết quả, RAM đỉnh, độ mượt và nhiệt sau các lượt lặp trên thiết bị mục tiêu. Chốt ngưỡng sau khi có baseline và yêu cầu sử dụng thực tế. Lưu phiên bản model cùng kết quả và giữ kết quả cũ khi cập nhật.
4. Kiểm thử unit cho xử lý ảnh và dữ liệu, widget cho trạng thái, integration cho luồng chụp/lưu/xem/xóa và nút đóng góp. Kiểm tra offline, quyền camera, luồng dữ liệu, log, bản quyền và thông báo giấy phép trên bản thử. Đo camera và hiệu năng trên máy thật bằng profile hoặc release. [Flutter integration tests](https://docs.flutter.dev/testing/integration-tests) · [Flutter profiling](https://docs.flutter.dev/perf/ui-performance) · [OWASP MASVS](https://mas.owasp.org/MASVS/)

## 4. iOS và tính năng nâng cao

- **iOS.** Khi có môi trường macOS/Xcode, xác nhận plugin, cấu hình quyền camera và ký bản thử. Dùng Simulator cho UI và dữ liệu mẫu, iPhone thật cho camera, inference, bộ nhớ và nhiệt. Phương thức truy cập Mac và phát hành sẽ được chọn lúc cần. [Thiết lập iOS](https://docs.flutter.dev/platform-integration/ios/setup)
- **Đóng góp mẫu.** Sau khi chốt chi phí và quyền sử dụng dữ liệu, cho người dùng xem trước ảnh và thông tin gửi, đồng ý tự nguyện, tải lên kho riêng và quản lý yêu cầu xóa theo chính sách đã công bố. Giữ chất lượng ảnh gốc, lọc GPS và metadata không cần. Gửi kèm mã mẫu, phiên bản hiệu chỉnh/model và nhãn xác nhận nếu có. Kiểm tra phân quyền, giới hạn tệp, mất mạng, gửi lại không tạo bản trùng và cơ chế xuất bộ dữ liệu.
- **Huấn luyện và phân phối.** Xuất ảnh và nhãn từ kho riêng, kiểm duyệt, huấn luyện ngoài app và đánh giá trên tập giữ riêng. Ưu tiên đóng gói model mới với bản cập nhật app. Tải model riêng chỉ xem xét sau khi ổn định hợp đồng tương thích, xác thực bản tải và có bản dự phòng. Firebase Cloud Storage là một phương án nhận ảnh. Firebase ML Custom Models là phương án phân phối model. [Firebase Storage](https://firebase.google.com/docs/storage/flutter/upload-files) · [Firebase ML](https://firebase.google.com/docs/ml/use-custom-models)
- **Đo nâng cao.** Kiểm chứng kích thước với mốc chuẩn và số đo thực. Kiểm chứng khối lượng bằng cân cùng mẫu đã chụp. Cân tổng và số đếm xác nhận cho tổng mẫu và trung bình mỗi con. Cân ghép với từng ảnh mới cho phép kiểm chứng dự báo từng con. Chỉ hiện các chỉ số sau khi đạt ngưỡng sai số đã chốt. [Nghiên cứu đo và ước tính khối lượng tôm](https://researchonline.jcu.edu.au/81679/1/JCU_81679.pdf)

### Khu vực chuẩn bị dữ liệu AI

[`shrimp-pipeline/`](../shrimp-pipeline/README.md) chứa danh mục nguồn và cấu trúc lưu dataset, checkpoint khởi tạo và bản export. Dữ liệu nhị phân lưu cục bộ. Model đưa vào app sau khi huấn luyện, xác minh quyền phân phối, đối chiếu đầu ra bản export và đo trên thiết bị mục tiêu.
