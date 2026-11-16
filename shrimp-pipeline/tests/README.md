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

## Nguồn bổ sung theo kích cỡ

- **PL:** Li và cộng sự, hình 2 gồm bảy ảnh khay theo mật độ. PL-Detection có nhãn hộp theo công bố DeformDANet. Chưa xác minh được gói tải và quyền của bộ đầy đủ. [Li et al.](https://doi.org/10.3390/ani13122036) · [DeformDANet](https://doi.org/10.3389/fmars.2026.1965583)
- **Khay có tôm thân lớn hơn:** TheNho *Shrimp size* công bố CC BY 4.0 và có nhãn Shrimp/circle. Hai ảnh gốc 1920 × 2560 đã tải và kiểm tra trực quan. Các điểm tròn đen trong ảnh thuộc khay. Chưa có số đo, cân hoặc nhãn đối chứng của hai ảnh tải trực tiếp. ZIP v1 trả HTTP 403. Hai ảnh chỉ dùng kiểm tra ngoài tập và không tính MAE. Nguồn gốc [ảnh A](https://source.roboflow.com/NTkJQZHmPoNDZoplXWrYNx7JYfI2/2moEfWRUrk7DRMnT02um/original.jpg) · [ảnh B](https://source.roboflow.com/NTkJQZHmPoNDZoplXWrYNx7JYfI2/7hgg2RfmLP0v5JPzQzzY/original.jpg) · [danh mục TheNho](https://universe.roboflow.com/thenho/shrimp-size). Lưu tại `artifacts/external/thenho-tray-a.jpg` và `artifacts/external/thenho-tray-b.jpg`.
- **Tôm thẻ 8–25 g:** Nghiên cứu Aquaculture Reports mô tả 1.318 ảnh từ video khay ăn và 6.994 chú thích. Khay ăn là nguồn bổ trợ cho tôm lớn. Gói ảnh gốc và quyền tái sử dụng chưa xác minh để nhập. [Aquaculture Reports](https://doi.org/10.1016/j.aqrep.2025.103137)
- **Tham chiếu quy trình:** Tomota và ảnh màn hình video cho thấy bố cục chụp, kết quả và khung tôm. Ảnh gốc và quyền dùng cho dataset chưa xác nhận. [Tomota S3+](https://tomota.vn/tomota-s3-plus)

Vòng xanh là điểm cực đại do model dự đoán, không phải biên cơ thể. `Reference: Unverified` nghĩa là chưa có số đếm đối chứng cho ảnh. Model v1 chỉ thử nhiệm vụ đếm. Phân nhóm mẫu theo kích cỡ cần số đo hoặc thông tin giai đoạn do nguồn xác nhận.


## Tiêu chí review detector và nhận diện loài

Model đếm v1 dự đoán điểm tâm. Kết quả trên khay PL cho thấy bỏ sót rõ rệt. Ứng viên kế tiếp cho luồng khay cần định vị từng cá thể thấy được bằng bounding box, hoặc mask kèm box. Đánh giá box với nhãn vẽ tay để phân biệt phát hiện đúng, báo nhầm và bỏ sót. Báo thêm sai số đếm theo loài, giai đoạn và mật độ. Trong video review, ghi rõ box dự đoán và box đối chứng, kèm tổng số tương ứng. Khay PL dày có thể dùng nhánh đếm điểm riêng nếu được kiểm chứng trên tập PL có nhãn.

Dùng các box đủ rõ để cắt từng con và chạy bộ phân loại tôm sú/tôm thẻ. Tổng hợp bằng chứng từ các crop qua 5–6 frame hợp lệ để trả một loài cho cả khay. Khi thiếu bằng chứng, trả chưa xác định loài. Đếm độc lập từng frame rồi lấy trung bình, còn box hiển thị thuộc ảnh đại diện. Đo độ chính xác định vị và độ chính xác loài cấp khay riêng. Dataset huấn luyện hoặc kiểm thử loài cần hai loài chụp trong điều kiện tương đương để giảm nguy cơ model dựa vào nền hoặc thiết bị.


## Detector khoanh vùng detect-v3 và pipeline độc lập

Phạm vi: tôm sống bơi trong khay hoặc thùng có nước, từ lúc thả nuôi đến thương phẩm, một lớp `shrimp` chung cho tôm thẻ và tôm sú. Model là Mask R-CNN ResNet50-FPN v2 khởi tạo từ COCO.

```sh
python registry/fetch_roboflow.py            # cần ~/.config/shrimpmetric/roboflow.key
python models/detect/train.py --epochs 14    # ghi artifacts/detect-v3
python tests/evaluate_detect.py --model artifacts/detect-v3 --split test
python pipeline/run.py <ảnh hoặc thư mục 5-6 frame> [--px-per-cm N] [--table average|tongwei|growmax]
```

Dữ liệu train: CSIRO (tôm sú trên sàng lưới), Vannamei Anatomical (ảnh từng con), JALA Vannamei v8 (tôm thẻ trong khay trắng), hai bộ khay của TheNho, bộ tôm trong nước ao của TheNho, và ảnh ghép giả khay từ các con tôm thẻ cắt theo mask. Các bộ đã tải nhưng không dùng và lý do nằm trong `registry/sources.tsv`.

Kết quả trên tập test giữ riêng, đo qua đúng đường chạy của pipeline, khớp box IoU ≥ 0,5 ([detect-v3-test.json](reports/detect-v3-test.json), [detect-v2-test.json](reports/detect-v2-test.json)). detect-v2 là baseline chỉ train trên CSIRO và Vannamei, dừng ở epoch 7.

| Nguồn test | Ảnh / con | detect-v3: sai số đếm trung bình mỗi ảnh | detect-v3: precision / recall | detect-v2: precision / recall |
|---|---|---|---|---|
| JALA, tôm thẻ trong khay | 41 / 407 | 0,22 con (2,16%) | 0,990 / 0,983 | 0,462 / 0,393 |
| TheNho, tôm lớn trong khay | 7 / 28 | 0 | 1,000 / 1,000 | 0,867 / 0,464 |
| Vannamei, ảnh từng con | 48 / 48 | 0,02 con | 0,980 / 1,000 | 1,000 / 1,000 |
| CSIRO, tôm sú trên sàng ở ao | 82 / 631 | 1,63 con (27,5%) | 0,847 / 0,853 | 0,834 / 0,859 |

Giới hạn của các số trên:

- JALA dùng cách chia tập của nhà xuất bản, không có thông tin phiên chụp. Cùng một khay có thể xuất hiện ở cả train và test, nên số trên JALA có thể lạc quan.
- Tập TheNho chỉ có 7 ảnh test.
- CSIRO còn kém. Ảnh là sàng lưới xanh ở ao với dây, bọt và phản quang, và nhãn gốc bỏ sót một số con nhỏ hoặc bị che.
- Chưa có ảnh khay thật của dự án kèm số đếm tay, nên chưa có số đo ngoài hiện trường.

Kiểm tra bằng mắt ngoài tập train: năm ảnh khay nhựa trong có tôm sống từ gói ảnh của bài IEEE Access (không có nhãn, loài khác, lưu ở `artifacts/external/tray-unlabeled/`). Pipeline khoanh được phần lớn tôm, mỗi ảnh khoảng 15–17 con sót 1–2 con, chủ yếu ở mép khay và ở cặp tôm chồng nhau.

Kích thước: chiều dài đo theo đường tâm mask, chiều rộng là trung vị bề ngang. Khối lượng và con/kg lấy từ `pipeline/length_weight_tables.json`, mặc định là trung bình hai thước Tongwei và Growmax do người dùng cung cấp. Vạch thước được đọc bằng mắt từ ảnh, cần đối chiếu với thước thật. Chỉ xuất cm, gam và con/kg khi có `--px-per-cm` từ bước hiệu chỉnh. Phép đo chiều dài từ mask chưa được kiểm chứng với số đo thật.

Nhận loài sú/thẻ chưa có; pipeline trả `undetermined` và coi mọi con là một lớp tôm chung. Mask R-CNN ResNet50 là model để chốt độ chính xác trên máy tính.

## Cỡ ảnh chuẩn

```sh
python tests/scale_sweep.py --model artifacts/detect-v3
```

Thu nhỏ dần ảnh khay test (JALA, TheNho) rồi đo theo chiều dài thân tôm tính bằng pixel ([detect-v3-scale-sweep.json](reports/detect-v3-scale-sweep.json)). Sai số chiều dài ở đây so mask dự đoán với mask nhãn của cùng con, không phải so với thước thật.

| Chiều dài thân (px) | Tỉ lệ tìm thấy | Sai số chiều dài trung vị |
|---|---|---|
| 0–12 | 0,336 | 20,1% |
| 12–16 | 0,745 | 10,3% |
| 16–24 | 0,929 | 5,2% |
| 24–32 | 0,955 | 4,1% |
| 32–48 | 0,965 | 3,6% |
| 48–64 | 0,989 | 2,5% |
| 64–96 | 0,998 | 2,2% |
| 96–160 | 0,998 | 2,6% |
| ≥160 | 0,999 | 2,7% |

Quy tắc: con nhỏ nhất dài ít nhất 64 px (tối thiểu 48 px), tức `px/cm ≥ 64 / chiều dài con nhỏ nhất (cm)`. Ảnh chuẩn đề xuất sau bước nắn khay là 2048 × 1536, đáy khay lấp đầy khung; cạnh dài có thể từ 1536 đến 2560 px nếu vẫn thỏa quy tắc. Bước hiệu chỉnh phải trả kèm px/cm.

## Độ đầy ruột (thử nghiệm)

`pipeline/gut.py` đo phần chiều dài bụng có đường tối chạy dọc giữa thân, chia ba mức rỗng / một phần / đầy, hoặc `not_observable`. Ý tưởng theo hai bài báo (doi 10.1080/09540091.2023.2268878 và 10.1016/j.aqrep.2025.103137); chỉ đọc được phần tóm tắt và không bài nào công bố dữ liệu có nhãn. Trên 435 con của tập test khay: 412 con đọc được. Chưa có nhãn độ đầy ruột nên chưa đo được độ chính xác; xem bằng mắt thấy sai ở tôm nằm nghiêng và ảnh nhòe. Kết quả trong `result.json` được ghi là thử nghiệm.

## ShrimpLite (lite-v1), model cho điện thoại

Mục này là bản đầu, giữ lại để so sánh; model điện thoại hiện tại ở mục phone-v1 bên dưới. Lệnh lúc đó: `python models/lite/train.py --output artifacts/lite-v1` (dải cỡ 0,6–1,3, cửa sổ đỉnh 3 ô) và bản `export_lite.py` cũ có xuất INT8.

MobileNetV3-Large + FPN nhẹ, 2,9 triệu tham số, chỉ gồm tích chập. Đầu ra `[1, 4, H/4, W/4]`: tâm con tôm, vùng thân, độ lệch x/y về tâm; ghép thành từng con bằng `models/lite/model.py:decode`. Cùng dữ liệu và cách chia tập với detect-v3, chọn epoch 33, ngưỡng 0,2.

Độ chính xác trên tập test, bản ONNX cỡ cố định 1 × 3 × 768 × 1024, một lượt, không cắt ô ([lite-v1-export.json](reports/lite-v1-export.json); số qua đường PyTorch của pipeline ở [lite-v1-test.json](reports/lite-v1-test.json)):

| Nguồn test | detect-v3 (P / R, sai số đếm) | lite-v1 FP32, 11,6 MB | lite-v1 INT8, 3,4 MB |
|---|---|---|---|
| JALA, khay | 0,990 / 0,983, 0,22 con | 0,956 / 0,958, 0,27 con | 0,873 / 0,926, 0,71 con |
| TheNho, khay | 1,000 / 1,000, 0 | 0,931 / 0,964, 0,14 con | 0,581 / 0,893, 2,14 con |
| Vannamei, từng con | 0,980 / 1,000, 0,02 con | 0,842 / 1,000, 0,19 con | 0,625 / 0,938, 0,50 con |
| CSIRO, sàng ở ao | 0,847 / 0,853, 1,63 con | 0,694 / 0,813, 1,93 con | 0,545 / 0,545, 1,76 con |

- Bản FP32 ONNX khớp PyTorch (lệch đầu ra tối đa 0,0001).
- INT8 lượng tử hóa sau huấn luyện làm giảm độ chính xác rõ, kể cả cấu hình tốt nhất đã thử (chỉ lượng tử hóa Conv, giữ ba lớp đầu ra dạng float). Lượng tử hóa mọi phép toán còn tệ hơn (precision chung 0,45). Chưa dùng được INT8; cần huấn luyện có lượng tử hóa (QAT) hoặc dùng FP16.
- Tốc độ ONNX Runtime trên CPU máy tính (i7-13650HX, WSL), FP32: 137 ms với 1 luồng, 78 ms với 2 luồng, 52 ms với 4 luồng. Đây không phải số đo trên điện thoại; chưa chạy trên thiết bị Android nào.
- lite-v1 kém detect-v3 trên khay khoảng 3 điểm precision và 2,5 điểm recall, và hay tách một con thành hai trên ảnh từng con.

## phone-v1, một file model cho Android và iOS

```sh
python models/lite/train.py --epochs 30 --lr 4e-4 --init artifacts/lite-v1/lite.pt --output artifacts/lite-v2
python tests/export_lite.py --model artifacts/lite-v2 --output artifacts/phone-v1
python tests/evaluate_detect.py --model artifacts/phone-v1 --split test
python tests/evaluate_detect.py --model artifacts/phone-v1 --split test --mosaic 3 [--mode whole|full]
```

`artifacts/phone-v1/shrimp-lite.onnx` (FP32, 11,6 MB, cỡ vào tự do theo bội của 32) và `config.json` chứa mọi tham số ghép tâm. `run.py:PhoneDetector` chạy file này bằng ONNX Runtime CPU đúng như app: lượt 1 ở cạnh dài 1024; nếu trung vị cạnh dài box < 96 px và ảnh đủ lớn thì lượt 2 chạy ảnh đầy đủ trong 4 ô chồng mép. `--mode whole` chỉ chạy lượt 1, `--mode full` chạy lượt 2 nguyên ảnh.

Độ chính xác của file ONNX trên tập test ([phone-v1-test.json](reports/phone-v1-test.json)):

| Nguồn test | precision / recall | Sai số đếm mỗi ảnh |
|---|---|---|
| JALA, khay | 0,968 / 0,968 | 0,29 con (3,3%) |
| TheNho, khay | 1,000 / 1,000 | 0 |
| Vannamei, từng con | 0,833 / 0,833 | 0 (đếm đúng, 8/48 vùng khoanh lệch) |
| CSIRO, sàng ở ao | 0,662 / 0,740 | 1,74 con |

Thử tôm nhỏ bằng ảnh ghép N × N ảnh khay test vào một khung 2048 × 1536 (báo cáo `phone-v1-test-mosaic*.json`):

| Ảnh thử | Chỉ lượt 1 | Lượt 2 chia 4 ô (mặc định) | Lượt 2 nguyên ảnh |
|---|---|---|---|
| 2 × 2, 12 ảnh / 435 con | 0,880 / 0,807 | 0,940 / 0,931 | 0,949 / 0,947 |
| 3 × 3, 5 ảnh / 426 con | 0,721 / 0,528 | 0,935 / 0,906 | 0,940 / 0,913 |

Tốc độ và RAM đỉnh trên CPU máy tính (i7-13650HX, WSL), không phải điện thoại ([phone-v1-export.json](reports/phone-v1-export.json)):

| Cỡ vào | 1 luồng | 2 luồng | 4 luồng | RAM đỉnh |
|---|---|---|---|---|
| 768 × 1024 (lượt 1) | 163 ms | 88 ms | 54 ms | 239 MB |
| 864 × 1152 (một ô lượt 2, chạy 4 ô) | 193 ms | 116 ms | 76 ms | 317 MB |
| 1536 × 2048 (lượt 2 nguyên ảnh) | 661 ms | 404 ms | 284 ms | 457 MB |

Giới hạn: ảnh ghép là ảnh khay thu nhỏ chứ không phải tôm nhỏ thật; con rất to (dài hơn nửa khung) có thể bị khoanh thiếu; chưa đo trên thiết bị Android hay iOS nào; code ghép tâm phía app chưa viết (`models/lite/model.py:decode` là bản tham chiếu).

## Video kiểm chứng

```sh
python tests/review_pipeline.py    # mặc định so artifacts/detect-v3 với artifacts/phone-v1
```

Ghi `artifacts/review/pipeline-review.mp4` (cần ffmpeg): 32 ảnh test có nhãn, 6 ảnh ghép thử tôm nhỏ và 5 ảnh khay không nhãn. Mỗi ảnh hiện ảnh đầu vào, vùng khoanh của từng model kèm chế độ chạy và thời gian, số thật, số dự đoán, độ lệch và sai số lũy kế; trang cuối là bảng tổng kết, lưu thêm ở `pipeline-review.json`.
