import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:verapp/bar_chart.dart';
import 'package:verapp/face_painter.dart';
import 'package:verapp/utils.dart';
import 'package:verapp/utils/emotion_labels.dart';
import 'package:verapp/utils/emotion_recognition.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isRecording = false;
  bool isPaid = false;

  Timer? _recordTimer;
  Duration _recordingDuration = Duration.zero;
  final Duration _maxRecordingDuration = const Duration(seconds: 5 * 60);

  EmotionRecognizer? emotionRecognizer;

  List<CameraDescription> _cameras = [];

  final List<List<String>> _storeData = List.empty(growable: true);

  Uint8List face = Uint8List.fromList(List<int>.generate(2304, (i) => 0));

  CameraDescription? bestCamera;

  double aspectRatio = 1.0;

  List<Rect> rects = [];
  List<int> emoIdx = [];
  List<List<double>> probs = [];

  int fps = 24;
  int cycleCnt = 0;
  int cycle = 6;
  double timestep = 0.25;
  Stopwatch stopwatch = Stopwatch();

  ImageFormatGroup format = ImageFormatGroup.nv21;

  /// 录制时的回调函数
  void _onNewFrame(CameraImage image) async {
    if (cycleCnt < cycle) {
      cycleCnt += 1;
    } else {
      MyCameraImage myImage = MyCameraImage.from(image);
      predictOneFrame(myImage);
      cycleCnt = 0;
    }
  }

  /// 预测一帧
  void predictOneFrame(MyCameraImage image) async {
    PredictResult? result = await emotionRecognizer?.predict(CameraInputImage(
        image,
        _controller!.value.deviceOrientation,
        bestCamera!.lensDirection,
        bestCamera!.sensorOrientation));

    if (result != null) {
      for (var i = 0; i < result.emoIdx.length; i++) {
        _storeData.add([getNowTime(), emoLabels[result.emoIdx[i]]]);
      }
      // print(emoLabels[result]);
      setState(() {
        rects = result.rects;
        probs = result.probs;
        emoIdx = result.emoIdx;
      });
    } else {
      setState(() {
        rects = [];
      });
    }
  }

  /// 预测脸的图片
  void predictFace(MyCameraImage image) async {
    Uint8List? result = await emotionRecognizer?.getface(CameraInputImage(
        image,
        _controller!.value.deviceOrientation,
        bestCamera!.lensDirection,
        bestCamera!.sensorOrientation));
    if (result != null) {
      setState(() {
        face = result;
      });
    }
  }

  /// 保存一帧
  void saveFrame(CameraImage image) async {
    final dir = await getExternalStorageDirectory();
    String filepath = '${dir?.parent.path}/frame.json';
    MyCameraImage myImage = MyCameraImage.from(image);
    myImage.saveToFile(filepath);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkAndRequestPermission();
    _initializeCamera();
    _initModel();

    if (Platform.isIOS) {
      format = ImageFormatGroup.bgra8888;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 熄屏或切后台时释放资源
      if (_isRecording) {
        _stopRecording();
      }

      // _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      // 恢复时重新初始化相机
      // _startRecording();
    }
  }

  void _initModel() async {
    emotionRecognizer = EmotionRecognizer();
    await emotionRecognizer?.initModel();
  }

  void _initializeCamera() async {
    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      showToast("未找到摄像头");
      return;
    }
    // 优先选择前置摄像头，其次是外置摄像头，最后选择背面的摄像头
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.front) {
        bestCamera = _cameras[i];
        break;
      } else if (_cameras[i].lensDirection == CameraLensDirection.external) {
        bestCamera = _cameras[i];
      }
    }

    bestCamera ??= _cameras[0];

    if (mounted) setState(() {});
  }

  /// 停止录制
  void _stopRecording() async {
    if (_controller != null && _isRecording) {
      await _controller?.stopImageStream();
      _controller?.dispose();
      _controller = null;
      WakelockPlus.disable();

      reset();
      // await _controller!.pausePreview();
      setState(() {
        _isRecording = false;
      });
      _recordTimer?.cancel();
      _recordTimer = null;
    }
  }

  /// 获取当前时间
  String getNowTime() {
    DateTime dateTime = DateTime.now();
    return dateTime.toString();
  }

  /// 重置计数和绘图变量
  void reset() {
    cycleCnt = 0;
    // _points.clear();
    setState(() {
      probs.clear();
      rects.clear();
      emoIdx.clear();
    });
  }

  /// 翻转摄像头
  void flipCamera() async {
    if (bestCamera == null) {
      return;
    }

    CameraDescription oldCamera = bestCamera!;

    if (bestCamera!.lensDirection == CameraLensDirection.front) {
      for (var i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          bestCamera = _cameras[i];
          break;
        }
      }
    } else {
      for (var i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.front) {
          bestCamera = _cameras[i];
          break;
        }
      }
    }

    if (bestCamera != oldCamera) {
      try {
        await _controller?.stopImageStream();
        reset();

        _controller = CameraController(bestCamera!, ResolutionPreset.medium,
            enableAudio: false, fps: fps, imageFormatGroup: format);

        await _controller!.initialize();
        aspectRatio = _controller!.value.aspectRatio;
        await _controller!.startImageStream(_onNewFrame);
        setState(() {});
      } catch (e) {
        showToast("出现异常");
        _startRecording();
      }
    }
  }

  /// 开始录制
  void _startRecording() async {
    if (!isPaid && _recordingDuration >= _maxRecordingDuration) {
      if (mounted) {
        _showAlertDialog(context);
      }
      return;
    }

    WakelockPlus.enable(); // 设置运行时不熄屏

    _controller = CameraController(bestCamera!, ResolutionPreset.medium,
        enableAudio: false, fps: fps, imageFormatGroup: format);

    await _controller!.initialize();
    aspectRatio = _controller!.value.aspectRatio;
    // print("aspect ratio: ${_controller!.value.aspectRatio}");
    if (_controller != null && !_isRecording) {
      // await _controller!.startVideoRecording();
      await _controller!.startImageStream(_onNewFrame);
      setState(() {
        _isRecording = true;
      });

      if (!isPaid) {
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    _recordTimer?.cancel();
    emotionRecognizer?.release();
    super.dispose();
  }

  /// 导出文件
  Future<void> exportFile() async {
    const headers = "time,emotion\n";
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

    showToast("saved in $filepath");
  }

  Widget _buildCameraPreview(double height) {
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

    return Stack(alignment: Alignment.center, children: [
      CameraPreview(_controller!),
      SizedBox(
          width: _controller!.value.previewSize!.width,
          height: _controller!.value.previewSize!.height,
          child: CustomPaint(
            painter: FacePainter(
              imageSize: Size(_controller!.value.previewSize!.height,
                  _controller!.value.previewSize!.width),
              rects: rects,
              emoIdx: emoIdx,
              cameraLensDirection: bestCamera!.lensDirection,
            ),
          ))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Column(
            children: [
              // SizedBox(
              //   height: 0.02 * height,
              // ),
              // 摄像头区域（40%）
              SizedBox(
                width: height * 0.5 / aspectRatio,
                height: height * 0.5,
                child: _buildCameraPreview(height * 0.5),
              ),

              // 图表区域（30%）
              SizedBox(
                height: height * 0.3,
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 12, top: 24, right: 12, bottom: 0),
                  child: EmotionBarChart(data: probs),
                  //  child: Image.memory(face)
                ),
              ),
              // SizedBox(height: ,)
              // 按钮区域（30%）
              SizedBox(
                height: height * 0.2,
                child: Center(
                    child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isRecording ? flipCamera : null,
                          child: const Text('切换镜头'),
                        ),
                        ElevatedButton(
                          onPressed:
                              _isRecording ? _stopRecording : _startRecording,
                          child: _isRecording
                              ? const Text('停止录制')
                              : const Text('开始录制'),
                        ),
                        ElevatedButton(
                          onPressed: exportFile,
                          child: const Text('导出文件'),
                        ),
                      ],
                    ),
                  ],
                )),
              ),
            ],
          );
        },
      ),
    );
  }
}
