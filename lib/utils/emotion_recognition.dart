import 'dart:ffi';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:opencv_dart/opencv.dart' as cv;
import 'package:opencv_dart/opencv_dart.dart';
import 'package:verapp/utils/emotion_labels.dart';
import 'package:verapp/utils/type_converter.dart';
import 'package:verapp/utils/image_converter.dart';

class EmotionRecognizer {
  OrtSessionOptions? _sessionOptions;
  OrtSession? _session;

  cv.CascadeClassifier? cascadeClassifier;

  final int _imageSize = 48;

  EmotionRecognizer();

  reset() {}

  release() {
    _sessionOptions?.release();
    _sessionOptions = null;
    _session?.release();
    _session = null;

    cascadeClassifier?.dispose();
    cascadeClassifier = null;
  }

  initClassifier() {
    const xmlFileName = "assets/haarcascade_frontalface_default.xml";
    cascadeClassifier = cv.CascadeClassifier.fromFile(xmlFileName);
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
    initClassifier();
  }

  initModelAsync() async {
    const assetFileName = 'assets/models/BiCifParaformer.quant.onnx';
    final rawAssetFile = await rootBundle.load(assetFileName);
    initClassifier();
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

  Future<int?> predictAsync(CameraImage image) {
    return compute(predict, image);
  }

  List<Float32List> reshapeMat(cv.Mat mat) {
    Uint8List matData = mat.data;
    List<Float32List> result = List.empty(growable: true);
    for (var i = 0; i < _imageSize; i++) {
      result.add(
          uint2Float(matData.sublist(i * _imageSize, (i + 1) * _imageSize)));
    }
    return result;
  }

  int? predict(CameraImage image) {
    Uint8List rgbData = convertYUV420toRGB(image);

    cv.Mat mat = cv.imdecode(rgbData, cv.IMREAD_GRAYSCALE);

    cv.VecRect? faceRects = cascadeClassifier?.detectMultiScale(mat,
        scaleFactor: 1.2, minNeighbors: 3, minSize: (32, 32));
    if (faceRects == null || faceRects.isEmpty) return null;

    for (var i = 0; i < faceRects.length; i++) {
      List<double> rs_sum = List.filled(emoNumClass, 0.0);
      cv.Mat cutMat = cv.Mat.fromMat(mat, copy: true, roi: faceRects[i]);
      cutMat = cv.resize(cutMat, (_imageSize, _imageSize));
      List<Mat> imgs = [];
      imgs.add(cutMat);
      for (var img in imgs) {
        List<Float32List> flist = reshapeMat(img);
        final inputOrt = OrtValueTensor.createTensorWithDataList(
            flist, [1, _imageSize, _imageSize, 1]);
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
    }

    return 0;
  }

  List<List<double>> extractFbank(List<int> intData) {
    return List<List<double>>.empty();
  }
}
