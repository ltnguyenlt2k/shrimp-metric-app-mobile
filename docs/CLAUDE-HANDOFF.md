# Bàn giao ShrimpMetric cho Claude Code

## Phạm vi và nguyên tắc

- App Flutter cho iPhone và Android, phát triển và kiểm thử Android trước. Dùng cửa sổ Android Emulator trực tiếp trên Windows qua WSLg. Đọc AGENTS.md và skill dùng chung trước khi sửa app.
- Baseline UI được duyệt tại `638e9bb`, với chỉnh sửa riêng đã được yêu cầu tại `d492531`. Mọi thay đổi bố cục, nhãn, điều khiển và điều hướng cần người dùng duyệt trước.
- Giữ toàn bộ mã, kiểm thử và bản xuất AI trong `shrimp-pipeline/`. Người dùng duyệt kết quả từng model trước khi tích hợp. Ưu tiên chính xác, độ trễ thấp, dung lượng nhỏ và ít nóng khi dùng lặp lại. Ghi nguồn, phiên bản và điều khoản riêng cho ảnh, nhãn, checkpoint và mã. Không tự đăng ký dịch vụ có phí.
- Sau mỗi phần đã kiểm chứng, lưu baseline commit theo quy trình của repo.

## App đã có

- M2 có camera theo yêu cầu, quyền hệ điều hành được hỏi khi vào Chụp mẫu, lấy 5–6 frame trong khoảng 1,8 giây và lưu một ảnh đại diện. Luồng offline đã thử trên AVD Android. Chỉ số hiện là mô phỏng. Hiệu năng và chất lượng camera trên máy thật còn chờ đo.
- Commit nền quan trọng: `36a4d1f` camera đa frame, `d492531` chỉnh hiển thị camera/kết quả, `c291b5f` quyền camera và ghi quyết định AI, `1df7f97` baseline huấn luyện, `cfd60d9` review ảnh khay, `8ac8387` tiêu chí detector và loài.

## AI đã làm và đã chốt

- Đọc [APP-NOTES.md](../APP-NOTES.md), [hướng dẫn AI](../shrimp-pipeline/README.md), [bộ test và báo cáo](../shrimp-pipeline/tests/README.md). Bản nghiên cứu gốc `hybrid-ai-pipeline-phan-tich-tom.md` ở root hiện là file cục bộ chưa theo dõi bởi Git.
- Mỗi lượt lấy 5–6 frame của một khay chứa một loài. Lọc frame lỗi, phát hiện từng cá thể bằng box hoặc mask kèm box, cắt ảnh từng con đủ rõ rồi phân loại tôm sú/tôm thẻ. Tổng hợp một loài cấp khay hoặc chưa xác định. Đếm riêng từng frame hợp lệ rồi lấy trung bình. Box hiển thị thuộc ảnh đại diện.
- V1 là model điểm tâm, không xuất box hoặc loài. Bản ONNX lưu trọng số FP16 khoảng 440 KB, MAE 1,49 con trên 130 ảnh benchmark. Kết quả này không đại diện cho ảnh khay thực tế. Trên 7 ảnh khay PL, v1 chỉ trả 1–2 con/ảnh, bỏ sót rõ rệt. Hồi quy cân nặng tôm thẻ cho MAE 2,91 g từ **chiều dài đo tay**, chưa xác nhận đo cân nặng end-to-end từ ảnh.
- Review thực tế cần ảnh nguyên khay lấy mẫu có nước chụp từ trên xuống, có nhiều con và trải từ PL đến thương phẩm. Ảnh ngoài ao, sàng lưới và ảnh từng cá thể chỉ phục vụ benchmark phụ. Để đo chính xác cần nhãn đối chứng từng con. Loài cần kiểm riêng trên hai loài chụp trong điều kiện tương đương.

## Tệp cục bộ và việc tiếp theo

- `shrimp-pipeline/data/raw/` có ba archive. `checkpoints/pretrained/` có RTMDet-Ins-tiny, RTMDet-tiny, MobileNetV3-Small. `artifacts/count-v1/`, `artifacts/weight-v1/` có model, báo cáo thô và video. Các binary nằm ngoài Git, cùng máy dùng lại trực tiếp. Nếu khác máy, lấy URL/SHA-256 ở `registry/` và chạy lại theo `tests/README.md`.
- Một ứng viên nguồn để kiểm tra tiếp là [Do Size Tom v1](https://universe.roboflow.com/nguyen-hai-dang-10csz/do-size-tom/dataset/1/images). Nguồn này xuất hiện trong tab trình duyệt, chưa được xác minh hoặc nhập. Kiểm ảnh gốc, nhãn, loài/cỡ, quyền tải và giấy phép trước.
- Việc tiếp theo là kiểm kê và chốt bộ ảnh khay có nhãn, chia theo phiên/lô để tránh rò rỉ, rồi thử detector xuất box trong workspace AI. Video review cần phân biệt box dự đoán, box đối chứng, con bỏ sót và vùng báo nhầm. Báo metric theo cỡ, loài, mật độ, kèm dung lượng và độ trễ trên cùng thiết bị. Nhánh phân loại loài đánh giá riêng và sau đó kiểm cả chuỗi. Chờ người dùng duyệt trước khi gắn model vào Flutter.
