import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:record/record.dart';

typedef AudioChunkCallback = Future<void> Function(String audioBase64, String format);
typedef RecorderFailureCallback = void Function(String message);

const String voiceAnalysisUnavailableText = '음성 분석을 쓸 수 없어요';

/// 분석 대상 통화에서 말하는 쪽 기기의 마이크 소리를 4초 조각으로 녹음해 서버로 올리는 모듈 (기획서 5.3).
///
/// 통화(WebRTC)와 조각 녹음이 마이크를 동시에 쓰지 못해 녹음이 실패하더라도
/// 통화는 끊기지 않고 화면에 [voiceAnalysisUnavailableText]("음성 분석을 쓸 수 없어요")를 보여 줍니다.
abstract interface class CallChunkRecorder {
  Future<void> start({
    required AudioChunkCallback onChunk,
    required RecorderFailureCallback onFailure,
  });

  Future<void> stop();
}

class RecordChunkRecorder implements CallChunkRecorder {
  final Duration chunkDuration;
  final AudioRecorder Function() _createRecorder;
  AudioRecorder? _recorder;
  Timer? _timer;
  bool _running = false;
  bool _rotating = false;
  int _seq = 0;

  RecordChunkRecorder({
    this.chunkDuration = const Duration(seconds: 4),
    AudioRecorder Function()? createRecorder,
  }) : _createRecorder = createRecorder ?? AudioRecorder.new;

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  String _nextTempPath() {
    _seq += 1;
    return '${Directory.systemTemp.path}/fb_call_chunk_${DateTime.now().millisecondsSinceEpoch}_$_seq.wav';
  }

  @override
  Future<void> start({
    required AudioChunkCallback onChunk,
    required RecorderFailureCallback onFailure,
  }) async {
    if (_running) return;
    _running = true;
    try {
      final recorder = _createRecorder();
      _recorder = recorder;
      final permitted = await recorder.hasPermission();
      if (!_running) return;
      if (!permitted) {
        await stop();
        onFailure(voiceAnalysisUnavailableText);
        return;
      }
      await recorder.start(_config, path: _nextTempPath());
      if (!_running) {
        await stop();
        return;
      }
      _scheduleNext(onChunk: onChunk, onFailure: onFailure);
    } catch (_) {
      final wasRunning = _running;
      await stop();
      if (wasRunning) onFailure(voiceAnalysisUnavailableText);
    }
  }

  void _scheduleNext({
    required AudioChunkCallback onChunk,
    required RecorderFailureCallback onFailure,
  }) {
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer(chunkDuration, () {
      _rotateChunk(onChunk: onChunk, onFailure: onFailure);
    });
  }

  Future<void> _rotateChunk({
    required AudioChunkCallback onChunk,
    required RecorderFailureCallback onFailure,
  }) async {
    if (!_running || _rotating) return;
    _rotating = true;
    String? recordedPath;
    try {
      final recorder = _recorder;
      if (recorder == null) return;
      recordedPath = await recorder.stop();
      if (!_running) {
        _deleteTempFile(recordedPath);
        return;
      }
      await recorder.start(_config, path: _nextTempPath());
      // 업로드와 서버 판정을 기다리지 않고 다음 4초 회전 타이머를 바로 잡습니다.
      if (_running) {
        _scheduleNext(onChunk: onChunk, onFailure: onFailure);
      }
    } catch (_) {
      _deleteTempFile(recordedPath);
      final wasRunning = _running;
      await stop();
      if (wasRunning) onFailure(voiceAnalysisUnavailableText);
      return;
    } finally {
      _rotating = false;
    }

    if (recordedPath != null && recordedPath.isNotEmpty) {
      unawaited(_readAndSendChunk(recordedPath, onChunk));
    }
  }

  Future<void> _readAndSendChunk(String recordedPath, AudioChunkCallback onChunk) async {
    try {
      final file = File(recordedPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _deleteTempFile(recordedPath);
        if (_running && bytes.isNotEmpty) {
          await onChunk(base64Encode(bytes), 'wav');
        }
      }
    } catch (_) {
      _deleteTempFile(recordedPath);
    }
  }

  static void _deleteTempFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      try {
        final path = await recorder.stop();
        _deleteTempFile(path);
      } catch (_) {}
      try {
        await recorder.dispose();
      } catch (_) {}
    }
  }
}

class NoopChunkRecorder implements CallChunkRecorder {
  bool started = false;
  bool stopped = false;
  final bool simulateFailure;

  NoopChunkRecorder({this.simulateFailure = false});

  @override
  Future<void> start({
    required AudioChunkCallback onChunk,
    required RecorderFailureCallback onFailure,
  }) async {
    started = true;
    if (simulateFailure) {
      onFailure(voiceAnalysisUnavailableText);
    }
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
