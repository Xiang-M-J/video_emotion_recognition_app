import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:verapp/utils/emotion_labels.dart';
import 'package:verapp/utils/emotion_recognition.dart';
import 'package:verapp/utils/image_converter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '情感识别',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '情感识别'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

Future<void> _showAlertDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('警告'),
        content: const Text('试用结束'),
        actions: <Widget>[
          TextButton(
            child: const Text('确定', style: TextStyle(color: Colors.blue)),
            onPressed: () {
              Navigator.pop(context, '确定');
            },
          ),
        ],
      );
    },
  );
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? _controller;
  bool _isRecording = false;
  bool isPaid = false;

  // For sine wave animation
  final List<FlSpot> _points = [];
  Timer? _timer;
  Timer? _cTimer;
  Duration _recordingDuration = Duration.zero;
  final Duration _maxRecordingDuration = const Duration(seconds: 1 * 10);

  double _time = 0;

  EmotionRecognizer? emotionRecognizer;

  List<CameraDescription> _cameras = [];

  bool isControllerInitialized = false;

  final List<CameraImage> _frameBuffer = [];

  void _onNewFrame(CameraImage image) async {
    // 限制最多保留 30 帧
    if (_frameBuffer.length >= 30) {
      _frameBuffer.removeAt(0);
    }
    // List<Uint8List> imageData = getDatafromCameraImage(image);
    _frameBuffer.add(image);
    // print(_frameBuffer.length);
    int? result = await emotionRecognizer?.predictAsync(image);
    if (result != null) print(emoLabels[result]);
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startSineWave();
    emotionRecognizer = EmotionRecognizer();
    _initModel();
  }

  void _initModel() async{
    await emotionRecognizer?.initModel();

  }

  void _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.medium,
    );
    // await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _startSineWave() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _time += 0.1;
        _points.add(FlSpot(_time, sin(_time)));

        // 保持最多100个点
        if (_points.length > 100) {
          _points.removeAt(0);
        }
      });
    });
  }

  void _stopRecording() async {
    if (_controller != null && _isRecording) {
      await _controller!.stopImageStream();
      setState(() {
        _isRecording = false;
      });
      _cTimer?.cancel();
      _cTimer = null;
    }
  }

  void _startRecording() async {
    if (!isPaid && _recordingDuration >= _maxRecordingDuration) {
      if (mounted) {
        _showAlertDialog(context);
      }
      return;
    }

    if (!isControllerInitialized) {
      await _controller!.initialize();
      isControllerInitialized = true;
    }

    if (_controller != null && !_isRecording) {
      // await _controller!.startVideoRecording();
      await _controller!.startImageStream(_onNewFrame);
      setState(() {
        _isRecording = true;
      });

      if (!isPaid) {
        _cTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
            if (_recordingDuration >= _maxRecordingDuration) {
              _stopRecording();
              _showAlertDialog(context);
            }
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    _cTimer?.cancel();
    emotionRecognizer?.release();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isRecording) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Text(
            '未开始录制',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }
    return CameraPreview(_controller!);
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        minX: _points.isNotEmpty ? _points.first.x : 0,
        maxX: _points.isNotEmpty ? _points.last.x : 10,
        minY: -1,
        maxY: 1,
        lineBarsData: [
          LineChartBarData(
            spots: _points,
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
          ),
        ],
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Column(
            children: [
              SizedBox(
                height: 0.02 * height,
              ),
              // 摄像头区域（40%）
              SizedBox(
                height: height * 0.58,
                child: _buildCameraPreview(),
              ),

              // 图表区域（30%）
              SizedBox(
                height: height * 0.2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildChart(),
                ),
              ),

              // 按钮区域（30%）
              SizedBox(
                height: height * 0.2,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _startRecording,
                        child: const Text('开始录制'),
                      ),
                      ElevatedButton(
                        onPressed: _stopRecording,
                        child: const Text('停止录制'),
                      ),
                      ElevatedButton(
                        onPressed: _startRecording,
                        child: const Text('导出文件'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
