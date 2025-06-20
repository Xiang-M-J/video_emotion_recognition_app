import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:verapp/utils/emotion_labels.dart';

class FacePainter extends CustomPainter {
  FacePainter(
      {required this.imageSize,
      required this.rects,
      required this.emoIdx,
      required this.cameraLensDirection});
  final Size imageSize;
  double? scaleX, scaleY;
  final List<Rect> rects;
  final List<int> emoIdx;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (rects.isEmpty) return;

    Paint paint;

    paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    scaleX = size.width / imageSize.width;
    scaleY = size.height / imageSize.height;

    for (var i = 0; i < rects.length; i++) {
      int idx = emoIdx[i];
      Rect rect = rects[i];

      rect = _scaleRect(
          rect: rect,
          widgetSize: size,
          cameraLensDirection: cameraLensDirection,
          scaleX: scaleX,
          scaleY: scaleY);
      canvas.drawRect(rect, paint);

      _drawTextInsideRect(canvas, rect, emoLabels[idx]);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.rects != rects;
  }
}

void _drawTextInsideRect(Canvas canvas, Rect rect, String text) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        backgroundColor: Colors.black54,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  textPainter.layout();

  // 文字起始绘制点（这里放在矩形左上角稍微偏下，避免贴边）
  final offset = Offset(rect.left - 36, rect.top + 12);

  textPainter.paint(canvas, offset);
}

Rect _scaleRect(
    {required Rect rect,
    required Size widgetSize,
    required CameraLensDirection cameraLensDirection,
    double? scaleX,
    double? scaleY}) {

  if (cameraLensDirection == CameraLensDirection.front) {
    return Rect.fromLTRB(
        (widgetSize.width - rect.left.toDouble() * scaleX!).clamp(0, widgetSize.width),
        rect.top.toDouble() * scaleY!,
        (widgetSize.width - rect.right.toDouble() * scaleX).clamp(0, widgetSize.width),
        rect.bottom.toDouble() * scaleY);
  } else {
    return Rect.fromLTRB(
        (rect.left.toDouble() * scaleX!).clamp(0, widgetSize.width),
        rect.top.toDouble() * scaleY!,
        (rect.right.toDouble() * scaleX).clamp(0, widgetSize.width),
        rect.bottom.toDouble() * scaleY);
  }
}
