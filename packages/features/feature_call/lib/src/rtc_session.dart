import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef SignalSender = void Function(Map<String, dynamic> signal);
typedef RtcStateCallback = void Function(String statusText);

const String rtcConnectingText = '음성 연결 중';
const String rtcConnectedText = '음성 연결됨';
const String rtcFailedText = '음성을 연결하지 못했어요';

/// 기기 간 WebRTC 음성 통화 이음매 (기획서 5.3, 지시서 8·14번).
///
/// 음성만 사용하고(`{'audio': true, 'video': false}`), 외부 STUN·TURN 서버 없이
/// 같은 Wi-Fi 안에서 연결하도록 `iceServers`를 비웁니다.
/// 연결 순서: 수신 측 준비 완료 후 `ready` 전송 → 발신 측 `offer` 전송 → 수신 측 `answer` 전송 → 양측 `ice` 교환.
/// 원격 설명(`setRemoteDescription`) 전에 도착한 ICE 후보는 모아 두었다가 설정 뒤에 반영합니다.
/// 위젯 테스트에서는 플랫폼 채널을 부르지 않는 [NoopRtcPeerSession]으로 바꿀 수 있습니다.
abstract interface class RtcPeerSession {
  Future<void> startAsCaller({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  });

  Future<void> startAsCallee({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  });

  Future<void> onSignal(Map<String, dynamic> signal);

  Future<void> setMicrophoneMuted(bool muted);

  Future<void> setSpeakerphoneEnabled(bool enabled);

  Future<void> close();
}

