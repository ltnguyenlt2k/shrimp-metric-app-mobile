---
name: shrimpmetric-mobile
description: Implement and verify ShrimpMetric Flutter screens and mobile features, including Android emulator reviews, camera and local image analysis, and milestone baselines.
---

# ShrimpMetric mobile workflow

- Check `docs/ROADMAP.md`, `docs/PLAN.md` and the relevant decision in `docs/ADR.md`. M1 is a navigable prototype using sample data. Review the overall layout and navigation with the user before wiring M2 features. Android is the first verification target for the shared Android/iOS app.
- In UI reviews, use the approved ShrimpMetric mark in `assets/branding/shrimpmetric-icon.png`. Make the sample image and count easy to read, check Vietnamese text, large text and safe areas, and capture the main flow at two phone sizes. Label demo results.
- Use the toolchain documented in `docs/DEVELOPMENT.md`. Run `flutter analyze` and `flutter test`, then verify affected flows on the emulator when available. Record the device, commands and outcome. Use a physical phone in profile or release mode for camera behavior, inference latency, memory and thermal measurements.
- Keep capture and inference on-device. Request camera access at capture time and release it when the capture session ends. Keep estimated and confirmed counts distinct. The first release's contribution button only explains its status. Avoid transmitting sample photos or their metadata until the contribution flow is implemented and approved.
- Record the source, version and license of new packages, model weights, datasets and UI assets. Preserve required notices in releases. Commit a baseline after each verified work unit when requested, recording any verification that remains pending.
