# Hồ sơ quyết định kiến trúc

Các mục **Đã chốt** phản ánh yêu cầu của người dùng. Các mục **Đề xuất** là lựa chọn lập kế hoạch, có thể cập nhật khi có dữ liệu. Xem [kế hoạch](PLAN.md) và [roadmap](ROADMAP.md).

## ADR-001 · Flutter, kiểm thử Android trước

**Trạng thái** · Đã chốt.

**Bối cảnh và quyết định** · Sản phẩm dành cho cả iPhone và Android. Dùng Flutter để chia sẻ UI và logic. Phát triển trên Android trước vì chưa có Mac. Cân nhắc khả năng chạy iOS khi chọn plugin.

**Đánh đổi và xem xét lại** · Hai codebase native tăng khối lượng duy trì. Flutter vẫn cần kiểm chứng quyền, plugin, camera và hiệu năng riêng trên iOS. Chọn cách truy cập macOS khi chuẩn bị M4. [Flutter iOS](https://docs.flutter.dev/platform-integration/ios/setup)

## ADR-002 · Tách UI khỏi camera, lưu trữ và phân tích

**Trạng thái** · Đề xuất.

**Bối cảnh và quyết định** · UI cần được phát triển song song với model. Tổ chức theo tính năng, với trạng thái màn hình và logic thao tác gọi lớp lưu trữ hoặc dịch vụ camera/phân tích. Dùng bộ ảnh cố định và kết quả mẫu cho kiểm thử, rồi thay bộ phân tích tại cùng điểm tích hợp. Chọn thư viện quản lý trạng thái và lưu dữ liệu khi xác nhận nhu cầu thực tế.

**Đánh đổi và xem xét lại** · Gọi trực tiếp plugin từ widget có ít mã ban đầu nhưng khiến UI khó kiểm thử bằng ảnh mẫu. Tách ở các điểm có phụ thuộc nền tảng hoặc cần thay thế. [Hướng dẫn kiến trúc Flutter](https://docs.flutter.dev/app-architecture/guide)

## ADR-003 · Chụp theo yêu cầu và phân tích cục bộ

**Trạng thái** · Xử lý trên thiết bị đã chốt. Chụp từng ảnh và đánh giá LiteRT là đề xuất.

**Bối cảnh và quyết định** · Ưu tiên tốc độ, độ mượt và nhiệt khi chụp lặp lại. Bắt đầu bằng preview theo yêu cầu, chụp ảnh, giải phóng camera rồi xử lý. Dùng số nhập/xác nhận thủ công khi chưa có AI đủ tin cậy. Đánh giá LiteRT với model và thiết bị thật.

**Đánh đổi và xem xét lại** · Phân tích theo ảnh không có phản hồi tức thời khi đang ngắm. Chỉ xem xét luồng liên tục nếu quy trình chụp cần tính năng đó và có số đo hiệu năng. ML Kit có điều khoản và số liệu sử dụng SDK riêng, hiện là phương án tham khảo. [LiteRT](https://github.com/google-ai-edge/LiteRT) · [Điều khoản ML Kit](https://developers.google.com/ml-kit/terms)

## ADR-004 · Lịch sử cục bộ và nguồn số liệu

**Trạng thái** · Đề xuất.

**Bối cảnh và quyết định** · Lưu kết quả để xem offline và phục vụ đánh giá model về sau. Mỗi lần đo có mã mẫu, thời điểm, tham chiếu ảnh, nguồn kết quả và phiên bản model hoặc cấu hình hiệu chỉnh nếu có. Tách số AI và số xác nhận. Giữ bản ghi cũ qua cập nhật app và model. Thiết kế lưu/xóa ảnh cùng dữ liệu để có thể phục hồi khi thao tác dở dang.

**Đánh đổi và xem xét lại** · Đồng bộ cloud tăng phạm vi quyền riêng tư và vận hành. Lưu cục bộ đòi hỏi chốt dung lượng, thời gian giữ ảnh và cách xuất dữ liệu nếu cần. Chọn cơ chế lưu sau khi chốt cấu trúc mẫu/lô/ao.

## ADR-005 · Đóng góp mẫu và phân phối model

**Trạng thái** · Đã chốt bản đầu chỉ có nút. Kho nhận ảnh và cách tải model riêng để sau.

**Bối cảnh và quyết định** · Bản đầu hiển thị nút Đóng góp mẫu và thông báo trạng thái. Giai đoạn nâng cao thu ảnh qua kho riêng có phân quyền và sự đồng ý. Đội dự án xuất bộ dữ liệu, huấn luyện ngoài app và đưa model đã kiểm chứng vào bản cập nhật. Firebase Cloud Storage là ứng viên lưu ảnh và yêu cầu Blaze. Firebase ML Custom Models là ứng viên lưu và phân phối model tương thích tới app.

**Đánh đổi và xem xét lại** · Phát hành model cùng app giúp kiểm thử đồng bộ nhưng cần một lượt cập nhật app. Tải model độc lập nhanh hơn khi định dạng và quy trình xử lý đã ổn định, đồng thời cần kiểm tra tương thích và dự phòng. Việc chọn kho và phân phối từ xa phụ thuộc chi phí, chính sách dữ liệu và nhu cầu cập nhật. [Firebase ML](https://firebase.google.com/docs/ml/use-custom-models) · [Yêu cầu thanh toán Firebase Storage](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)

## ADR-006 · Thiết kế, skill chung và bằng chứng kiểm thử

**Trạng thái** · Yêu cầu dùng chung đã chốt. Cách triển khai là đề xuất.

**Bối cảnh và quyết định** · Giữ một nguồn skill và checklist cho Codex, Claude Code. Chuẩn hóa màn hình tham chiếu, màu, chữ, các trạng thái và cách kiểm chứng qua ảnh giả lập. Dùng chung quy trình ghi nhận lỗi, rà soát bảo mật và benchmark máy thật.

**Đánh đổi và xem xét lại** · Duy trì hướng dẫn riêng theo agent có thể khiến hai quy trình lệch nhau. Thư mục và công cụ chạy có thể khác theo agent, còn tiêu chí nghiệm thu dùng chung. [Flutter cho coding agent](https://docs.flutter.dev/ai/get-started)

## ADR-007 · Giấy phép dùng thương mại và kiểm soát chi phí

**Trạng thái** · Đã chốt tiêu chí giấy phép. Phí store và hạ tầng còn mở.

**Bối cảnh và quyết định** · Chấp nhận giấy phép nguồn mở cho phép dùng thương mại và không yêu cầu mua license. Flutter và plugin camera dùng BSD-3-Clause, LiteRT dùng Apache-2.0. Ghi phiên bản, nguồn, giấy phép và nghĩa vụ của thư viện trực tiếp, phụ thuộc, model, dữ liệu, font và tài nguyên UI. Kèm bản quyền, giấy phép và NOTICE theo yêu cầu khi phân phối. Dự kiến có mục Giấy phép nguồn mở trong Thông tin app.

**Đánh đổi và xem xét lại** · Quyền dùng runtime không quyết định quyền dùng model hoặc dữ liệu. Kiểm tra lại khi đổi phiên bản hoặc thêm thành phần. Bản thử Android chạy cục bộ. Chỉ chọn dịch vụ có khả năng tính phí sau khi quyết định chi phí và mục đích sử dụng. [Flutter FAQ](https://docs.flutter.dev/resources/faq) · [Camera LICENSE](https://github.com/flutter/packages/blob/main/packages/camera/camera/LICENSE) · [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0)
