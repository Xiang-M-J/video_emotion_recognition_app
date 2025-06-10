import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
// import "package:opencv_dart/opencv.dart" as cv;

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

Float32List uint2Float(Uint8List u8data){
  int length = u8data.length;
  List<double> ddata = List.filled(length, 0.0);
  for (var i = 0; i < u8data.length; i++) {
    ddata[i] = u8data[i] / 255.0;
  }
  return Float32List.fromList(ddata);
}