class FlutterWebRtcPeerSession implements RtcPeerSession {
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': <Map<String, dynamic>>[],
  };

  static const Map<String, dynamic> audioOnlyConstraints = {
    'audio': true,
    'video': false,
  };

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _callId;
  String? _localId;
  SignalSender? _sendSignal;
  RtcStateCallback? _onStateChanged;
  bool _isCaller = false;
  bool _peerReady = false;
  bool _offerSent = false;
  bool _remoteDescriptionSet = false;
  Map<String, dynamic>? _pendingOffer;
  Map<String, dynamic>? _pendingAnswer;
  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _muted = false;
  bool _speakerphone = false;
  bool _closed = false;

  void _reportState(String statusText) {
    if (_closed) return;
    _onStateChanged?.call(statusText);
  }

  Future<void> _applyMuteToStream(MediaStream stream, bool muted) async {
    for (final track in stream.getAudioTracks()) {
      try {
        await Helper.setMicrophoneMute(muted, track);
      } catch (_) {
        track.enabled = !muted;
      }
    }
  }

  Future<RTCPeerConnection?> _preparePeer({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  }) async {
    if (_closed) return null;
    _callId = callId;
    _localId = localId;
    _sendSignal = sendSignal;
    _onStateChanged = onStateChanged;
    _reportState(rtcConnectingText);
    try {
      final stream = await navigator.mediaDevices.getUserMedia(audioOnlyConstraints);
      if (_closed) {
        await stream.dispose();
        return null;
      }
      _localStream = stream;
      if (_muted) {
        await _applyMuteToStream(stream, true);
      }
      final pc = await createPeerConnection(rtcConfiguration);
      if (_closed) {
        await pc.close();
        await pc.dispose();
        return null;
      }
      _pc = pc;
      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
      pc.onIceCandidate = (RTCIceCandidate candidate) {
        final cand = candidate.candidate;
        if (_closed || cand == null || cand.isEmpty) return;
        _sendSignal?.call({
          'type': 'rtc_signal',
          'call_id': callId,
          'signal_type': 'ice',
          'from': localId,
          'data': {
            'candidate': cand,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };
      pc.onConnectionState = (RTCPeerConnectionState state) {
        if (_closed) return;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _reportState(rtcConnectedText);
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _reportState(rtcFailedText);
          default:
            break;
        }
      };
      pc.onIceConnectionState = (RTCIceConnectionState state) {
        if (_closed) return;
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            _reportState(rtcConnectedText);
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            _reportState(rtcFailedText);
          default:
            break;
        }
      };
      return pc;
    } catch (_) {
      // 마이크 권한 거부나 WebRTC 초기화 실패 시 상태를 알리고 통화 화면·대본 전송은 계속 쓸 수 있게 합니다.
      _reportState(rtcFailedText);
      return null;
    }
  }

  Future<void> _createAndSendOffer(RTCPeerConnection pc) async {
    if (_closed || _offerSent) return;
    _offerSent = true;
    try {
      final offer = await pc.createOffer();
      if (_closed) return;
      await pc.setLocalDescription(offer);
      _sendSignal?.call({
        'type': 'rtc_signal',
        'call_id': _callId ?? '',
        'signal_type': 'offer',
        'from': _localId ?? '',
        'data': {
          'sdp': offer.sdp,
          'type': offer.type ?? 'offer',
        },
      });
    } catch (_) {
      _offerSent = false;
      _reportState(rtcFailedText);
    }
  }

  Future<void> _flushPendingCandidates(RTCPeerConnection pc) async {
    final pending = List<RTCIceCandidate>.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in pending) {
      if (_closed) return;
      try {
        await pc.addCandidate(candidate);
      } catch (_) {
        _reportState(rtcFailedText);
      }
    }
  }

  Future<void> _handleOffer(RTCPeerConnection pc, Map<String, dynamic> data, String callId) async {
    final sdp = data['sdp'] as String?;
    if (sdp == null || sdp.isEmpty) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    if (_closed) return;
    _remoteDescriptionSet = true;
    await _flushPendingCandidates(pc);
    if (_closed) return;
    final answer = await pc.createAnswer();
    if (_closed) return;
    await pc.setLocalDescription(answer);
    _sendSignal?.call({
      'type': 'rtc_signal',
      'call_id': callId,
      'signal_type': 'answer',
      'from': _localId ?? '',
      'data': {
        'sdp': answer.sdp,
        'type': answer.type ?? 'answer',
      },
    });
  }

  Future<void> _handleAnswer(RTCPeerConnection pc, Map<String, dynamic> data) async {
    final sdp = data['sdp'] as String?;
    if (sdp == null || sdp.isEmpty) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    if (_closed) return;
    _remoteDescriptionSet = true;
    await _flushPendingCandidates(pc);
  }

  @override
  Future<void> startAsCaller({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  }) async {
    if (_closed) return;
    _isCaller = true;
    final pc = await _preparePeer(
      callId: callId,
      localId: localId,
      sendSignal: sendSignal,
      onStateChanged: onStateChanged,
    );
    if (pc == null || _closed) return;
    if (_peerReady) {
      await _createAndSendOffer(pc);
    }
    if (_pendingAnswer != null) {
      final ans = _pendingAnswer!;
      _pendingAnswer = null;
      try {
        await _handleAnswer(pc, ans);
      } catch (_) {
        _reportState(rtcFailedText);
      }
    }
  }

  @override
  Future<void> startAsCallee({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  }) async {
    if (_closed) return;
    _isCaller = false;
    final pc = await _preparePeer(
      callId: callId,
      localId: localId,
      sendSignal: sendSignal,
      onStateChanged: onStateChanged,
    );
    if (pc == null || _closed) return;
    sendSignal({
      'type': 'rtc_signal',
      'call_id': callId,
      'signal_type': 'ready',
      'from': localId,
    });
    if (_pendingOffer != null) {
      final offer = _pendingOffer!;
      _pendingOffer = null;
      try {
        await _handleOffer(pc, offer, callId);
      } catch (_) {
        _reportState(rtcFailedText);
      }
    }
  }

  @override
  Future<void> onSignal(Map<String, dynamic> signal) async {
    if (_closed) return;
    final signalCallId = signal['call_id'] as String?;
    if (_callId != null && signalCallId != null && signalCallId.isNotEmpty && signalCallId != _callId) {
      return;
    }
    final from = (signal['from'] ?? signal['from_id']) as String?;
    if (_localId != null && from == _localId) return;

    final signalType = (signal['signal_type'] ?? signal['type']) as String? ?? '';
    final rawData = signal['data'];
    final data = rawData is Map<String, dynamic> ? rawData : signal;

    try {
      switch (signalType) {
        case 'ready':
          if (!_isCaller) return;
          _peerReady = true;
          final pc = _pc;
          if (pc != null) {
            await _createAndSendOffer(pc);
          }
        case 'offer':
          final pc = _pc;
          if (pc == null) {
            _pendingOffer = data;
            return;
          }
          await _handleOffer(pc, data, _callId ?? signalCallId ?? '');
        case 'answer':
          final pc = _pc;
          if (pc == null) {
            _pendingAnswer = data;
            return;
          }
          await _handleAnswer(pc, data);
        case 'ice':
          final cand = data['candidate'] as String?;
          if (cand == null || cand.isEmpty) return;
          final sdpMid = data['sdpMid'] as String?;
          final sdpMLineIndex = data['sdpMLineIndex'] is int ? data['sdpMLineIndex'] as int : null;
          final candidate = RTCIceCandidate(cand, sdpMid, sdpMLineIndex);
          final pc = _pc;
          if (pc == null || !_remoteDescriptionSet) {
            _pendingCandidates.add(candidate);
            return;
          }
          await pc.addCandidate(candidate);
      }
    } catch (_) {
      _reportState(rtcFailedText);
    }
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    if (_closed) return;
    _muted = muted;
    final stream = _localStream;
    if (stream == null) return;
    await _applyMuteToStream(stream, muted);
  }

  @override
  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    if (_closed) return;
    _speakerphone = enabled;
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _closed = true;
    _pendingOffer = null;
    _pendingAnswer = null;
    _pendingCandidates.clear();
    if (_speakerphone) {
      _speakerphone = false;
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (_) {}
    }
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      try {
        if (_muted) {
          _muted = false;
          await _applyMuteToStream(stream, false);
        }
        for (final track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
      } catch (_) {}
    }
    final pc = _pc;
    _pc = null;
    if (pc != null) {
      try {
        await pc.close();
        await pc.dispose();
      } catch (_) {}
    }
  }
}

