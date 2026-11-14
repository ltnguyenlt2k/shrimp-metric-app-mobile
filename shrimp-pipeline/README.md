# ShrimpMetric AI

Khu vực chuẩn bị dữ liệu và model để huấn luyện ngoài app. Flutter nhận model xuất sau khi kiểm thử trên điện thoại.

| Thư mục | Nội dung |
|---|---|
| `data/raw/` | Tệp gốc tải về. Giữ nguyên archive để đối chiếu và tái lập. |
| `checkpoints/pretrained/` | Trọng số nền COCO và ImageNet để fine-tune. |
| `models/` | Vị trí cho mã và cấu hình từng nhánh khi bắt đầu huấn luyện. |
| `artifacts/` | Kết quả các lượt huấn luyện và model xuất. Dự kiến dùng `exports/android/` cho LiteRT và `exports/ios/` cho Core ML. |
| `registry/` | URL, phiên bản, tác giả, giấy phép, trạng thái và SHA-256. |

Git lưu tài liệu và danh mục. Dataset, checkpoint và bản export nằm trên máy. Có thể dùng URL trong [danh mục](registry/sources.tsv) để tải lại vào đúng đường dẫn, rồi chạy `sha256sum -c registry/downloads.sha256` từ thư mục này. Hash ghi nhận bản tải cục bộ. Các tiền tố hash từ tên checkpoint được đối chiếu trong lần nhập đầu.

## Thứ tự sử dụng

1. Kiểm kê ảnh và nhãn, ghép ID bộ Vannamei gốc với bộ mask dẫn xuất trước khi chia tập. Chia theo cá thể, lô hoặc phiên. Giữ các frame cùng lượt chụp trong cùng tập.
2. Ưu tiên baseline tách và đếm. Sau đó thử nhận diện loài cấp khay trên ảnh hai loài được chụp cùng quy trình. Mỗi khay chỉ có một loài. AI tổng hợp bằng chứng từ 5–6 frame, lấy trung bình số đếm trên các frame hợp lệ và trả một ảnh đại diện. Tài liệu quyết định nằm trong [APP-NOTES.md](../APP-NOTES.md).
3. Dự kiến các module `instance_seg`, `species`, `pl_count`, `landmarks`, `weight` và `gut_fullness`. Tạo cấu hình và script khi có tác vụ huấn luyện cụ thể.
4. Trước khi đưa model vào app, ghi phiên bản dữ liệu, cấu hình xử lý, quyền phân phối trọng số, kết quả đánh giá và chi phí chạy trên điện thoại. Hai bộ Mendeley phục vụ hình thái và khối lượng tôm thẻ. Bộ CSIRO phục vụ segmentation tôm sú. Bộ JALA bổ sung segmentation tôm thẻ khi tải được.

Giữ ghi công, liên kết CC BY 4.0 và thông tin thay đổi khi chia sẻ dữ liệu tương ứng. Giấy phép mã MMDetection và TorchVision được ghi riêng với điều khoản trọng số. [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

## Kiểm tra lần nhập đầu

- CSIRO có đúng 523.013.632 byte theo danh mục nguồn. Đọc được TAR và nhãn COCO của fold 1. Fold này có 560 ảnh train và 141 ảnh test, tương ứng 3.269 và 877 annotation. Đây là số đếm từ fold đã đọc. Số cá thể công bố cần đối chiếu thêm trước khi khóa manifest huấn luyện.
- ZIP mask tôm thẻ qua kiểm tra giải nén và khớp cả 782 hash nội bộ do tác giả cung cấp.
- Ba checkpoint khớp tiền tố SHA-256 trong tên tệp chính thức. Chỉ kiểm tệp, quyền sử dụng được theo dõi riêng trong danh mục.
- ZIP Vannamei Biomass có 1.465.185.448 byte, 5.507 ảnh PNG và 5 bảng XLSX. Kiểm tra CRC toàn bộ ZIP đã qua.
