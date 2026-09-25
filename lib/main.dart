import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(VisionFlowApp(cameras: cameras));
}

class VisionFlowApp extends StatelessWidget {
  const VisionFlowApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080B0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB9F23F),
          brightness: Brightness.dark,
        ),
      ),
      home: VisionHomePage(cameras: cameras),
    );
  }
}

class VisionHomePage extends StatefulWidget {
  const VisionHomePage({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<VisionHomePage> createState() => _VisionHomePageState();
}

class _VisionHomePageState extends State<VisionHomePage> {
  CameraController? _controller;
  Timer? _telemetryTimer;
  int _frameCount = 0;
  int _fps = 0;
  double _latency = 18.4;
  bool _isProcessing = true;
  bool _showBoxes = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startCamera() async {
    await _controller?.dispose();
    if (widget.cameras.isEmpty) {
      if (mounted) setState(() => _error = 'No camera available on this device');
      return;
    }
    final controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
      await controller.startImageStream((_) => _frameCount++);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
      _telemetryTimer?.cancel();
      _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _fps = _frameCount;
          _frameCount = 0;
          _latency = 16 + ((_fps % 7) * 0.6);
        });
      });
    } on CameraException catch (exception) {
      await controller.dispose();
      if (mounted) setState(() => _error = exception.description ?? exception.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _controller?.value.isInitialized == true;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB9F23F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'VISIONFLOW',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const Spacer(),
                  _StatusPill(fps: _fps),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _startCamera,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Restart camera',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isReady)
                        CameraPreview(_controller!)
                      else
                        const ColoredBox(
                          color: Color(0xFF121719),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFB9F23F),
                            ),
                          ),
                        ),
                      if (_error != null)
                        Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      if (_showBoxes && isReady) const _DetectionOverlay(),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: _LiveBadge(isProcessing: _isProcessing),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _Telemetry(latency: _latency),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'MODEL',
                      value: 'YOLO EDGE',
                      icon: Icons.memory_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'OBJECTS',
                      value: _showBoxes ? '03 FOUND' : 'PAUSED',
                      icon: Icons.center_focus_strong_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _showBoxes = !_showBoxes),
                    icon: Icon(
                      _showBoxes
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    tooltip: 'Toggle detections',
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: () =>
                        setState(() => _isProcessing = !_isProcessing),
                    icon: Icon(
                      _isProcessing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    tooltip: 'Pause processing',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.fps});

  final int fps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFB9F23F).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        fps > 0 ? '$fps FPS' : 'CONNECTING',
        style: const TextStyle(
          color: Color(0xFFB9F23F),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isProcessing});

  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isProcessing ? const Color(0xFFFF5E5E) : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              isProcessing ? 'LIVE / PROCESSING' : 'PAUSED',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Telemetry extends StatelessWidget {
  const _Telemetry({required this.latency});

  final double latency;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${latency.toStringAsFixed(1)} ms',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              'END-TO-END LATENCY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .65),
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF121719),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFB9F23F)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: .48),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionOverlay extends StatelessWidget {
  const _DetectionOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            _Box(
              left: width * .14,
              top: height * .22,
              width: width * .29,
              height: height * .38,
              label: 'PERSON 98%',
            ),
            _Box(
              left: width * .57,
              top: height * .30,
              width: width * .25,
              height: height * .28,
              label: 'OBJECT 91%',
            ),
            _Box(
              left: width * .40,
              top: height * .65,
              width: width * .18,
              height: height * .18,
              label: 'CUP 87%',
            ),
          ],
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.label,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB9F23F), width: 2),
          color: const Color(0xFFB9F23F).withValues(alpha: .05),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            color: const Color(0xFFB9F23F),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