class NoopRtcPeerSession implements RtcPeerSession {
  final bool simulateFailure;
  bool startedAsCaller = false;
  bool startedAsCallee = false;
  bool closed = false;
  bool muted = false;
  bool speakerphoneEnabled = false;
  bool remoteDescriptionSet = false;
  String? lastStatus;
  final List<Map<String, dynamic>> receivedSignals = [];
  final List<Map<String, dynamic>> pendingIceCandidates = [];
  final List<Map<String, dynamic>> appliedIceCandidates = [];

  String? _callId;
  String? _localId;
  SignalSender? _sendSignal;
  RtcStateCallback? _onStateChanged;
  bool _peerReady = false;
  bool _offerSent = false;

  NoopRtcPeerSession({this.simulateFailure = false});

  void _report(String status) {
    if (closed) return;
    lastStatus = status;
    _onStateChanged?.call(status);
  }

  void _sendOffer() {
    if (closed || simulateFailure || !startedAsCaller || _offerSent) return;
    _offerSent = true;
    _sendSignal?.call({
      'type': 'rtc_signal',
      'call_id': _callId ?? '',
      'signal_type': 'offer',
      'from': _localId ?? '',
      'data': const {
        'sdp': 'v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\n',
        'type': 'offer',
      },
    });
  }

  void _flushIce() {
    if (pendingIceCandidates.isEmpty) return;
    appliedIceCandidates.addAll(pendingIceCandidates);
    pendingIceCandidates.clear();
  }

  @override
  Future<void> startAsCaller({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  }) async {
    if (closed) return;
    startedAsCaller = true;
    _callId = callId;
    _localId = localId;
    _sendSignal = sendSignal;
    _onStateChanged = onStateChanged;
    if (simulateFailure) {
      _report(rtcFailedText);
      return;
    }
    _report(rtcConnectingText);
    if (_peerReady) {
      _sendOffer();
    }
  }

  @override
  Future<void> startAsCallee({
    required String callId,
    required String localId,
    required SignalSender sendSignal,
    RtcStateCallback? onStateChanged,
  }) async {
    if (closed) return;
    startedAsCallee = true;
    _callId = callId;
    _localId = localId;
    _sendSignal = sendSignal;
    _onStateChanged = onStateChanged;
    if (simulateFailure) {
      _report(rtcFailedText);
      return;
    }
    _report(rtcConnectingText);
    sendSignal({
      'type': 'rtc_signal',
      'call_id': callId,
      'signal_type': 'ready',
      'from': localId,
    });
  }

  @override
  Future<void> onSignal(Map<String, dynamic> signal) async {
    if (closed) return;
    final signalCallId = signal['call_id'] as String?;
    if (_callId != null && signalCallId != null && signalCallId.isNotEmpty && signalCallId != _callId) {
      return;
    }
    final from = (signal['from'] ?? signal['from_id']) as String?;
    if (_localId != null && from == _localId) return;

    receivedSignals.add(signal);
    if (simulateFailure) return;

    final signalType = (signal['signal_type'] ?? signal['type']) as String? ?? '';
    final rawData = signal['data'];
    final data = rawData is Map<String, dynamic> ? rawData : signal;

    switch (signalType) {
      case 'ready':
        if (!startedAsCaller) return;
        _peerReady = true;
        _sendOffer();
      case 'offer':
        final sdp = data['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        remoteDescriptionSet = true;
        _flushIce();
        _sendSignal?.call({
          'type': 'rtc_signal',
          'call_id': _callId ?? signalCallId ?? '',
          'signal_type': 'answer',
          'from': _localId ?? '',
          'data': const {
            'sdp': 'v=0\r\no=- 2 2 IN IP4 127.0.0.1\r\n',
            'type': 'answer',
          },
        });
        _report(rtcConnectedText);
      case 'answer':
        final sdp = data['sdp'] as String?;
        if (sdp == null || sdp.isEmpty) return;
        remoteDescriptionSet = true;
        _flushIce();
        _report(rtcConnectedText);
      case 'ice':
        final cand = data['candidate'] as String?;
        if (cand == null || cand.isEmpty) return;
        if (!remoteDescriptionSet) {
          pendingIceCandidates.add(data);
        } else {
          appliedIceCandidates.add(data);
        }
    }
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    if (closed) return;
    this.muted = muted;
  }

  @override
  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    if (closed) return;
    speakerphoneEnabled = enabled;
  }

  @override
  Future<void> close() async {
    closed = true;
    muted = false;
    speakerphoneEnabled = false;
    pendingIceCandidates.clear();
  }
}
