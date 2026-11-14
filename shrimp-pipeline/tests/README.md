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

## Ảnh thử từ nguồn ngoài

Ảnh [Penaeus vannamei.jpg](https://commons.wikimedia.org/wiki/File:Penaeus_vannamei.jpg) từ iNaturalist, CC0 1.0, lưu ở `artifacts/external/vannamei-commons.jpg`. Chạy riêng sau huấn luyện và loại khỏi chỉ số chung. Đây là ảnh một cá thể, dùng để quan sát tổng quát hóa. Video thêm điểm dự đoán và thu nhỏ ảnh để hiển thị. Bài nghiên cứu đếm trong trại của Bukas và cộng sự ghi dữ liệu cung cấp theo yêu cầu, chưa dùng trong lần chạy này. [Bài báo](https://epic.awi.de/id/eprint/58961/1/Bukasetal2024.pdf)

## Phạm vi lần chạy v1

- Đếm dùng heatmap tâm từ backbone MobileNetV3-Small đã fine-tune trên hai nguồn. Đầu ra là điểm. Các nhánh mask cá thể, loài cấp khay, PL dày, mốc giải phẫu và độ đầy ruột còn chờ lượt huấn luyện và đánh giá riêng. Tập tôm thẻ kiểm thử ở đây là ảnh từng con. Tập đếm hiện thiếu khay rỗng đã xác nhận và khay tôm thẻ nhiều con cùng giao thức chụp.
- Giữ ứng viên có trọng số Conv lưu FP16 và phép tính FP32. Bản INT8 dùng ngưỡng chung để so sánh ban đầu, chưa hiệu chỉnh lại ngưỡng riêng. Đo CPU i7-13650HX, ONNX Runtime CPU 2 luồng, sau 8 lần warm-up. p95 end-to-end gồm giải mã, resize, suy luận và lọc điểm, chưa gồm camera. Chưa có số đo Android/iOS, RAM đỉnh hoặc nhiệt.
- Hồi quy tôm thẻ xuất JSON hệ số, yêu cầu chiều dài theo định nghĩa của bộ Vannamei Biomass. Giá trị ngoài 4–14,4 cm bị từ chối. Cần kiểm lại với chiều dài do pipeline ảnh đo trước khi dùng.
- ONNX là bản xuất để review. Chính sách phân phối trọng số, bản LiteRT/Core ML, kiểm thử clip thật 5–6 frame và bộ test khay tại trại vẫn cần xác nhận trước khi tích hợp.
