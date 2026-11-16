import 'package:core_api/core_api.dart';

import 'json.dart';
import 'models.dart';
import 'results.dart';

/// 핑거벨 백엔드와 주고받는 모든 기능. 실패하면 [ApiException]을 던집니다.
abstract interface class FamilyRepository {
  Future<FamilySnapshot> fetchState();

  /// 실시간 이벤트와 연결 상태. 실시간 연결이 없는 구현은 빈 스트림을 돌려줍니다.
  Stream<FamilyEvent> get events;
  Stream<Map<String, dynamic>> get rtcSignals;
  Stream<bool> get connection;
  void connect();
  void sendRtcSignal(Map<String, dynamic> signal);

  Future<FreezeResult> freeze(String memberId, SosTrigger trigger, {double? intensity});
  Future<void> requestUnfreeze(String memberId);
  Future<void> unfreeze(String memberId, String guardianId);
  Future<void> releaseCautionMode(String memberId, String guardianId);
  Future<SmsReceiveResult> receiveSms(
    String memberId, {
    String? kind,
    String? senderPhone,
    String? senderName,
    String? body,
  });

  Future<CallSession> startCall({
    required String callerId,
    required String calleeId,
    String? peerPhone,
    String? peerName,
  });
  Future<CallSession> answerCall(String callId);
  Future<CallSession> endCall(String callId);
  Future<CallAnalysisResult> sendCallAudio(
    String callId, {
    required String audioBase64,
    String audioFormat = 'wav',
  });
  Future<CallAnalysisResult> sendCallTranscript(String callId, {required String text});

  Future<TransferPreview> assessTransfer(String memberId, TransferDraft draft);
  Future<TransferResult> submitTransfer(String memberId, TransferDraft draft);

  Future<ConfirmationQuestionResult> fetchConfirmationQuestion(String memberId, String actionKind, {int? amount});
  Future<SavingsCancelResult> cancelSavings(
    String memberId,
    String accountId, {
    String? questionAnswer,
    bool confirmed = false,
  });
  Future<LoanQuote> quoteLoan(int amount);
  Future<LoanLimitResult> checkLoanLimit(String memberId, {String? questionAnswer, bool confirmed = false});
  Future<LoanApplyResult> applyLoan(
    String memberId,
    int amount, {
    String? questionAnswer,
    bool confirmed = false,
  });

  Future<PaymentResult> pay(String memberId, String merchantId);
  Future<PaymentResult> requestPayment(String memberId, String merchantId);

  Future<ModeChangeResult> setMode(String memberId, String modeId, {required bool byGuardian});
  Future<void> setDailyLimit(String memberId, int value);
  Future<void> setSleepGuard(String memberId, bool enabled);

  Future<DecisionResult> decide(String requestId, String guardianId, {required bool approve});
  Future<DecisionResult> extendHold(String requestId, String guardianId);
  Future<DecisionResult> cancelRequest(String requestId, String memberId);
  Future<DecisionResult> reconfirmHold(String requestId, String memberId, {required bool confirm});
  Future<void> dismissNotice(String memberId, String noticeId);

  Future<PairingCodeResult> issuePairingCode(String guardianId, String memberId);
  Future<PairingConnectResult> connectPairing(String memberId, String code, {required bool consented});

  Future<List<IntegrationLogEntry>> integrationLogs({int limit = 30});
  Future<UserFeedbackResult> submitFeedback(String memberId, {required String category, String message = ''});
  Future<void> resetDemo();

  Future<void> dispose();
}

class ApiFamilyRepository implements FamilyRepository {
  static const _signalTypes = {'rtc_signal', 'signal', 'ready', 'offer', 'answer', 'ice'};

  final FingerBellApi api;
  final RealtimeChannel realtime;

  ApiFamilyRepository(this.api, {RealtimeChannel? realtime})
    : realtime = realtime ?? RealtimeChannel(api.config.websocket);

  @override
  Stream<FamilyEvent> get events => realtime.events
      .where((e) => e['type'] != 'hello' && !_signalTypes.contains(e['type']))
      .map((e) => FamilyEvent.fromJson(e, clientId: api.clientId));

  @override
  Stream<Map<String, dynamic>> get rtcSignals =>
      realtime.events.where((e) => _signalTypes.contains(e['type']));

