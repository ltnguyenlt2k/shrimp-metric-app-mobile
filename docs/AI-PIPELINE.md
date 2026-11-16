# Ngữ cảnh pipeline AI của ShrimpMetric

File này để người hoặc agent mới đọc một lần là nắm được yêu cầu, các quyết định đã chốt, trạng thái hiện tại và việc còn lại của phần AI. Số liệu chi tiết và lệnh chạy nằm ở [tests/README.md](../shrimp-pipeline/tests/README.md); nguồn dữ liệu ở [registry/sources.tsv](../shrimp-pipeline/registry/sources.tsv). Cập nhật file này mỗi khi một quyết định hoặc số đo thay đổi.

Cập nhật lần cuối: 2026-11-15.

## 1. Mục tiêu và yêu cầu của người dùng

Sản phẩm tham chiếu là [Tomota S3+](https://tomota.vn/tomota-s3-plus): bỏ tôm vào khay hoặc thùng trắng có nước, chụp từ trên xuống, app trả số con, kích cỡ, khối lượng, con/kg và độ đầy ruột.

Luồng đầy đủ:

1. App chụp 5–6 frame của khay (đã có trong app, M2).
2. Tiền xử lý và hiệu chỉnh bằng marker: nắn khay, trả ảnh chuẩn và tỉ lệ px/cm. **Chưa làm**, người dùng để sau.
3. Pipeline AI trên từng frame: khoanh vùng từng con, đếm, đo dài/rộng, đổi sang khối lượng và con/kg, độ đầy ruột.
4. Lấy trung bình các frame hợp lệ.
5. Hiển thị và lưu kết quả trong app. **Chưa làm**, để sau.

Các ràng buộc người dùng đã nêu:

- Tôm **sống, đang bơi trong nước** trong khay/thùng. Không phải tôm chết, tôm nằm trên bàn, tôm ở chợ.
- Cỡ tôm từ **lúc mới thả nuôi đến thu hoạch**. Không phải ấu trùng/PL trong trại giống.
- Cả tôm sú và tôm thẻ. Hiện **gộp chung một lớp "tôm"**; chưa cần tách loài.
- Chiều dài → khối lượng → con/kg theo hai thước của trại (Tongwei, Growmax); mặc định là **trung bình hai thước**.
- Mục tiêu **≥ 97% ngoài thực tế**, nhanh, nhẹ, chạy được trên điện thoại tầm trung và yếu (Android và iOS). Người dùng chưa định nghĩa 97% tính theo chỉ số nào (đếm, chiều dài hay khối lượng).
- Phải chứng minh pipeline chính xác **trước khi gắn vào app**. Không nêu kết luận thiếu căn cứ.
- Người dùng sẽ tự chụp và thu bộ ảnh thực địa sau.
- Mỗi lần kiểm chứng cần một **video** cho thấy ảnh đầu vào, kết quả và sai số.
- UI app giữ nguyên bản đã duyệt (xem AGENTS.md); mọi thay đổi nhìn thấy được cần người dùng duyệt.

## 2. Môi trường

- Mọi thứ chạy trong WSL `Ubuntu-24.04`. Windows không có flutter, adb, java, torch.
- Python: `~/.local/share/shrimpmetric/train-venv/bin/python` (Python 3.12, torch 2.7.1+cu128, torchvision 0.22.1, onnxruntime 1.22.1; không có pip, dùng uv). GPU RTX 4060 Laptop 8 GB. ffmpeg 6.1.1.
- Toolchain app: `~/.local/share/shrimpmetric/` (env.sh, Flutter, JDK 17, Android SDK, hai AVD). Bản build app là `~/.local/share/shrimpmetric/app-build` (rsync từ repo, vì Gradle lỗi trên /mnt/d).
- Gọi lệnh từ Windows: viết script `.sh` rồi chạy `wsl.exe -d Ubuntu-24.04 -- bash /mnt/c/.../x.sh` bằng PowerShell. Gọi `bash -lc '...'` qua Git Bash làm hỏng `$VAR` và đường dẫn `/mnt/...`.
- Khóa Roboflow nằm ở `~/.config/shrimpmetric/roboflow.key` trong WSL. Không đưa vào repo, không in ra.
- Dữ liệu, checkpoint và artifacts nằm ngoài Git (`shrimp-pipeline/data/raw`, `checkpoints`, `artifacts`). URL và SHA-256 ở `registry/`.

### Mốc (baseline) 2026-11-16

- Git chỉ chứa code, tài liệu, báo cáo JSON và mã băm. File nặng không vào Git và hiện **chỉ có trên máy này, chưa sao lưu**: `data/raw` 7,3 GB, `checkpoints` 285 MB, `artifacts` 462 MB.
- Dữ liệu và checkpoint tải về: 27 file, SHA-256 ở `registry/downloads.sha256`, đã kiểm tra khớp toàn bộ ngày 2026-11-16. Tải lại được theo `registry/sources.tsv` (Roboflow cần khóa API).
- Model và video do dự án tạo ra: SHA-256 ở `tests/reports/artifacts.sha256` (detect-v2, detect-v3, lite-v1, lite-v2, phone-v1, video kiểm chứng). Mất file thì phải train lại theo lệnh trong tests/README.md; kết quả train lại sẽ không trùng từng bit.

## 3. Các quyết định đã chốt

| Việc | Quyết định | Căn cứ |
|---|---|---|
| Lớp nhận diện | Một lớp `shrimp` chung | Người dùng đồng ý 2026-11-14 |
| Bảng thước | Trung bình Tongwei và Growmax (trung bình nhân ở đoạn hai thước cùng phủ) | Người dùng chọn |
| Ảnh chuẩn | **2048 × 1536** (4:3), đáy khay nắn phẳng lấp đầy khung, kèm px/cm | Thí nghiệm thu nhỏ ảnh, mục 5 |
| Cỡ tôm tối thiểu trong ảnh | Thân dài **≥ 64 px**, tối thiểu 48 px | Mục 5 |
| Cách chạy model trên điện thoại | Lượt 1 ở 1024 × 768; nếu tôm nhỏ thì chạy lượt 2 trên ảnh chuẩn đầy đủ 2048 × 1536 | Người dùng đồng ý 2026-11-15 |
| Model điện thoại | **Một file duy nhất** `shrimp-lite.onnx` (FP32) cho cả Android và iOS | Người dùng yêu cầu 2026-11-15; INT8 làm hỏng độ chính xác |
| Model tham chiếu trên PC | detect-v3 (Mask R-CNN), dùng để chốt trần độ chính xác | |

## 4. Kiến trúc pipeline (`shrimp-pipeline/pipeline/`)

`run.py` là điểm vào: `python pipeline/run.py <ảnh hoặc thư mục 5–6 frame> [--model DIR] [--px-per-cm N] [--table average|tongwei|growmax]`.

1. **Kiểm tra chất lượng frame**: độ nét (Laplacian), chói, tối. Ngưỡng là kinh nghiệm, chưa tinh chỉnh trên ảnh thực địa.
2. **Khoanh vùng từng con** bằng một trong ba detector, cùng giao diện (`load_detector`):
   - `Detector`: detect-v3, Mask R-CNN ResNet50-FPN v2, 184 MB, chỉ chạy trên PC.
   - `LiteDetector`: ShrimpLite chạy bằng PyTorch (để train và so sánh).
   - `PhoneDetector`: file `shrimp-lite.onnx` chạy bằng ONNX Runtime CPU, đúng cách app sẽ chạy (hai lượt như mục 3).
3. **Đếm**: số vùng khoanh được.
4. **Đo** (`size.py`): chiều dài theo đường tâm mask, chiều rộng là trung vị bề ngang. Con chạm mép khung được đếm nhưng không đo.
5. **Khối lượng và con/kg** (`length_weight_tables.json`): chỉ xuất khi có `--px-per-cm`.
6. **Độ đầy ruột** (`gut.py`): thử nghiệm, xem mục 8.
7. **Gộp frame**: trung bình số đếm trên các frame hợp lệ, chọn một frame đại diện để vẽ. Ghi `overlay.jpg`, `instances.png`, `result.json`.

### ShrimpLite (`models/lite/`)

- MobileNetV3-Large + FPN nhẹ, 2,9 triệu tham số, chỉ gồm tích chập (không NMS, không RoI) để chuyển sang runtime di động dễ.
- Vào: `rgb` float32 `[1, 3, H, W]` giá trị 0..1, H và W là bội của 32, phần đệm có giá trị 0,45. Chuẩn hóa mean/std nằm trong model.
- Ra: `maps` float32 `[1, 4, H/4, W/4]` = logit tâm con tôm, logit vùng thân, độ lệch x, độ lệch y về tâm (đơn vị 64 ô).
- Ghép thành từng con (`model.py:decode`, là bản tham chiếu cho code app): lấy đỉnh của bản đồ tâm trong cửa sổ `kernel` ô với điểm ≥ `threshold`; mỗi ô thân (sigmoid ≥ 0,5) cộng độ lệch rồi gán cho tâm gần nhất; bỏ con dưới 3 ô. Tham số nằm trong `config.json` cạnh file model.
- Quy tắc hai lượt (`run.py:PhoneDetector`): lượt 1 thu ảnh chuẩn về cạnh dài 1024. Nếu trung vị cạnh dài box của các con tìm được < 96 px (tính ở cỡ lượt 1) thì chạy lượt 2 trên ảnh chuẩn đầy đủ và dùng kết quả lượt 2.

## 5. Cỡ ảnh và cỡ tôm nhỏ nhất

Thí nghiệm (`tests/scale_sweep.py`, detect-v3, ảnh khay test JALA và TheNho thu nhỏ dần):

| Chiều dài thân (px) | Tỉ lệ tìm thấy | Sai số chiều dài trung vị (so với mask nhãn) |
|---|---|---|
| 0–12 | 33,6% | 20,1% |
| 12–16 | 74,5% | 10,3% |
| 16–24 | 92,9% | 5,2% |
| 24–32 | 95,5% | 4,1% |
| 32–48 | 96,5% | 3,6% |
| 48–64 | 98,9% | 2,5% |
| 64–96 | 99,8% | 2,2% |
| ≥ 96 | 99,8–99,9% | 2,6–2,7% |

Quy tắc: `px/cm ≥ 64 / chiều dài con nhỏ nhất (cm)`. Cạnh dài ảnh chuẩn có thể từ 1536 đến 2560 px nếu vẫn thỏa quy tắc.

**Pipeline AI không cần biết kích thước khay.** Nó chỉ nhận ảnh chuẩn và một số `px/cm` do bước hiệu chỉnh marker trả về (marker có kích thước thật đã biết, nên `px/cm = số pixel của marker / kích thước marker tính bằng cm`). Mọi phép đổi là `cm = pixel / px_per_cm`. Khi khay, thùng và marker đã cố định thì `px/cm` là hằng số của bộ thiết bị đó.

Bảng dưới chỉ là ví dụ quy đổi để hình dung "64 px là bao nhiêu mm", giả sử vùng nhìn thấy trong ảnh chuẩn dài bằng chiều dài ghi ở cột đầu (khi đó `px/cm = 2048 / chiều dài đó`). Đây không phải yêu cầu về khay:

| Khay dài | px/cm | Con dài 64 px | Con dài 48 px (tối thiểu) |
|---|---|---|---|
| 30 cm | 68,3 | 9,4 mm | 7,0 mm |
| 40 cm | 51,2 | 12,5 mm | 9,4 mm |
| 50 cm | 41,0 | 15,6 mm | 11,7 mm |
| 60 cm | 34,1 | 18,8 mm | 14,1 mm |

Các chiều dài này **nằm dưới vạch nhỏ nhất của cả hai thước** (Tongwei bắt đầu ở 4,0 cm ↔ 0,5 g), nên khối lượng và con/kg ở cỡ này chỉ là ngoại suy và hai thước lệch nhau nhiều lần. Điểm đo thật duy nhất ở vùng nhỏ là từ video Tomota: 3,57 cm ↔ 0,456 g (2.191 con/kg). Với tôm 12,5 mm, ngoại suy cho khoảng 0,03–0,08 g, tức cỡ 12.000–30.000 con/kg; không dùng con số này làm kết quả chính thức.

Camera 8 MP (3264 × 2448) đủ cho ảnh chuẩn nếu khay chiếm từ khoảng 63% bề ngang khung hình.

Khối lượng tỉ lệ với khoảng lũy thừa ba chiều dài: sai 2,2% chiều dài thành khoảng 6–7% khối lượng mỗi con.

## 6. Dữ liệu

Đang dùng để train và test (chia nhóm, seed 37, dùng chung cho mọi model):

- **JALA Vannamei v8** (Roboflow, CC BY 4.0): tôm thẻ sống trong khay trắng. Nguồn sát ngữ cảnh nhất. Chia tập theo nhà xuất bản, không có thông tin phiên chụp nên số test có thể lạc quan.
- **TheNho** shrimp-size v3 và camera-calibration v2: tôm lớn trong khay, ít ảnh (7 ảnh test). img-smkzh v10: tôm trong nước ao, chỉ train.
- **CSIRO**: tôm sú trên sàng lưới ở ao; lệch ngữ cảnh, nhãn thiếu, giữ làm benchmark phụ.
- **Vannamei Anatomical**: ảnh từng con; dùng thêm để cắt tôm ghép ảnh khay giả.

Đã tải nhưng không dùng (lý do từng bộ trong `sources.tsv`): tôm giống PL, tôm chết ngoài nước, tôm chợ/chế biến/bệnh, bộ chỉ có box. Bộ ảnh IEEE Access (3.698 ảnh khay, không nhãn, chưa rõ quyền dùng) chỉ lấy 5 ảnh để xem bằng mắt.

Không tìm thấy bộ dữ liệu công khai nào có nhãn độ đầy ruột.

**Thiếu quan trọng nhất**: ảnh khay thật của dự án kèm số đếm tay và chiều dài đo tay. Chưa có nó thì chưa thể nói gì về 97% thực địa.

## 7. Model và kết quả

Số đo trên tập test giữ riêng, khớp box IoU ≥ 0,5, qua đúng đường chạy của pipeline. Bảng đầy đủ và file báo cáo ở tests/README.md.

| Nguồn test | detect-v3 (PC) precision / recall, sai số đếm mỗi ảnh | **phone-v1** (`shrimp-lite.onnx`) | lite-v1 FP32 (bản trước) |
|---|---|---|---|
| JALA, tôm thẻ trong khay, 41 ảnh / 407 con | 0,990 / 0,983, 0,22 con | 0,968 / 0,968, 0,29 con | 0,956 / 0,958, 0,27 con |
| TheNho, tôm lớn trong khay, 7 ảnh / 28 con | 1,000 / 1,000, 0 | 1,000 / 1,000, 0 | 0,931 / 0,964, 0,14 con |
| Vannamei, ảnh từng con, 48 ảnh | 0,980 / 1,000, 0,02 con | 0,833 / 0,833, 0 con | 0,842 / 1,000, 0,19 con |
| CSIRO, tôm sú trên sàng ở ao, 82 ảnh / 631 con | 0,847 / 0,853, 1,63 con | 0,662 / 0,740, 1,74 con | 0,694 / 0,813, 1,93 con |

Thử tôm nhỏ bằng ảnh ghép (nhiều ảnh khay test JALA/TheNho xếp vào một khung 2048 × 1536, `--mosaic N`), phone-v1:

| Ảnh thử | Chỉ lượt 1 | Lượt 2 chia 4 ô (mặc định) | Lượt 2 nguyên ảnh |
|---|---|---|---|
| Ghép 2 × 2, 12 ảnh / 435 con | 0,880 / 0,807 | 0,940 / 0,931, sai số đếm 2,8% | 0,949 / 0,947, 2,4% |
| Ghép 3 × 3, 5 ảnh / 426 con | 0,721 / 0,528 | 0,935 / 0,906, sai số đếm 3,2% | 0,940 / 0,913, 3,0% |

**phone-v1** là model điện thoại hiện tại: `artifacts/phone-v1/shrimp-lite.onnx` (11,6 MB, FP32, sha256 `3a1979ee…46cd99`) kèm `config.json`. Xuất từ lite-v2 = lite-v1 train tiếp 30 epoch với dải cỡ tôm 0,4–1,6 và cửa sổ đỉnh 7 ô; chọn epoch 15, ngưỡng 0,2. File ONNX khớp PyTorch (lệch tối đa 0,0003).

Tốc độ và RAM của file đó, ONNX Runtime CPU trên PC (i7-13650HX), **không phải điện thoại**:

| Cỡ vào | 1 luồng | 2 luồng | 4 luồng | RAM đỉnh của tiến trình |
|---|---|---|---|---|
| Lượt 1, 768 × 1024 | 163 ms | 88 ms | 54 ms | 239 MB |
| Một ô của lượt 2, 864 × 1152 (chạy 4 ô) | 193 ms | 116 ms | 76 ms | 317 MB |
| Lượt 2 nguyên ảnh, 1536 × 2048 | 661 ms | 404 ms | 284 ms | 457 MB |

Lượt 2 mặc định chia 4 ô chồng mép (`PhoneDetector.quarters`) để RAM gần bằng lượt 1; chạy nguyên ảnh (`--mode full`) chính xác hơn một chút và nhanh hơn khoảng 15% nhưng tốn RAM gấp rưỡi. Ước lượng thô, chưa đo: CPU điện thoại tầm trung chậm hơn PC này khoảng 3–5 lần mỗi luồng.

Giới hạn đã thấy của phone-v1:

- Trên khay JALA còn kém detect-v3 khoảng 2 điểm precision và 1,5 điểm recall.
- Ảnh chỉ có một con rất to (dài hơn nửa khung): đếm đúng nhưng vùng khoanh lệch ở 8/48 ảnh, tức chiều dài con rất to có thể bị đo thiếu.
- Ảnh ghép là ảnh khay thu nhỏ, không phải tôm nhỏ thật; nó kiểm tra đường chạy hai lượt chứ không thay cho ảnh tôm mới thả.
- CSIRO (ngoài ngữ cảnh khay) vẫn kém.

Video kiểm chứng: `artifacts/review/pipeline-review.mp4` (135 giây, 38 ảnh có nhãn gồm 6 ảnh ghép, và 5 ảnh khay không nhãn), so detect-v3 với phone-v1, có thời gian chạy từng ảnh. Dựng lại bằng `python tests/review_pipeline.py`.

Đã rút ra:

- **INT8 (lượng tử hóa sau huấn luyện) không dùng được**: precision trên khay tụt từ 0,96 xuống 0,87 ở cấu hình tốt nhất, và trên PC còn chậm hơn FP32. Muốn có INT8 phải huấn luyện có lượng tử hóa (QAT).
- **Train thêm epoch trên cùng dữ liệu không giúp nhiều**: lite-v1 đạt đỉnh ở epoch 33/45, sau đó chỉ số validation đi ngang (F1 0,89). Cải thiện đến từ dữ liệu sát thực tế hơn, dải cỡ tôm khi train, và cách ghép tâm.
- lite-v1 hay tách một con dài thành nhiều mảnh (cửa sổ đỉnh 3 ô) và sót tôm dưới 48 px hoặc trên 320 px ở cỡ ảnh đưa vào model.

## 8. Độ đầy ruột

`pipeline/gut.py`: tôm nhìn từ trên, ruột đầy là đường tối dọc giữa phần bụng (35–90% chiều dài tính từ đầu). Chỉ số = phần chiều dài bụng có đường tối; mức rỗng < 0,3, đầy > 0,7; `not_observable` khi thân quá tối hoặc quá hẹp (< 7 px).

Ý tưởng theo Connection Science 2023 (doi 10.1080/09540091.2023.2268878) và Aquaculture Reports 2025 (doi 10.1016/j.aqrep.2025.103137, báo > 87% trên ảnh khay). Chỉ đọc được tóm tắt.

Trạng thái: **thử nghiệm, chưa kiểm chứng**. Trên 435 con test khay, 412 con đọc được; xem bằng mắt thấy hợp lý ở phần lớn nhưng sai ở tôm nằm nghiêng và ảnh nhòe. Cách kiểm chứng đề xuất: chụp cùng một khay trước khi cho ăn và sau khi ăn 30–60 phút, chỉ số phải tăng rõ.

## 9. Việc chưa làm và rủi ro

- Chưa chạy trên điện thoại thật nào. Mọi số tốc độ là ONNX Runtime trên CPU PC (i7-13650HX).
- Chưa có bộ test thực địa; chưa có định nghĩa chỉ số cho mục tiêu 97%.
- Bước hiệu chỉnh marker (ảnh chuẩn, px/cm) chưa có; chưa biết kích thước khay.
- Phép đo chiều dài từ mask chưa đối chiếu với thước thật. Vạch thước trong bảng đọc bằng mắt từ ảnh (±0,2 cm).
- Chưa nhận loài. Độ đầy ruột chưa kiểm chứng.
- Code ghép tâm phía app (Dart/Kotlin/Swift) chưa viết; `model.py:decode` là bản tham chiếu.
- Chưa tích hợp gì vào app Flutter. Cần người dùng duyệt kết quả trước.
