import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dognal1/data/api/rest_client.dart';
import 'package:dognal1/core/providers/analysis_provider.dart';
import 'package:dognal1/features/walk/screens/walk_history_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum WalkState { notStarted, walking, paused }

class WalkScreen extends ConsumerStatefulWidget {
  final String dogId;

  const WalkScreen({
    super.key,
    required this.dogId,
  });

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  WalkState _walkState = WalkState.notStarted;
  GoogleMapController? _mapController;
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  final Set<Polyline> _polylines = {};
  final List<LatLng> _pathPoints = [];
  LocationData? _currentLocation;

  double _distance = 0.0;
  Timer? _timer;
  int _durationInSeconds = 0;
  String _weatherInfo = '정보 없음';
  DateTime? _startedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _currentLocation = await _location.getLocation();
    if (mounted) setState(() {});
  }

  Future<void> _getWeather() async {
    if (_currentLocation == null) return;

    final lat = _currentLocation!.latitude;
    final lng = _currentLocation!.longitude;
    final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final currentWeather = data['current_weather'];
        final temp = currentWeather['temperature'];
        final weatherCode = currentWeather['weathercode'] as int;
        final description = _getWeatherDescription(weatherCode);

        if (mounted) {
          setState(() {
            _weatherInfo = '$description, ${temp.toStringAsFixed(1)}°C';
          });
        }
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherInfo = '날씨 실패';
        });
      }
      debugPrint('날씨 정보를 가져오는 데 실패했습니다: $e');
    }
  }

  String _getWeatherDescription(int code) {
    switch (code) {
      case 0: return '맑음';
      case 1: case 2: case 3: return '대체로 맑음';
      case 45: case 48: return '안개';
      case 51: case 53: case 55: return '이슬비';
      case 61: case 63: case 65: return '비';
      case 80: case 81: case 82: return '소나기';
      case 95: return '뇌우';
      case 71: case 73: case 75: case 85: case 86: return '눈';
      default: return '정보 없음';
    }
  }

  void _startWalk() {
    if (_currentLocation == null) return;

    _pathPoints.clear();
    _polylines.clear();
    _distance = 0.0;
    _durationInSeconds = 0;
    _weatherInfo = '정보 없음';
    _startedAt = DateTime.now();

    _getWeather();

    final startPoint = LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    _pathPoints.add(startPoint);

    _locationSubscription = _location.onLocationChanged.listen((LocationData newLocation) {
      if (!mounted || _walkState != WalkState.walking) return;
      final newPoint = LatLng(newLocation.latitude!, newLocation.longitude!);
      setState(() {
        if (_pathPoints.isNotEmpty) {
          final lastPoint = _pathPoints.last;
          _distance += _calculateDistance(lastPoint, newPoint);
        }
        _pathPoints.add(newPoint);
        _updatePolylines();
        _currentLocation = newLocation;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _durationInSeconds++;
      });
    });

    setState(() {
      _walkState = WalkState.walking;
    });
  }

  void _pauseOrResumeWalk() {
    if (_walkState == WalkState.walking) {
      _timer?.cancel();
      _locationSubscription?.pause();
      setState(() {
        _walkState = WalkState.paused;
      });
    } else if (_walkState == WalkState.paused) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _durationInSeconds++;
        });
      });
      _locationSubscription?.resume();
      setState(() {
        _walkState = WalkState.walking;
      });
    }
  }

  // --- ▼▼▼ [수정] _stopWalk 함수를 동영상 촬영 로직으로 수정합니다. ▼▼▼ ---
  Future<void> _stopWalk() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('산책 종료'),
        content: const Text('산책을 마치고 강아지 표정 분석을 위해 짧은 동영상을 촬영하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('종료 및 촬영')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() { _isSaving = true; });

    _locationSubscription?.cancel();
    _timer?.cancel();

    try {
      final picker = ImagePicker();
      // --- [수정] 사진 대신 동영상을 촬영합니다. ---
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);

      if (video != null) {
        final videoBytes = await video.readAsBytes();
        final videoFilename = video.name;
        final restClient = ref.read(restClientProvider);
        final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;

        if (accessToken != null) {
          // --- [수정] 수정된 analyzeFacialExpression 함수를 올바른 파라미터로 호출합니다. ---
          await restClient.analyzeFacialExpression(
            dogId: widget.dogId,
            videoBytes: videoBytes,
            videoFilename: videoFilename,
            accessToken: accessToken,
            activityDescription: '산책 종료 후 표정 분석',
          );
        }
      }

      // 중앙 Provider를 갱신하여 다른 화면에 변경사항을 알립니다.
      ref.invalidate(analysisResultsProvider((dogId: widget.dogId, viewType: 'daily')));
      ref.invalidate(analysisResultsProvider((dogId: widget.dogId, viewType: 'weekly')));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 표정 분석 완료! 홈 화면에서 결과를 확인하세요!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: 분석에 실패했습니다.\n$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        _resetWalkState();
      }
    }
  }

  void _resetWalkState() {
    setState(() {
      _isSaving = false;
      _walkState = WalkState.notStarted;
      _pathPoints.clear();
      _polylines.clear();
      _distance = 0.0;
      _durationInSeconds = 0;
      _startedAt = null;
    });
  }

  void _updatePolylines() {
    _polylines.add(Polyline(
      polylineId: const PolylineId('walk_path'),
      points: List.from(_pathPoints),
      color: Colors.blueAccent,
      width: 5,
    ));
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const r = 6371e3;
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return r * c;
  }

  String _formatDuration(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책하기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '산책 기록 보기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WalkHistoryScreen(dogId: widget.dogId),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoTile('거리', '${(_distance / 1000).toStringAsFixed(2)} km'),
                            _infoTile('시간', _formatDuration(_durationInSeconds)),
                            _infoTile('날씨', _weatherInfo),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_walkState == WalkState.notStarted)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('시작'),
                                onPressed: _isSaving ? null : _startWalk,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                              ),
                            if (_walkState == WalkState.walking || _walkState == WalkState.paused)
                              ElevatedButton.icon(
                                icon: Icon(_walkState == WalkState.walking ? Icons.pause : Icons.play_arrow),
                                label: Text(_walkState == WalkState.walking ? '중지' : '재개'),
                                onPressed: _isSaving ? null : _pauseOrResumeWalk,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                              ),
                            if (_walkState != WalkState.notStarted)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.stop),
                                label: const Text('종료'),
                                onPressed: _isSaving ? null : _stopWalk,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                if (_isSaving) const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}