  @override
  Stream<bool> get connection => realtime.connection;

  @override
  void connect() => realtime.connect();

  @override
  void sendRtcSignal(Map<String, dynamic> signal) => realtime.sendJson(signal);

  @override
  Future<FamilySnapshot> fetchState() async => FamilySnapshot.fromJson(await api.get('/state'));

  @override
  Future<FreezeResult> freeze(String memberId, SosTrigger trigger, {double? intensity}) async => FreezeResult.fromJson(
    await api.post('/security/sos-freeze', {
      'user_id': memberId,
      'trigger_type': trigger.apiValue,
      'sensor_intensity': intensity,
    }),
  );

  @override
  Future<void> requestUnfreeze(String memberId) => api.post('/security/unfreeze-request', {'member_id': memberId});

  @override
  Future<void> unfreeze(String memberId, String guardianId) =>
      api.post('/security/unfreeze', {'member_id': memberId, 'guardian_id': guardianId});

  @override
  Future<void> releaseCautionMode(String memberId, String guardianId) =>
      api.post('/security/caution-mode/release', {'member_id': memberId, 'guardian_id': guardianId});

  @override
  Future<SmsReceiveResult> receiveSms(
    String memberId, {
    String? kind,
    String? senderPhone,
    String? senderName,
    String? body,
  }) async => SmsReceiveResult.fromJson(
    await api.post('/sms/receive', {
      'member_id': memberId,
      'kind': ?kind,
      'sender_phone': ?senderPhone,
      'sender_name': ?senderName,
      'body': ?body,
    }),
  );

  @override
  Future<CallSession> startCall({
    required String callerId,
    required String calleeId,
    String? peerPhone,
    String? peerName,
  }) async {
    final res = await api.post('/calls/start', {
      'caller_id': callerId,
      'callee_id': calleeId,
      'peer_phone': ?peerPhone,
      'peer_name': ?peerName,
    });
    return CallSession.fromJson(asJson(res['call']));
  }

  @override
  Future<CallSession> answerCall(String callId) async {
    final res = await api.post('/calls/$callId/answer');
    return CallSession.fromJson(asJson(res['call']));
  }

  @override
  Future<CallSession> endCall(String callId) async {
    final res = await api.post('/calls/$callId/end');
    return CallSession.fromJson(asJson(res['call']));
  }

  @override
  Future<CallAnalysisResult> sendCallAudio(
    String callId, {
    required String audioBase64,
    String audioFormat = 'wav',
  }) async => CallAnalysisResult.fromJson(
    await api.post('/calls/$callId/audio', {
      'audio_base64': audioBase64,
      'audio_format': audioFormat,
    }),
  );

  @override
  Future<CallAnalysisResult> sendCallTranscript(String callId, {required String text}) async =>
      CallAnalysisResult.fromJson(await api.post('/calls/$callId/transcript', {'text': text}));

  @override
  Future<TransferPreview> assessTransfer(String memberId, TransferDraft draft) async =>
      TransferPreview.fromJson(await api.post('/transaction/assess', draft.toJson(memberId)));

  @override
  Future<TransferResult> submitTransfer(String memberId, TransferDraft draft) async =>
      TransferResult.fromJson(await api.post('/transaction/transfer', draft.toJson(memberId)));

  @override
  Future<ConfirmationQuestionResult> fetchConfirmationQuestion(String memberId, String actionKind, {int? amount}) async =>
      ConfirmationQuestionResult.fromJson(
        await api.post('/banking/question', {
          'member_id': memberId,
          'action_kind': actionKind,
          'amount': ?amount,
        }),
      );

  @override
  Future<SavingsCancelResult> cancelSavings(
    String memberId,
    String accountId, {
    String? questionAnswer,
    bool confirmed = false,
  }) async => SavingsCancelResult.fromJson(
    await api.post('/banking/savings/cancel', {
      'member_id': memberId,
      'account_id': accountId,
      'question_answer': ?questionAnswer,
      'confirmed': confirmed,
    }),
  );

  @override
  Future<LoanQuote> quoteLoan(int amount) async =>
      LoanQuote.fromJson(asJson((await api.post('/banking/loan/quote', {'amount': amount}))['quote']));

