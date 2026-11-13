# Roadmap theo mốc nghiệm thu

Trình tự đề xuất, chưa ấn định ngày hoặc số tuần. Chi tiết thực hiện trong [kế hoạch](PLAN.md) và lý do chọn hướng trong [ADR](ADR.md).

| Mốc | Kết quả bàn giao | Điều kiện qua mốc |
|---|---|---|
| M0 · Môi trường | Toolchain Android cục bộ, giả lập, kết nối máy thật và quy trình agent dùng chung | Project Flutter mẫu chạy được trên giả lập. Máy thật được nhận diện để kiểm thử camera. Ghi phiên bản và cách chạy. |
| M1 · Khung và UI | Tổng quan, Chụp, Kết quả, Lịch sử, Cài đặt, bản dịch và trạng thái mẫu | Duyệt giao diện trên hai kích thước màn hình, cỡ chữ lớn và các trạng thái chính. |
| M2 · Luồng cục bộ | Camera, thiết lập chụp, xác nhận số đếm, lưu và mở lại kết quả, nút Đóng góp mẫu | Chụp thật và lưu/xem/xóa được khi offline. Kiểm tra quyền bị từ chối và rời app. Nút đóng góp hiển thị đúng trạng thái và không truyền dữ liệu. |
| M3 · AI thử nghiệm | Model đếm tại máy, phiên bản model trong lịch sử, bản thử Android | Báo cáo sai số trên tập giữ riêng và baseline độ trễ, bộ nhớ, nhiệt trên máy thật. Nếu model chưa đạt, bản thử giữ luồng đếm xác nhận thủ công và chỉ mở AI trong phạm vi thử nghiệm. |
| M4 · iOS | Bản Flutter chạy trên iOS Simulator và iPhone thật | Qua luồng camera, offline, lưu lịch sử, UI thích ứng và hiệu năng trên iPhone. Phụ thuộc môi trường macOS và cách cài bản thử. |
| M5 · Đóng góp mẫu | Kho riêng, luồng đồng ý và gửi mẫu, xuất dữ liệu huấn luyện | Chốt nơi lưu, quyền sử dụng, chính sách lưu/xóa và chi phí trước khi bật. Kiểm thử phân quyền, hủy/gửi lại, lọc metadata và xuất ảnh ghép đúng nhãn. Có thể làm sau M3 trên Android độc lập với tiến độ iOS. |
| M6 · Model nâng cao | Cải thiện đếm, kích thước, độ đồng đều hoặc khối lượng theo dữ liệu | Có số đo/cân đối chiếu, đạt ngưỡng sai số và hiệu năng đã chốt. Phát hành model cùng app trước, tải riêng nếu được chọn sau. Có thể bắt đầu nghiên cứu bằng mẫu đo riêng trước M5. |

## Điểm cần quyết định theo mốc

- **Trước M1:** Người dùng chính, tôm giống hay tôm nuôi ở ao, ngôn ngữ bản đầu và hướng nhận diện UI.
- **Trước M2:** Chụp cầm tay hay giá đỡ/khay, hiệu chỉnh để căn mẫu hay đo kích thước, quy tắc giữ ảnh và cách tổ chức lịch sử theo mẫu/lô/ao.
- **Trước M3:** Thiết bị Android mục tiêu, ngưỡng độ trễ và nhiệt, tiêu chí sai số đếm và phạm vi bản thử.
- **Trước M4:** Môi trường macOS, thiết bị iPhone và phương thức phân phối bản thử.
- **Trước M5/M6:** Kho lưu, ngân sách và quyền dùng dữ liệu. Chọn khối lượng tổng mẫu, trung bình hay từng con để thiết kế cách thu số cân.
