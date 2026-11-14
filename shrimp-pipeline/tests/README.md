# Kiểm thử model độc lập

Từ `shrimp-pipeline/`, dùng Python 3.12, PyTorch 2.7.1, TorchVision 0.22.1, các phiên bản trong `requirements.txt` và ffmpeg.

```sh
python models/count/train.py --epochs 20
python models/weight/train.py
python -m unittest discover -s tests
python tests/review_count.py
python tests/review_weight.py
```

Video MP4 dựng từ kết quả suy luận, có nhãn đối chứng và dự đoán, gồm cả mẫu tốt và mẫu sai nhiều. Đếm dùng ảnh giữ riêng CSIRO theo ngày chụp và Vannamei Anatomical theo nhóm DB. Cân dùng số đo bằng tay và kiểm thử giữ riêng từng DB, ảnh minh họa ghép đúng DB và mã cá thể. Xem JSON trong [reports/](reports/). Các tệp model và video nằm cục bộ trong `artifacts/count-v1/` và `artifacts/weight-v1/`.

## Kiểm thử đúng bối cảnh app

Bộ review thực tế dùng ảnh hoặc clip điện thoại nhìn từ trên xuống khay lấy mẫu có nước. Kiểm theo nhóm tôm giống (PL), tôm nhỏ, tôm đang nuôi và tôm thương phẩm, theo loài và mật độ. Ảnh ngoài vuông, sàng lưới ở ao và ảnh chụp riêng từng con chỉ phục vụ benchmark dữ liệu tương ứng. Chúng không đại diện cho bài kiểm thử khay. Muốn báo sai số cần số đếm đối chứng cho từng khay hoặc phiên, và chiều dài/cân đối chứng nếu đánh giá chỉ số đo.

Video `count-tray-review.mp4` chạy model hiện tại trên bảy ảnh tôm sú PL trong khay, các panel a–g của hình 2 trong Li và cộng sự. Đây là nhiều mức mật độ trong cùng giai đoạn PL. Model chỉ trả 1–2 điểm mỗi ảnh, bỏ sót rõ ràng. Hình công bố không kèm nhãn từng panel đã xác minh nên báo dự đoán riêng, không tính MAE. Chưa có mẫu khay đúng bối cảnh cho tôm lớn. [Bài báo và hình 2](https://doi.org/10.3390/ani13122036)

Để chạy lại, tải [hình gốc](https://mdpi-res.com/animals/animals-13-02036/article_deploy/html/images/animals-13-02036-g002.png) vào `artifacts/external/li2023-figure2.png` rồi chạy `python tests/review_trays.py`. Video ghi công tác giả, cắt riêng từng panel và vẽ điểm dự đoán. Video benchmark dataset được đặt tên riêng `count-dataset-review.mp4`. Báo cáo benchmark trước đây vẫn dùng để so sánh bản export trên cùng tập kiểm thử.

## Phạm vi lần chạy v1

- Đếm dùng heatmap tâm từ backbone MobileNetV3-Small đã fine-tune trên hai nguồn. Đầu ra là điểm. Các nhánh mask cá thể, loài cấp khay, PL dày, mốc giải phẫu và độ đầy ruột còn chờ lượt huấn luyện và đánh giá riêng. Tập tôm thẻ kiểm thử ở đây là ảnh từng con. Tập đếm hiện thiếu khay rỗng đã xác nhận và khay tôm thẻ nhiều con cùng giao thức chụp.
- Giữ ứng viên có trọng số Conv lưu FP16 và phép tính FP32. Bản INT8 dùng ngưỡng chung để so sánh ban đầu, chưa hiệu chỉnh lại ngưỡng riêng. Đo CPU i7-13650HX, ONNX Runtime CPU 2 luồng, sau 8 lần warm-up. p95 end-to-end gồm giải mã, resize, suy luận và lọc điểm, chưa gồm camera. Chưa có số đo Android/iOS, RAM đỉnh hoặc nhiệt.
- Hồi quy tôm thẻ xuất JSON hệ số, yêu cầu chiều dài theo định nghĩa của bộ Vannamei Biomass. Giá trị ngoài 4–14,4 cm bị từ chối. Cần kiểm lại với chiều dài do pipeline ảnh đo trước khi dùng.
- ONNX là bản xuất để review. Chính sách phân phối trọng số, bản LiteRT/Core ML, kiểm thử clip thật 5–6 frame và bộ test khay tại trại vẫn cần xác nhận trước khi tích hợp.
