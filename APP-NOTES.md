# Ghi chú trao đổi về app điện thoại

## Đã chốt

- Tên app đã chọn là **ShrimpMetric**. Repo là `shrimp-metric-app-mobile`. Bản logo đề xuất lồng chữ N vào hình tôm: [icon ShrimpMetric](assets/branding/shrimpmetric-icon.png).

- Sản phẩm là app di động đa nền tảng cho iPhone (iOS) và Android, dùng Flutter. Android là nền tảng phát triển và kiểm thử đầu tiên. iOS sẽ được tích hợp và kiểm thử ở giai đoạn sau. Người dùng không có máy Mac.
- App dùng camera để chụp ảnh và lấy thông tin từ ảnh. AI xử lý ảnh ngay trên điện thoại.
- Camera có thể chỉ mở khi người dùng thực hiện thao tác cần camera. Ưu tiên xử lý nhanh, UI mượt và hạn chế nóng khi dùng lặp lại.
- UI cần thích ứng với nhiều kích thước màn hình điện thoại. Muốn dùng giả lập trong quá trình lập trình và kiểm thử.
- Bộ skill và quy trình dự án phải dùng chung cho nhiều coding agent, tối thiểu Codex và Claude Code. Phạm vi gồm quy trình làm việc, UI, kiểm thử trên giả lập, bảo mật và hiệu năng.
- Hiện đang trao đổi, nghiên cứu và ghi lại quyết định. Chỉ triển khai khi người dùng yêu cầu rõ ràng.

## Kết quả tra cứu và đề xuất đang cân nhắc

