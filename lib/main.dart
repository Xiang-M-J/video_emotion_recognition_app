import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:verapp/utils.dart';
import 'package:verapp/utils/emotion_labels.dart';
import 'package:verapp/utils/emotion_recognition.dart';
import 'line_chart.dart';

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
  final Duration _maxRecordingDuration = const Duration(seconds: 1 * 60);

  double _time = 0;

  EmotionRecognizer? emotionRecognizer;

  List<CameraDescription> _cameras = [];

  bool isControllerInitialized = false;

  final List<List<String>> _storeData = List.empty(growable: true);

  final List<CameraImage> _frameBuffer = [];

  CameraDescription? bestCamera;

  String nowEmotion = "";
  int count = 0;
  int precount = 60;
  Stopwatch stopwatch = Stopwatch();

  void _onNewFrame(CameraImage image) async {
    // 限制最多保留 30 帧
    if (_frameBuffer.length >= 60) {
      _frameBuffer.removeAt(0);
    }
    // List<Uint8List> imageData = getDatafromCameraImage(image);

    if (precount <= 0) {
      _frameBuffer.add(image);
    } else {
      precount -= 1;
    }

    // print(_frameBuffer.length);
    if (_frameBuffer.length >= 60) {
      just_once(image);
    }
  }

  void predictOneImage(CameraImage image) async {
    int? result = emotionRecognizer?.predict(CameraInputImage(
        image,
        _controller!.value.deviceOrientation,
        bestCamera!.lensDirection,
        bestCamera!.sensorOrientation));

    if (result != null) {
      _storeData.add([getNowTime(), emoLabels[result]]);
      print(emoLabels[result]);
      setState(() {
        nowEmotion = emoLabels[result];
        _time += 0.5;
        _points.add(FlSpot(_time, result.toDouble()));

        if (_points.length > 30) {
          _points.removeAt(0);
        }
      });
    }
  }

  void just_once(CameraImage image) {
    if (count >= 1) {
      return;
    }
    count += 1;
    stopwatch.start();
    predictOneImage(image);
    stopwatch.stop();
    print(stopwatch.elapsedMilliseconds / 1000);
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    checkAndRequestPermission();
    // _startSineWave();
    emotionRecognizer = EmotionRecognizer();
    _initModel();
  }

  void _initModel() async {
    await emotionRecognizer?.initModel();
  }

  void _initializeCamera() async {
    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      showToast("未找到摄像头");
      return;
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.front) {
        bestCamera = _cameras[i];
        break;
      } else if (_cameras[i].lensDirection == CameraLensDirection.external) {
        bestCamera = _cameras[i];
      }
    }

    if (bestCamera != null) {
      bestCamera = _cameras[0];
    }

    // await _controller!.initialize();
    if (mounted) setState(() {});
  }

  // void _startSineWave() {
  //   _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
  //     setState(() {
  //       _time += 0.1;
  //       _points.add(FlSpot(_time, sin(_time)));

  //       // 保持最多100个点
  //       if (_points.length > 100) {
  //         _points.removeAt(0);
  //       }
  //     });
  //   });
  // }

  void _stopRecording() async {
    if (_controller != null && _isRecording) {
      await _controller!.stopImageStream();
      _controller?.dispose();
      _controller = null;
      // await _controller!.pausePreview();
      setState(() {
        _isRecording = false;
      });
      _cTimer?.cancel();
      _cTimer = null;
    }
  }

  String getNowTime() {
    DateTime dateTime = DateTime.now();
    return dateTime.toString();
  }

  void _startRecording() async {
    if (!isPaid && _recordingDuration >= _maxRecordingDuration) {
      if (mounted) {
        _showAlertDialog(context);
      }
      return;
    }

    ImageFormatGroup format = ImageFormatGroup.nv21;
    if (Platform.isIOS) {
      format = ImageFormatGroup.bgra8888;
    }

    _controller = CameraController(bestCamera!, ResolutionPreset.medium,
        enableAudio: false, fps: 24, imageFormatGroup: format);

    await _controller!.initialize();

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

  Future<void> checkAndRequestPermission() async {
    // 检查当前权限状态
    var status = await Permission.storage.status;
    if (status.isGranted) {
      // 权限已经授予
      print("storage permission granted.");
    } else if (status.isDenied) {
      // 请求权限
      PermissionStatus result = await Permission.storage.request();
      if (result.isGranted) {
        print("storage permission granted after request.");
      } else {
        print("storage permission denied.");
      }
    }

    status = await Permission.manageExternalStorage.request();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _timer?.cancel();
    _cTimer?.cancel();
    emotionRecognizer?.release();
    super.dispose();
  }

  Future<void> exportFile() async {
    const headers = "时间,情感\n";
    String content = "";

    for (var i = 0; i < _storeData.length; i++) {
      content += "${_storeData[i][0]}, ${_storeData[i][1]}\n";
    }
    final dir = await getExternalStorageDirectory();
    String filepath = '${dir?.parent.path}/${getNowTime()}.csv';
    final file = File(filepath);

    if (file.existsSync()) {
      await file.delete();
    }

    file.writeAsString(headers + content);

    showToast("文件已保存在$filepath");
  }

  Widget _buildCameraPreview() {
    // if (_controller == null || !_controller!.value.isInitialized) {
    //   return const Center(child: CircularProgressIndicator());
    // }
    if (!_isRecording ||
        _controller == null ||
        !_controller!.value.isInitialized) {
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

  // Widget _buildChart() {
  //   return LineChart(
  //     LineChartData(
  //       minX: _points.isNotEmpty ? _points.first.x : 0,
  //       maxX: _points.isNotEmpty ? _points.last.x : 10,
  //       minY: -1,
  //       maxY: 1,
  //       lineBarsData: [
  //         LineChartBarData(
  //           spots: _points,
  //           isCurved: true,
  //           color: Colors.green,
  //           barWidth: 2,
  //         ),
  //       ],
  //       titlesData: const FlTitlesData(show: true),
  //       gridData: const FlGridData(show: false),
  //       borderData: FlBorderData(show: false),
  //     ),
  //   );
  // }

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
                height: height * 0.48,
                child: _buildCameraPreview(),
              ),

              // 图表区域（30%）
              SizedBox(
                height: height * 0.3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: EmotionLineChart(spots: _points),
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
                        onPressed: exportFile,
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