  @override
  Future<LoanLimitResult> checkLoanLimit(String memberId, {String? questionAnswer, bool confirmed = false}) async =>
      LoanLimitResult.fromJson(
        await api.post('/banking/loan/limit', {
          'member_id': memberId,
          'question_answer': ?questionAnswer,
          'confirmed': confirmed,
        }),
      );

  @override
  Future<LoanApplyResult> applyLoan(
    String memberId,
    int amount, {
    String? questionAnswer,
    bool confirmed = false,
  }) async => LoanApplyResult.fromJson(
    await api.post('/banking/loan/apply', {
      'member_id': memberId,
      'amount': amount,
      'question_answer': ?questionAnswer,
      'confirmed': confirmed,
    }),
  );

  @override
  Future<PaymentResult> pay(String memberId, String merchantId) async =>
      PaymentResult.fromJson(await api.post('/payments/pay', {'member_id': memberId, 'merchant_id': merchantId}));

  @override
  Future<PaymentResult> requestPayment(String memberId, String merchantId) async => PaymentResult.fromJson(
    await api.post('/payments/request-approval', {'member_id': memberId, 'merchant_id': merchantId}),
  );

  @override
  Future<ModeChangeResult> setMode(String memberId, String modeId, {required bool byGuardian}) async =>
      ModeChangeResult.fromJson(
        await api.post('/modes', {'member_id': memberId, 'mode': modeId, 'actor': byGuardian ? 'GUARDIAN' : 'SELF'}),
      );

  @override
  Future<void> setDailyLimit(String memberId, int value) =>
      api.post('/guardian/limits', {'member_id': memberId, 'daily_limit': value});

  @override
  Future<void> setSleepGuard(String memberId, bool enabled) =>
      api.post('/guardian/sleep-guard', {'member_id': memberId, 'enabled': enabled});

  @override
  Future<DecisionResult> decide(String requestId, String guardianId, {required bool approve}) async =>
      DecisionResult.fromJson(
        await api.post('/guardian/callback-decision', {
          'transaction_id': requestId,
          'guardian_id': guardianId,
          'decision': approve ? 'APPROVE' : 'REJECT',
        }),
      );

  @override
  Future<DecisionResult> extendHold(String requestId, String guardianId) async => DecisionResult.fromJson(
    await api.post('/guardian/callback-decision', {
      'transaction_id': requestId,
      'guardian_id': guardianId,
      'decision': 'EXTEND',
    }),
  );

  @override
  Future<DecisionResult> cancelRequest(String requestId, String memberId) async =>
      DecisionResult.fromJson(await api.post('/transaction/cancel', {'request_id': requestId, 'member_id': memberId}));

  @override
  Future<DecisionResult> reconfirmHold(String requestId, String memberId, {required bool confirm}) async =>
      DecisionResult.fromJson(
        await api.post('/transaction/reconfirm', {'request_id': requestId, 'member_id': memberId, 'confirm': confirm}),
      );

  @override
  Future<void> dismissNotice(String memberId, String noticeId) =>
      api.post('/members/$memberId/notices/$noticeId/dismiss');

  @override
  Future<PairingCodeResult> issuePairingCode(String guardianId, String memberId) async =>
      PairingCodeResult.fromJson(
        await api.post('/guardian/pairing-code', {'guardian_id': guardianId, 'member_id': memberId}),
      );

  @override
  Future<PairingConnectResult> connectPairing(String memberId, String code, {required bool consented}) async =>
      PairingConnectResult.fromJson(
        await api.post('/pairing/connect', {'member_id': memberId, 'code': code, 'consented': consented}),
      );

  @override
  Future<List<IntegrationLogEntry>> integrationLogs({int limit = 30}) async {
    final body = await api.get('/integrations/logs', query: {'limit': '$limit'});
    return asList(body['logs'], IntegrationLogEntry.fromJson);
  }

  @override
  Future<UserFeedbackResult> submitFeedback(String memberId, {required String category, String message = ''}) async =>
      UserFeedbackResult.fromJson(
        await api.post('/feedback', {
          'member_id': memberId,
          'category': category,
          'message': message,
        }),
      );

  @override
  Future<void> resetDemo() => api.post('/demo/reset');

  @override
  Future<void> dispose() async {
    await realtime.dispose();
    api.close();
  }
}
