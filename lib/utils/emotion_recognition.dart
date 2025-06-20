import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:onnxruntime/onnxruntime.dart';
import "package:image/image.dart";
import "package:image/image.dart" as img;
import 'package:verapp/utils.dart';

import 'package:verapp/utils/image_converter.dart';

class CameraInputImage {
  MyCameraImage image;
  DeviceOrientation deviceOrientation = DeviceOrientation.landscapeLeft;
  CameraLensDirection lensDirection = CameraLensDirection.front;
  int sensorOrientation = 0;

  CameraInputImage(this.image, this.deviceOrientation, this.lensDirection,
      this.sensorOrientation);
}

class RecognitionResult {
  List<List<Float32List>> detectedFaces;
  List<Rect> rects;

  RecognitionResult(this.detectedFaces, this.rects);
}

class PredictResult{
  List<List<double>> probs;
  List<int> emoIdx;
  List<Rect> rects;
  PredictResult(this.probs, this.emoIdx, this.rects);
}

class EmotionRecognizer {
  OrtSessionOptions? _sessionOptions;
  OrtSession? _session;

  final int _imgSize = 48;

  FaceDetector? _detector;

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
    const assetFileName = 'assets/model.onnx';
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

  Future<PredictResult?> predictAsync(CameraInputImage cameraInputImage) {
    return compute(predict, cameraInputImage);
  }
  
  Future<RecognitionResult?> detectFaces(CameraInputImage cameraInputImage) async {
    // faces.clear()

    MyCameraImage image = cameraInputImage.image;
    DeviceOrientation deviceOrientation = cameraInputImage.deviceOrientation;
    CameraLensDirection lensDirection = cameraInputImage.lensDirection;
    int sensorOrientation = cameraInputImage.sensorOrientation;

    InputImage? inputImage = getInputImageFromCameraImage(
        image, deviceOrientation, lensDirection, sensorOrientation);
    if (inputImage == null) return null;

    final faces = await _detector?.processImage(inputImage);
    if (faces != null && faces.isNotEmpty) {
      List<List<Float32List>> detectedFaces = List.empty(growable: true);
      Uint8List rgbImg = convertYUVNV21toRGB(image);
      List<Rect> rects = [];
      for (var i = 0; i < faces.length; i++) {
        detectedFaces.add(cropandresizeFace(
            rgbImg, image.width, image.height, faces[i].boundingBox));
        rects.add(faces[i].boundingBox);
      }
      return RecognitionResult(detectedFaces, rects);
      
    }
    return null;
  }

  List<Float32List> cropandresizeFace(
      Uint8List imageData, int srcWidth, int srcHeight, Rect faceRect) {
    final faceX = faceRect.left.toInt();
    final faceY = faceRect.top.toInt();
    final faceW = faceRect.width.toInt();
    final faceH = faceRect.height.toInt();

    final image = img.Image.fromBytes(width: srcWidth, height: srcHeight, bytes: imageData.buffer);
    final rotateImage = img.copyRotate(image, angle:  270);
    final cropImage = img.copyCrop(rotateImage, x: faceX, y: faceY, width: faceW, height: faceH);
    final resizeImage = copyResize(cropImage, width: _imgSize, height: _imgSize);

    final src = Uint8List.view(resizeImage.buffer);
    final gray = grayscale2(src, _imgSize, _imgSize);

    final reshapedFace = reshapeImage(gray, _imgSize, _imgSize);

    return reshapedFace;
  }

  Uint8List cropandresizeFace2(
      Uint8List image, int srcWidth, int srcHeight, Rect faceRect) {
    final faceX = faceRect.left.toInt();
    final faceY = faceRect.top.toInt();
    final faceW = faceRect.width.toInt();
    final faceH = faceRect.height.toInt();

    final image2 = img.Image.fromBytes(width: srcWidth, height: srcHeight, bytes: image.buffer);
    final image3 = img.copyRotate(image2, angle:  270);
    final image4 = img.copyCrop(image3, x: faceX, y: faceY, width: faceW, height: faceH);

    // 缩放图像
    final resized = copyResize(image4, width: _imgSize, height: _imgSize);
    final grayImg = grayscale(resized);

    final pngBytes = Uint8List.fromList(img.encodePng(grayImg));

    return pngBytes;
  }

