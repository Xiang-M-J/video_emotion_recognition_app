import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:yuv_converter/yuv_converter.dart';
// import "package:opencv_dart/opencv.dart" as cv;

final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

List<Uint8List> getDatafromCameraImage(CameraImage image) {
  List<Uint8List> data = List.empty(growable: true);
  List<Plane> planes = image.planes;
  for (var i = 0; i < planes.length; i++) {
    data.add(planes[i].bytes);
  }
  return data;
}

List<List<Uint8List>> convertYUV420toRGB2(CameraImage image) {
  final int width = image.width;
  final int height = image.height;

  final yRowStride = image.planes[0].bytesPerRow;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel!;

  final img =
      List.filled(height, List.filled(width, Uint8List.fromList([0, 0, 0])));

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
      final int indexY = y * yRowStride + x;

      final yp = image.planes[0].bytes[indexY];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];

      final yVal = yp.toDouble();
      final u = up.toDouble() - 128.0;
      final v = vp.toDouble() - 128.0;

      int r = (yVal + 1.370705 * v).round();
      int g = (yVal - 0.337633 * u - 0.698001 * v).round();
      int b = (yVal + 1.732446 * u).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      img[y][x][0] = r;
      img[y][x][1] = g;
      img[y][x][2] = b;
    }
  }
  return img;
}

Uint8List convertYUV420toRGB(CameraImage image) {
  final int width = image.width;
  final int height = image.height;

  final yRowStride = image.planes[0].bytesPerRow;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel!;

  final img = Uint8List(width * height * 3); // RGB 格式

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
      final int indexY = y * yRowStride + x;

      final yp = image.planes[0].bytes[indexY];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];

      final yVal = yp.toDouble();
      final u = up.toDouble() - 128.0;
      final v = vp.toDouble() - 128.0;

      int r = (yVal + 1.370705 * v).round();
      int g = (yVal - 0.337633 * u - 0.698001 * v).round();
      int b = (yVal + 1.732446 * u).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      final int index = (y * width + x) * 4;
      img[index + 0] = r;
      img[index + 1] = g;
      img[index + 2] = b;
    }
  }
  return img;
}

Float32List convertYUVNV21toGray(CameraImage image) {
  int width = image.width;
  int height = image.height;
  Uint8List src = image.planes[0].bytes;

  Float32List gray = Float32List(width * height);
  final nvStart = width * height;
  int index = 0, rgbaIndex = 0;
  int y, u, v;
  int r, g, b;
  int nvIndex = 0;

  for (int i = 0; i < height; i++) {
    for (int j = 0; j < width; j++) {
      nvIndex = (i ~/ 2 * width + j - j % 2).toInt();

      y = src[rgbaIndex];
      u = src[nvStart + nvIndex];
      v = src[nvStart + nvIndex + 1];

      // r = y + (140 * (v - 128)) ~/ 100; // r
      // g = y - (34 * (u - 128)) ~/ 100 - (71 * (v - 128)) ~/ 100; // g
      // b = y + (177 * (u - 128)) ~/ 100; // b
      r = y + (1.13983 * (v - 128)).toInt(); // r
      g = y -
          (0.39465 * (u - 128)).toInt() -
          (0.58060 * (v - 128)).toInt(); // g
      b = y + (2.03211 * (u - 128)).toInt(); // b

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      // index = rgbaIndex % width + (height - i - 1) * width;
      index = rgbaIndex % width + i * width;
      
      gray[index] = 0.299 * r / 255.0 + 0.587 * g / 255.0 + 0.114 * b / 255.0;
      rgbaIndex++;
    }
  }

  return gray;
}

Float32List convertYUV420toGray(CameraImage image) {
  final int width = image.width;
  final int height = image.height;

  final yRowStride = image.planes[0].bytesPerRow;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel!;

  final img = Float32List(width * height); // Gray 格式

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
      final int indexY = y * yRowStride + x;

      final yp = image.planes[0].bytes[indexY];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];

      final yVal = yp.toDouble();
      final u = up.toDouble() - 128.0;
      final v = vp.toDouble() - 128.0;

      int r = (yVal + 1.370705 * v).round();
      int g = (yVal - 0.337633 * u - 0.698001 * v).round();
      int b = (yVal + 1.732446 * u).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      final int index = (y * width + x);
      img[index] = 0.299 * r / 255.0 + 0.587 * g / 255.0 + 0.114 * b / 255.0;
    }
  }
  return img;
}

Float32List uint2Float(Uint8List u8data) {
  int length = u8data.length;
  List<double> ddata = List.filled(length, 0.0);
  for (var i = 0; i < u8data.length; i++) {
    ddata[i] = u8data[i] / 255.0;
  }
  return Float32List.fromList(ddata);
}

InputImage? getInputImageFromCameraImage(
    CameraImage image,
    DeviceOrientation deviceOrientation,
    CameraLensDirection lensDirection,
    int sensorOrientation) {
  // get image rotation
  // it is used in android to convert the InputImage from Dart to Java: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/android/src/main/java/com/google_mlkit_commons/InputImageConverter.java
  // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_commons/ios/Classes/MLKVisionImage%2BFlutterPlugin.m
  // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
  // print(
  //     'lensDirection: ${camera.lensDirection}, sensorOrientation: $sensorOrientation, ${_controller?.value.deviceOrientation} ${_controller?.value.lockedCaptureOrientation} ${_controller?.value.isCaptureOrientationLocked}');
  InputImageRotation? rotation;
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var rotationCompensation = _orientations[deviceOrientation];
    if (rotationCompensation == null) return null;
    if (lensDirection == CameraLensDirection.front) {
      // front-facing
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      // back-facing
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    // print('rotationCompensation: $rotationCompensation');
  }
  if (rotation == null) return null;
  // print('final rotation: $rotation');

  // get image format
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  // validate format depending on platform
  // only supported formats:
  // * nv21 for Android
  // * bgra8888 for iOS
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) {
    return null;
  }

  // since format is constraint to nv21 or bgra8888, both only have one plane
  if (image.planes.length != 1) return null;
  final plane = image.planes.first;

  // compose InputImage using bytes
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation, // used only in Android
      format: format, // used only in iOS
      bytesPerRow: plane.bytesPerRow, // used only in iOS
    ),
  );
}
