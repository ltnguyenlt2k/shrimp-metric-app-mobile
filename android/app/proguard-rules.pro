# ONNX Runtime's native code looks up its Java classes and fields by name.
# Without this the release build crashes inside OrtSession.run.
-keep class ai.onnxruntime.** { *; }