- Android Emulator hỗ trợ camera mô phỏng. iOS Simulator chạy qua Xcode trên macOS. Có thể dùng cùng bộ ảnh mẫu để kiểm thử luồng ảnh trên hai nền tảng. Kiểm chứng camera, độ trễ, RAM và nhiệt khi dùng lặp lại trên máy thật. [Android Emulator Camera](https://developer.android.com/studio/run/emulator-use-camera) · [Apple Simulator](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices) · [Flutter profiling](https://docs.flutter.dev/perf/ui-performance)
- Hướng ban đầu là mở camera theo thao tác, chụp một ảnh rồi xử lý. Chỉ cân nhắc phân tích liên tục nếu tính năng cần phản hồi ngay khi đang ngắm. ML Kit có các tác vụ thị giác dựng sẵn, LiteRT là một ứng viên khi cần model riêng. [Flutter camera](https://pub.dev/packages/camera) · [ML Kit](https://developers.google.com/ml-kit/guides) · [LiteRT](https://developers.google.com/edge/litert)
- Đề xuất lấy plugin Flutter/Dart chính thức làm nền, bổ sung skill dự án dùng chung theo định dạng SKILL.md. Duy trì một nguồn nội dung và đưa vào thư mục mà mỗi agent nhận diện khi thiết lập. Dùng chung lệnh, ảnh mẫu, tiêu chí và kết quả kiểm thử. [Flutter và coding agents](https://docs.flutter.dev/ai/get-started) · [OpenAI về skill](https://developers.openai.com/plugins/concepts/skills) · [Thư mục skill của từng agent](https://developers.openai.com/api/reference/cli)
- Kiểm thử UI bằng nhiều kích thước màn hình, cỡ chữ và vùng an toàn. Tham chiếu OWASP MASVS cho quyền camera, lưu ảnh, metadata nhạy cảm và log. [Flutter adaptive UI](https://docs.flutter.dev/ui/adaptive-responsive) · [Flutter integration tests](https://docs.flutter.dev/testing/integration-tests) · [OWASP MASVS](https://mas.owasp.org/MASVS/)

- Giai đoạn Android có thể dùng Android Emulator hằng ngày và thiết bị Android thật để kiểm tra camera, tốc độ AI và nhiệt. Khi chuyển sang iOS, các lựa chọn gồm Mac từ xa có Xcode hoặc CI macOS build bản simulator để mở qua trình duyệt. Khi cần kiểm tra camera, AI và nhiệt trên iPhone thật, có thể dùng CI macOS build bản đã ký và phát qua TestFlight. [Flutter iOS](https://docs.flutter.dev/platform-integration/ios/setup) · [Codemagic preview](https://docs.codemagic.io/yaml-distributing/app-preview/) · [TestFlight](https://developer.apple.com/testflight/)

## Còn mở

- Hoãn lựa chọn dịch vụ chạy iOS Simulator từ xa hoặc build bản thử iOS đến giai đoạn iOS.
- Thông tin cần lấy là metadata, nội dung nhìn thấy trong ảnh, hay cả hai? Có cần phản hồi trước khi bấm chụp không?
- Thiết bị mục tiêu, ngưỡng độ trễ và nhiệt, khả năng offline ngay lần đầu, chính sách lưu ảnh và tác vụ AI cụ thể.
- Đối tượng sử dụng, vấn đề cần giải quyết và phạm vi bản đầu.

## Sản phẩm và trải nghiệm mong muốn

- App chụp ảnh để phân tích và đếm tôm, tham khảo [Tomota S3T](https://tomota.vn/tomota-s3t) về đếm, chiều dài và độ đồng đều của tôm giống, và [Tomota S3+](https://tomota.vn/tomota-s3-plus) về theo dõi tăng trưởng, độ đầy ruột và lưu/xuất dữ liệu. Hai giải pháp tham chiếu có phần cứng chụp mẫu. Phạm vi app chưa chốt theo toàn bộ tính năng Tomota.
- Ưu tiên UI di động hiện đại, chỉn chu, có bản sắc riêng. Tránh bố cục, màu sắc và chi tiết trang trí lặp lại kiểu template AI. Người dùng muốn có dashboard ngắn gọn, lịch sử phân tích và cài đặt gồm hiệu chỉnh camera lúc thiết lập, ngôn ngữ và thông tin/phiên bản app.
- Độ chính xác của AI có thể hoàn thiện dần sau khi có dữ liệu và kiểm chứng model. Đề xuất phân biệt kết quả mẫu, ước tính AI và số đã xác nhận; cân nhắc cho phép chỉnh số và lưu ảnh kèm lần phân tích.
- Hướng trải nghiệm đề xuất: Tổng quan, Chụp mẫu, Lịch sử, Cài đặt. Ưu tiên thao tác chính rõ ràng, chữ và số dễ đọc ngoài hiện trường, ảnh mẫu và kết quả nổi bật. Màu, kiểu chữ và bố cục cụ thể còn mở.
- Đề xuất một skill thiết kế Flutter dùng chung cho Codex và Claude Code, ghi quy tắc giao diện, các trạng thái và cách đối chiếu ảnh chụp Android Emulator với thiết kế đã duyệt. Tham khảo [Anthropic Frontend Design](https://claude.com/plugins/frontend-design) cho định hướng thẩm mỹ và [Flutter AI tools](https://docs.flutter.dev/ai/tools) cho triển khai widget và bố cục thích ứng.

### Quyết định sản phẩm cần trao đổi

- Ưu tiên tôm giống ở trại giống, tôm đang nuôi ở ao, hay cả hai ngay từ đầu?
- Chụp cầm tay hay dùng khay/hộp, giá đỡ và ánh sáng cố định? Hiệu chỉnh phục vụ chất lượng ảnh, vùng đếm, quy đổi chiều dài, hay nhiều mục tiêu?
- Ngoài số lượng, chỉ số nào cần xuất hiện ở bản đầu? Lịch sử lưu theo lần chụp, lô, ao hay trại? Ngôn ngữ bản đầu và nhu cầu đồng bộ/xuất dữ liệu còn mở.

## Ý tưởng đóng góp ảnh và cập nhật model

- Người dùng hỏi về việc tự nguyện gửi ảnh đã đo để tạo bộ dữ liệu huấn luyện, cải thiện đếm, kích thước và ước tính khối lượng, sau đó phân phối model tốt hơn. Đây là hướng đang trao đổi.
- Đề xuất nút “Đóng góp mẫu” trên kết quả/lịch sử, xem trước dữ liệu và đồng ý trước khi gửi vào kho riêng. Giữ chất lượng ảnh chụp gốc, loại metadata nhạy cảm không cần thiết, gửi kèm thông số hiệu chỉnh, loại mẫu và dữ liệu đo xác nhận nếu có. App vẫn phân tích trên thiết bị.
- Đếm cần nhãn xác nhận. Đo kích thước cần mốc chuẩn hoặc bố trí đã hiệu chỉnh. Ước tính khối lượng cần mẫu ảnh ghép với số cân thực tế cùng đối tượng hoặc cùng nhóm, phân biệt cân tổng và cân từng con. Kết quả AI cũ không được dùng làm nhãn chuẩn. Đánh giá trên lô/trại giữ riêng và đo hiệu năng trên máy thật trước khi phát hành.
- Có thể đóng gói model mới trong bản cập nhật app. Tải riêng model là phương án sau nếu tương thích với runtime và quy trình xử lý đã cài, có lưu bản dự phòng và phiên bản model theo từng kết quả.
- Đã chốt bản đầu có nút Đóng góp mẫu; xử lý và gửi ảnh để giai đoạn sau. Chưa chốt dịch vụ lưu trữ hay nhu cầu ước tính khối lượng từng con, trung bình hoặc tổng mẫu. Tham khảo [Firebase Storage cho Flutter](https://firebase.google.com/docs/storage/flutter/upload-files), [Firebase ML](https://firebase.google.com/docs/ml/use-custom-models), [nghiên cứu ước tính khối lượng tôm](https://researchonline.jcu.edu.au/81679/1/JCU_81679.pdf).

## Chi phí và giấy phép

- Đã chốt chấp nhận giấy phép nguồn mở cho phép dùng thương mại và không thu phí bản quyền. Khi triển khai phải ghi nguồn và tuân thủ điều khoản của từng thành phần. Phí tài khoản store và dịch vụ hạ tầng là quyết định riêng, còn mở.
- Flutter và camera dùng BSD-3-Clause. LiteRT dùng Apache-2.0. Cần kiểm tra riêng license của thư viện tích hợp, model/weights, dữ liệu và tài nguyên UI khi chọn. [Flutter FAQ](https://docs.flutter.dev/resources/faq) · [Camera LICENSE](https://github.com/flutter/packages/blob/main/packages/camera/camera/LICENSE) · [LiteRT](https://github.com/google-ai-edge/LiteRT)
- Firebase Storage yêu cầu bật Blaze. ML Kit có điều khoản dịch vụ riêng. Codemagic có hạn mức build miễn phí cho cá nhân và dịch vụ có thể tính phí. Các dịch vụ này chưa được chọn.
- Có thể phát triển và thử Android cục bộ trước, lưu ảnh trong app và xuất thủ công trong đợt thử nghiệm. Phát hành Google Play có phí đăng ký 25 USD một lần. Apple Developer Program để phát hành thông thường có phí 99 USD/năm, có diện miễn phí theo điều kiện. [Google Play](https://support.google.com/googleplay/android-developer/answer/6112435) · [Apple](https://developer.apple.com/programs/enroll/)

### Ghi nhận và kiểm tra trước khi phát hành

- Khi thêm hoặc cập nhật thành phần, ghi tên, phiên bản hoặc commit, URL nguồn, giấy phép và nghĩa vụ đi kèm. Rà soát cả thư viện phụ thuộc, plugin tích hợp LiteRT, model/weights, dữ liệu huấn luyện, font và tài nguyên UI. Chỉ chọn thành phần phù hợp với quyền sử dụng thương mại và quyền phân phối cần thiết.
- Khi phân phối app, giữ thông báo bản quyền, toàn văn giấy phép và các thông báo bắt buộc của thành phần đi kèm. Với Apache-2.0, kiểm tra NOTICE nếu có và đánh dấu tệp nguồn đã sửa nếu phân phối chúng. Dự kiến dùng mục Cài đặt → Thông tin app → Giấy phép nguồn mở để cung cấp thông báo cho người dùng, kiểm tra nội dung trên bản build phát hành. [Flutter FAQ](https://docs.flutter.dev/resources/faq) · [Apache-2.0, mục 4](https://www.apache.org/licenses/LICENSE-2.0)
- Ưu tiên đánh giá LiteRT cho AI cục bộ. Google ML Kit vẫn là phương án tham khảo có điều khoản riêng và gửi số liệu sử dụng SDK. [Điều khoản ML Kit](https://developers.google.com/ml-kit/terms)

## Tài liệu triển khai

- [Kế hoạch](docs/PLAN.md) · [Roadmap](docs/ROADMAP.md) · [ADR](docs/ADR.md).