  List<Float32List> reshapeImage(Float32List src, int width, int height) {
    List<Float32List> result = List.empty(growable: true);
    for (var i = 0; i < height; i++) {
      result.add((src.sublist(i * width, (i + 1) * width)));
    }
    return result;
  }

  Float32List resizeImage(Uint8List inputBytes, int srcWidth, int srcHeight,
      int targetWidth, int targetHeight) {
    // 解码图像
    final image = img.Image.fromBytes(
        width: srcWidth,
        height: srcHeight,
        bytes: inputBytes.buffer,
        numChannels: 3);

    // 缩放图像
    final resized = copyResize(image, width: targetWidth, height: targetHeight);
    // img.getLuminance(img.Color.r)
    final grayImg = grayscale(resized);
    final src = Uint8List.view(resized.buffer);
    final gray = grayscale2(src, targetWidth, targetHeight);
    return gray;
  }

  Float32List grayscale2(Uint8List src, int width, int height){
     final gray = Float32List(width * height);

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        int srcIndex = (row * width + col) * 3;
        int dstIndex = (row * width + col);
        int r = src[srcIndex];
        int g = src[srcIndex+1];
        int b = src[srcIndex+2];
        gray[dstIndex] = 0.299 * r / 255.0 + 0.587 * g / 255.0 + 0.114 * b / 255.0;
      }
    }

    return gray;
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
      scale = _imgSize / (faceW * 1.0);
      ph = ((_imgSize - (faceH * scale).round()) / 2).round();
      if (ph < 0) {
        ph = 0;
      }
    } else {
      scale = _imgSize / (faceH * 1.0);
      pw = ((_imgSize - (faceW * scale).round()) / 2).round();
      if (pw < 0) {
        pw = 0;
      }
    }

    final faceFlist = List.filled(_imgSize,
        Float32List.fromList(List<double>.filled(_imgSize, 0.0))); // RGB

    for (int row = 0; row < faceH; row++) {
      for (int col = 0; col < faceW; col++) {
        int srcIndex = ((faceY + row) * srcWidth + (faceX + col));
        int dsth = ph + (scale * row).round();
        int dstw = pw + (scale * col).round();
        dsth = dsth.clamp(0, _imgSize - 1);
        dstw = dstw.clamp(0, _imgSize - 1);
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

  Future<Uint8List?> getface(CameraInputImage cameraInputImage) async{
    MyCameraImage image = cameraInputImage.image;
    DeviceOrientation deviceOrientation = cameraInputImage.deviceOrientation;
    CameraLensDirection lensDirection = cameraInputImage.lensDirection;
    int sensorOrientation = cameraInputImage.sensorOrientation;

    InputImage? inputImage = getInputImageFromCameraImage(
        image, deviceOrientation, lensDirection, sensorOrientation);
    if (inputImage == null) return null;

    final faces = await _detector?.processImage(inputImage);
    if (faces != null && faces.isNotEmpty) {
      Uint8List rgbImg = convertYUVNV21toRGB(image);
      
      return cropandresizeFace2(
            rgbImg, image.width, image.height, faces[0].boundingBox);
    }
    return null;
  }

  Future<PredictResult?> predict(CameraInputImage image) async {
    RecognitionResult? results = await detectFaces(image);
    if (results == null) {
      return null;
    }
    List<List<Float32List>> detectedFaces = results.detectedFaces;
    List<Rect> rects = results.rects;
    List<int> emoIdx = [];
    List<List<double>> probs = [];
    int index = 0;
    for (var i = 0; i < detectedFaces.length; i++) {
      final inputOrt = OrtValueTensor.createTensorWithDataList(
          detectedFaces[i], [1, _imgSize, _imgSize, 1]);
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
      final logits = (outputs[0]?.value as List<List<double>>)[0];
      // final toke_num = (outputs[1]?.value as List<double>)[0];
      // final usAlphas = (outputs[2]?.value as List<List<double>>)[0];
      // final usCifPeak = (outputs[3]?.value as List<List<double>>)[0];
      index = maxIndex(logits);
      for (var element in outputs) {
        element?.release();
      }
      probs.add(logits);
      emoIdx.add(index);
    }
    return PredictResult(probs, emoIdx, rects);
  }

}
