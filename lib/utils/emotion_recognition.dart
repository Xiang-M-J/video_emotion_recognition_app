import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:onnxruntime/onnxruntime.dart';
import "package:image/image.dart";

import 'package:verapp/utils/emotion_labels.dart';
import 'package:verapp/utils/type_converter.dart';
import 'package:verapp/utils/image_converter.dart';

class CameraInputImage {
  CameraImage image;
  DeviceOrientation deviceOrientation = DeviceOrientation.landscapeLeft;
  CameraLensDirection lensDirection = CameraLensDirection.front;
  int sensorOrientation = 0;

  CameraInputImage(this.image, this.deviceOrientation, this.lensDirection,
      this.sensorOrientation);
}

class EmotionRecognizer {
  OrtSessionOptions? _sessionOptions;
  OrtSession? _session;

  final int _imageSize = 48;

  FaceDetector? _detector;

  List<List<Float32List>>? detectedFaces;

  EmotionRecognizer();

  reset() {}

  release() {
    _sessionOptions?.release();
    _sessionOptions = null;
    _session?.release();
    _session = null;
    _detector?.close();
    _detector = null;
  }

  int maxIndex(List<double> values) {
    int index = 0;
    double preValue = -10000;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > preValue) {
        index = i;
        preValue = values[i];
      }
    }
    return index;
  }

  initModel() async {
    _sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    const assetFileName = 'assets/model.onnx';
    final rawAssetFile = await rootBundle.load(assetFileName);
    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, _sessionOptions!);
    initDetector();
  }

  initDetector() {
    _detector = FaceDetector(
        options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: false,
      enableContours: false,
    ));
  }

  initModelAsync() async {
    const assetFileName = 'assets/models/BiCifParaformer.quant.onnx';
    final rawAssetFile = await rootBundle.load(assetFileName);
    initDetector();
    return compute(_initModel, rawAssetFile);
  }

  bool _initModel(ByteData rawAssetFile) {
    _sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, _sessionOptions!);
    return true;
  }

  Future<int?> predictAsync(CameraInputImage cameraInputImage) {
    return compute(predict, cameraInputImage);
  }

  void detectFaces(CameraInputImage cameraInputImage) async {
    // faces.clear();
    if (detectedFaces != null) {
      detectedFaces?.clear();
      detectedFaces = null;
    }

    CameraImage image = cameraInputImage.image;
    DeviceOrientation deviceOrientation = cameraInputImage.deviceOrientation;
    CameraLensDirection lensDirection = cameraInputImage.lensDirection;
    int sensorOrientation = cameraInputImage.sensorOrientation;

    // final WriteBuffer allBytes = WriteBuffer();
    // for (var plane in image.planes) {
    //   allBytes.putUint8List(plane.bytes);
    // }
    // int bytesPerRow = image.planes[0].bytesPerRow;
    // InputImageFormat format = InputImageFormat.yuv420;
    double width = image.width.toDouble();
    double height = image.height.toDouble();

    // final inputImage = InputImage.fromBytes(
    //     bytes: allBytes.done().buffer.asUint8List(),
    //     metadata: InputImageMetadata(
    //         size: Size(width, height),
    //         rotation: InputImageRotation.rotation0deg,
    //         format: format,
    //         bytesPerRow: bytesPerRow));
    InputImage? inputImage = getInputImageFromCameraImage(
        image, deviceOrientation, lensDirection, sensorOrientation);
    if (inputImage == null) return;

    final faces = await _detector?.processImage(inputImage);
    if (faces != null && faces.isNotEmpty) {
      detectedFaces ??= List.empty(growable: true);
      Float32List data = convertYUVNV21toGray(image);
      for (var i = 0; i < faces.length; i++) {
        detectedFaces?.add(cropFaceFromImage(
            data, width.toInt(), height.toInt(), faces[i].boundingBox));
      }
    }
  }

  List<Float32List> cropandresizeFace(
      Float32List image, int srcWidth, int srcHeight, Rect faceRect) {
    final faceX = faceRect.left.round().clamp(0, srcWidth - 1);
    final faceY = faceRect.top.round().clamp(0, srcHeight - 1);
    final faceW = faceRect.width.round().clamp(1, srcWidth - faceX);
    final faceH = faceRect.height.round().clamp(1, srcHeight - faceY);

    final faceFlist = Float32List(faceW * faceH);

    for (int row = 0; row < faceH; row++) {
      for (int col = 0; col < faceW; col++) {
        int srcIndex = ((faceY + row) * srcWidth + (faceX + col));
        int dstIndex = (row * faceW + col);

        faceFlist[dstIndex] = image[srcIndex];
      }
    }

    // Image iimage = decodeImage(data);

    return [faceFlist];
  }

  Uint8List resizeImage(
      Uint8List inputBytes, int targetWidth, int targetHeight) {
    // 解码图像
    final image = decodeImage(inputBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // 缩放图像
    final resized = copyResize(image, width: targetWidth, height: targetHeight);

    // 编码为 PNG/JPEG
    final resizedBytes = encodePng(resized);
    return Uint8List.fromList(resizedBytes);
  }

  List<Float32List> cropFaceFromImage(
      Float32List image, int srcWidth, int srcHeight, Rect faceRect) {
    final faceX = faceRect.left.round().clamp(0, srcWidth - 1);
    final faceY = faceRect.top.round().clamp(0, srcHeight - 1);
    final faceW = faceRect.width.round().clamp(1, srcWidth - faceX);
    final faceH = faceRect.height.round().clamp(1, srcHeight - faceY);
    double scale;
    int pw = 0;
    int ph = 0;
    if (faceW >= faceH) {
      scale = _imageSize / (faceW * 1.0);
      ph = ((_imageSize - (faceH * scale).round()) / 2).round();
      if (ph < 0) {
        ph = 0;
      }
    } else {
      scale = _imageSize / (faceH * 1.0);
      pw = ((_imageSize - (faceW * scale).round()) / 2).round();
      if (pw < 0) {
        pw = 0;
      }
    }

    final faceFlist = List.filled(_imageSize,
        Float32List.fromList(List<double>.filled(_imageSize, 0.0))); // RGB

    for (int row = 0; row < faceH; row++) {
      for (int col = 0; col < faceW; col++) {
        int srcIndex = ((faceY + row) * srcWidth + (faceX + col));
        int dsth = ph + (scale * row).round();
        int dstw = pw + (scale * col).round();
        dsth = dsth.clamp(0, _imageSize - 1);
        dstw = dstw.clamp(0, _imageSize - 1);
        faceFlist[dsth][dstw] = image[srcIndex];
      }
    }

    return faceFlist;
  }

  // List<Float32List> reshapeMat(cv.Mat mat) {
  //   Uint8List matData = mat.data;
  //   List<Float32List> result = List.empty(growable: true);
  //   for (var i = 0; i < _imageSize; i++) {
  //     result.add(
  //         uint2Float(matData.sublist(i * _imageSize, (i + 1) * _imageSize)));
  //   }
  //   return result;
  // }

  int? predict(CameraInputImage image) {
    detectFaces(image);
    if (detectedFaces == null) {
      return null;
    }

    for (var i = 0; i < detectedFaces!.length; i++) {
      final inputOrt = OrtValueTensor.createTensorWithDataList(
          detectedFaces![i], [1, _imageSize, _imageSize, 1]);
      final runOptions = OrtRunOptions();
      final inputs = {'conv2d_1_input': inputOrt};
      final List<OrtValue?>? outputs;

      outputs = _session?.run(runOptions, inputs);

      if (outputs == null) {
        return null;
      }
      inputOrt.release();

      runOptions.release();

      /// Output probability & update h,c recursively
      final logits = (outputs[0]?.value as List<List<List<double>>>)[0];
      // final toke_num = (outputs[1]?.value as List<double>)[0];
      // final usAlphas = (outputs[2]?.value as List<List<double>>)[0];
      // final usCifPeak = (outputs[3]?.value as List<List<double>>)[0];

      for (var element in outputs) {
        element?.release();
      }
    }

    return 0;
  }

  List<List<double>> extractFbank(List<int> intData) {
    return List<List<double>>.empty();
  }
}
