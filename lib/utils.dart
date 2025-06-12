import 'package:fluttertoast/fluttertoast.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

void showToast(String msg) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      timeInSecForIosWeb: 1,
      fontSize: 16.0);
}


/// 自定义类，仿 CameraImage
class MyCameraImage {
  final int format;
  final int height;
  final int width;
  final List<MyPlane> planes;
  final double? lensAperture;
  final int? sensorExposureTime;
  final double? sensorSensitivity;

  MyCameraImage({
    required this.format,
    required this.height,
    required this.width,
    required this.planes,
    required this.lensAperture,
    required this.sensorExposureTime,
    required this.sensorSensitivity
  });

  /// 从 CameraImage 创建
  factory MyCameraImage.from(CameraImage image) {
    return MyCameraImage(
      format: image.format.raw,
      height: image.height,
      width: image.width,
      planes: image.planes.map((p) => MyPlane.from(p)).toList(),
      lensAperture: image.lensAperture,
      sensorExposureTime: image.sensorExposureTime,
      sensorSensitivity: image.sensorSensitivity,
    );
  }

  /// 转 JSON
  Map<String, dynamic> toJson() {
    return {
      'format': format,
      'height': height,
      'width': width,
      'planes': planes.map((p) => p.toJson()).toList(),
      'lensAperture': lensAperture,
      'sensorExposureTime': sensorExposureTime,
      'sensorSensitivity': sensorSensitivity
    };
  }

  /// 从 JSON 创建
  factory MyCameraImage.fromJson(Map<String, dynamic> json) {
    return MyCameraImage(
      format: json['format'],
      height: json['height'],
      width: json['width'],
      planes: (json['planes'] as List)
          .map((p) => MyPlane.fromJson(p))
          .toList(),
      lensAperture: json['lensAperture'],
      sensorExposureTime: json['sensorExposureTime'],
      sensorSensitivity: json['sensorSensitivity']
    );
  }

  /// 保存到本地文件（返回路径）
  Future<String> saveToFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsString(jsonEncode(toJson()));
    return filePath;
  }

  /// 从本地文件读取
  static Future<MyCameraImage> loadFromFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    return MyCameraImage.fromJson(jsonDecode(jsonStr));
  }
}

/// 仿 Plane
class MyPlane {
  final Uint8List bytes;
  final int? bytesPerPixel;
  final int bytesPerRow;
  final int height;
  final int width;

  MyPlane({
    required this.bytes,
    required this.bytesPerPixel,
    required this.bytesPerRow,
    required this.height,
    required this.width,
  });

  factory MyPlane.from(Plane p) {
    return MyPlane(
      bytes: Uint8List.fromList(p.bytes),
      bytesPerPixel: p.bytesPerPixel ?? 1,
      bytesPerRow: p.bytesPerRow,
      height: p.height ?? 0,
      width: p.width ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bytes': base64Encode(bytes), // base64 编码保存二进制
      'bytesPerPixel': bytesPerPixel,
      'bytesPerRow': bytesPerRow,
      'height': height,
      'width': width,
    };
  }

  factory MyPlane.fromJson(Map<String, dynamic> json) {
    return MyPlane(
      bytes: base64Decode(json['bytes']),
      bytesPerPixel: json['bytesPerPixel'],
      bytesPerRow: json['bytesPerRow'],
      height: json['height'],
      width: json['width'],
    );
  }
}
