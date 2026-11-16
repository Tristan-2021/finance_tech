/// 테스트용 가짜 저장소와 시연 데이터. 앱·기능 패키지의 위젯 테스트에서 씁니다.
library;

import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_errors/core_errors.dart';

import 'core_family.dart';

Map<String, dynamic> scamSmsJson({
  String id = 'sms-phishing-1',
  String memberId = 'senior',
  String senderName = '금융감독원 민원실(사칭)',
  String senderPhone = '02-0000-1332',
  String body =
      '[금융감독원] 김순자님 명의 대포통장 개설 사건이 접수되었습니다. 즉시 본인 확인 바랍니다. 사건 확인 http://fss-verify.invalid/case/8821 담당 조사관 02-0000-1332',
  DateTime? now,
}) {
  final t = (now ?? DateTime.now()).toUtc();
  return {
    'id': id,
    'member_id': memberId,
    'sender_name': senderName,
    'sender_phone': senderPhone,
    'body': body,
    'level': 'danger',
    'reasons': [
      '공공·금융기관 사칭 의심 표현(금융감독원)이 들어 있어요',
      '불안을 주거나 확인을 재촉하는 표현(대포통장)이 있어요',
      '문자 안에 출처가 불분명한 인터넷 주소(링크)가 들어 있어요',
    ],
    'explanation': '기관이나 회사를 사칭해 링크를 누르게 하거나 전화를 유도하는 사기 의심 문자예요. 문자 속 링크를 누르거나 적힌 번호로 전화하지 마세요.',
    'links': ['http://fss-verify.invalid/case/8821'],
    'phones': ['02-0000-1332'],
    'at': t.toIso8601String(),
  };
}

Map<String, dynamic> normalSmsJson({
  String id = 'sms-normal-1',
  String memberId = 'senior',
  String senderName = '안심택배',
  String senderPhone = '1588-0000',
  String body = '[안심택배] 김순자님 주문하신 건강즙 상품이 오늘 오후 배송 완료되었습니다. 문 앞을 확인해 주세요.',
  DateTime? now,
}) {
  final t = (now ?? DateTime.now()).toUtc();
  return {
    'id': id,
    'member_id': memberId,
    'sender_name': senderName,
    'sender_phone': senderPhone,
    'body': body,
    'level': 'low',
    'reasons': <String>[],
    'explanation': '사기 의심 징후가 없는 일반 문자예요.',
    'links': <String>[],
    'phones': <String>['1588-0000'],
    'at': t.toIso8601String(),
  };
}

Map<String, dynamic> demoSnapshotJson({
  DateTime? now,
  bool seniorFrozen = false,
  bool seniorCautionMode = false,
  List<Map<String, dynamic>> requests = const [],
  List<Map<String, dynamic>>? seniorSmsMessages,
  String childMode = 'school',
}) {
  final t = (now ?? DateTime.now()).toUtc();
  String ago(Duration d) => t.subtract(d).toIso8601String();
  Map<String, dynamic> merchant(String id, String name, String cat, String label, int amount, Map<String, dynamic> check) =>
      {'id': id, 'name': name, 'category': cat, 'category_label': label, 'mcc': '0000', 'amount': amount, 'emoji': '', 'check': check};
  const ok = {'ok': true, 'code': 'ok', 'message': '', 'can_request': false};
  final defaultSms = <Map<String, dynamic>>[
    normalSmsJson(id: 'sms-seed-delivery', now: t.subtract(const Duration(hours: 5))),
    normalSmsJson(
      id: 'sms-seed-family',
      senderName: '김사랑 (딸)',
      senderPhone: '010-0000-1024',
      body: '엄마, 이번 주말에 민준이랑 반찬 가지고 갈게요. 식사 꼭 챙겨 드세요!',
      now: t.subtract(const Duration(hours: 18)),
    ),
    normalSmsJson(
      id: 'sms-seed-bank',
      senderName: '핑거벨은행',
      senderPhone: '1599-0000',
      body: '[핑거벨] 김순자님 연금 650,000원이 입출금 통장(5678)으로 입금되었습니다.',
      now: t.subtract(const Duration(hours: 26)),
    ),
  ];

  return {
    'server_time': t.toIso8601String(),
    'config': {
      'hold_seconds': 1800,
      'reconfirm_seconds': 86400,
      'approval_timeout_seconds': 180,
      'caution_mode_hours': 24,
      'freeze_hours': 24,
    },
    'guardian': {
      'id': 'guardian',
      'name': '김사랑',
      'avatar': '',
      'phone': '010-••••-1024',
      'banking': {
        'id': 'guardian',
        'role': 'GUARDIAN',
        'name': '김사랑',
        'relation_label': '보호자',
        'guardian_relation': '본인',
        'balance': 3480000,
        'account': {'id': 'a4', 'name': '핑거벨 주거래 통장', 'bank': '핑거벨', 'number': '3333-00-••••-1024', 'balance': 3480000},
        'accounts': [
          {'id': 'a4', 'name': '핑거벨 주거래 통장', 'bank': '핑거벨', 'number': '3333-00-••••-1024', 'balance': 3480000},
        ],
        'spent_today': 11000,
        'daily_limit': 5000000,
        'limit_range': {'min': 1000000, 'max': 10000000, 'step': 1000000},
        'approval_threshold': 0,
        'avg_transfer': 200000,
        'mode': 'normal',
        'modes': ['normal'],
        'is_frozen': false,
        'contacts': [
          {'id': 'c-g-mother', 'name': '김순자', 'relation': '어머니', 'bank': '핑거벨', 'number': '333-••••-5678'},
          {'id': 'c-g-son', 'name': '이민준', 'relation': '아들', 'bank': '핑거벨', 'number': '333-••••-0917'},
        ],
        'ledger': [
          {'id': 'g1', 'kind': 'out', 'title': '점심 식당', 'desc': '식당', 'amount': -11000, 'at': ago(const Duration(hours: 2))},
          {'id': 'g2', 'kind': 'out', 'title': '김순자님께 송금', 'desc': '송금', 'amount': -200000, 'at': ago(const Duration(hours: 50))},
        ],
        'notices': [],
        'merchants': [merchant('g-mart', '행복마트', 'grocery', '마트', 52300, ok)],
      },
    },
    'members': [
      {
        'id': 'senior',
        'role': 'SENIOR',
        'name': '김순자',
        'nickname': null,
        'relation_label': '어머니',
        'guardian_relation': '딸',
        'balance': 2350000,
        'account': {'id': 'a1', 'name': '핑거벨 입출금 통장', 'bank': '핑거벨', 'number': '3333-12-••••-5678', 'balance': 2350000},
        'accounts': [
          {'id': 'a1', 'name': '핑거벨 입출금 통장', 'bank': '핑거벨', 'number': '3333-12-••••-5678', 'balance': 2350000},
          {'id': 'a2', 'name': '노후 생활비 통장', 'bank': '핑거벨', 'number': '3333-15-••••-2086', 'balance': 18400000, 'kind': 'SAVINGS'},
        ],
        'spent_today': 12400,
        'daily_limit': 1000000,
        'limit_range': {'min': 100000, 'max': 3000000, 'step': 100000},
        'approval_threshold': 300000,
        'avg_transfer': 100000,
        'mode': 'normal',
        'modes': ['normal', 'hospital'],
        'require_approval_to_loosen': false,
        'sleep_guard': true,
        'sleep_active': false,
        'is_frozen': seniorFrozen,
        'frozen_until': seniorFrozen ? t.add(const Duration(hours: 24)).toIso8601String() : null,
        'frozen_source': seniorFrozen ? 'LONG_PRESS' : null,
        'caution_mode': seniorCautionMode,
        'caution_until': seniorCautionMode ? t.add(const Duration(hours: 24)).toIso8601String() : null,
        'sms_messages': seniorSmsMessages ?? defaultSms,
        'contacts': [
          {'id': 'c-sarang', 'name': '김사랑', 'relation': '딸', 'bank': '핑거벨', 'number': '333-••••-1024'},
          {'id': 'c-younghee', 'name': '박영희', 'relation': '이웃', 'bank': '농협', 'number': '302-••••-4471'},
        ],
        'ledger': [
          {'id': 't1', 'kind': 'out', 'title': '온누리 약국', 'desc': '약국', 'amount': -12400, 'at': ago(const Duration(hours: 3))},
          {'id': 't2', 'kind': 'in', 'title': '연금 입금', 'desc': '입금', 'amount': 650000, 'at': ago(const Duration(hours: 26))},
          {'id': 't5', 'kind': 'protect', 'title': '낯선 계좌 송금 차단', 'desc': '보호자가 거절했어요', 'amount': 0, 'tag': '거절', 'tone': 'red', 'at': ago(const Duration(hours: 120))},
        ],
        'notices': [],
        'merchants': [
          merchant('s-pharmacy', '온누리 약국', 'pharmacy', '약국', 12400, ok),
          merchant('s-gift', '상품권 대량 구매', 'giftcard', '상품권', 500000,
              {'ok': false, 'code': 'approval', 'message': '300,000원 이상은 보호자 확인이 필요해요.', 'can_request': true}),
        ],
      },
      {
        'id': 'child',
        'role': 'CHILD',
        'name': '이민준',
        'nickname': '민준',
        'relation_label': '아들',
        'guardian_relation': '엄마',
        'balance': 120000,
        'account': {'id': 'a3', 'name': '민준이 용돈 통장', 'bank': '핑거벨', 'number': '3333-31-••••-0917', 'balance': 120000},
        'accounts': [
          {'id': 'a3', 'name': '민준이 용돈 통장', 'bank': '핑거벨', 'number': '3333-31-••••-0917', 'balance': 120000},
        ],
        'spent_today': 8500,
        'daily_limit': 20000,
        'limit_range': {'min': 5000, 'max': 100000, 'step': 5000},
        'approval_threshold': 10000,
        'avg_transfer': 5000,
        'mode': childMode,
        'modes': ['normal', 'school', 'hospital'],
        'require_approval_to_loosen': true,
        'sleep_guard': true,
        'is_frozen': false,
        'contacts': [
          {'id': 'c-mom', 'name': '김사랑', 'relation': '엄마', 'bank': '핑거벨', 'number': '333-••••-1024'},
        ],
        'ledger': [
          {'id': 'k1', 'kind': 'out', 'title': '우리동네 편의점', 'desc': '편의점', 'amount': -3550, 'at': ago(const Duration(hours: 1))},
        ],
        'notices': [],
        'merchants': [
          merchant('c-bus', '버스·지하철', 'transport', '교통', 1450, ok),
          merchant('c-game', '게임 아이템 상점', 'game', '게임', 33000,
              {'ok': false, 'code': 'mode', 'message': '등교 모드에서는 게임 결제가 막혀 있어요.', 'can_request': true}),
        ],
      },
    ],
    'requests': requests,
    'alerts': [
      {'id': 'al1', 'member_id': 'child', 'title': '우리동네 편의점 결제', 'amount': 3550, 'status': 'ok', 'at': ago(const Duration(hours: 1))},
    ],
    'assessments': [],
    'stats': {'blocked_today': 0, 'risky_transfers': 1},
    'catalog': {
      'modes': [
        {'id': 'normal', 'label': '일반 모드', 'short': '일반', 'icon': '', 'desc': '모든 결제처를 쓸 수 있어요', 'allow': null},
        {'id': 'school', 'label': '등교 모드', 'short': '등교', 'icon': '', 'desc': '교통·문구점·편의점·서점·식당만 결제돼요', 'allow': ['transport']},
        {'id': 'hospital', 'label': '병원 모드', 'short': '병원', 'icon': '', 'desc': '병원·약국·교통·마트만 결제돼요', 'allow': ['hospital']},
      ],
      'banks': ['핑거벨', '국민', '신한'],
    },
  };
}

Map<String, dynamic> pendingTransferJson({
  String id = 'req-1',
  String memberId = 'senior',
  String status = 'pending',
  DateTime? now,
}) {
  final t = (now ?? DateTime.now()).toUtc();
  return {
    'id': id,
    'member_id': memberId,
    'type': 'transfer',
    'title': '이정민님께 송금',
    'amount': 500000,
    'detail': '국민 123-••••-7788 · 처음 보내는 계좌',
    'status': status,
    'channel': '앱 알림',
    'created_at': t.toIso8601String(),
    'expires_at': t.add(const Duration(minutes: 30)).toIso8601String(),
    'reconfirm_until': status == 'reconfirm' ? t.add(const Duration(hours: 24)).toIso8601String() : null,
    'risk': {
      'score': 79,
      'level': 'high',
      'needs_approval': true,
      'explanation': '처음 보내는 계좌예요 · 평소보다 훨씬 큰 금액이에요',
      'signals': [
        {'id': 'new', 'label': '처음 보내는 계좌예요', 'weight': 35},
        {'id': 'large', 'label': '평소보다 훨씬 큰 금액이에요', 'weight': 30},
      ],
    },
  };
}

/// 메모리에서 동작하는 가짜 저장소. 호출 기록은 [calls]에 남습니다.
class FakeFamilyRepository implements FamilyRepository {
  Map<String, dynamic> snapshotJson;
  final List<String> calls = [];
  final _events = StreamController<FamilyEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  bool failNetwork = false;
  String? failDecisionReason;
  SmsRiskLevel? forceSmsLevel;

  FakeFamilyRepository([Map<String, dynamic>? snapshot]) : snapshotJson = snapshot ?? demoSnapshotJson();

  void emitEvent(FamilyEvent e) => _events.add(e);

  Future<T> _call<T>(String name, T value) async {
    calls.add(name);
    if (failNetwork) throw const ApiException(Failure('서버에 연결할 수 없어요.', 'network'));
    return value;
  }

  @override
  Stream<FamilyEvent> get events => _events.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  void connect() => _connection.add(true);

  @override
  Future<FamilySnapshot> fetchState() => _call('fetchState', FamilySnapshot.fromJson(snapshotJson));

  @override
  Future<FreezeResult> freeze(String memberId, SosTrigger trigger, {double? intensity}) => _call(
    'freeze:$memberId:${trigger.apiValue}',
    FreezeResult(alreadyFrozen: false, frozenAccountsCount: 2, guardianNotified: true, expiresAt: DateTime.now().add(const Duration(hours: 24))),
  );

  @override
  Future<void> requestUnfreeze(String memberId) => _call('requestUnfreeze:$memberId', null);

  @override
  Future<void> unfreeze(String memberId, String guardianId) => _call('unfreeze:$memberId', null);

  @override
  Future<void> releaseCautionMode(String memberId, String guardianId) => _call('releaseCautionMode:$memberId', null);

  @override
  Future<SmsReceiveResult> receiveSms(
    String memberId, {
    String? kind,
    String? senderPhone,
    String? senderName,
    String? body,
  }) {
    final k = (kind ?? 'phishing').toLowerCase();
    final defaultLevel = (k.contains('phish') || k == 'scam' || k == 'danger')
        ? SmsRiskLevel.danger
        : SmsRiskLevel.low;
    final level = forceSmsLevel ?? defaultLevel;
    final isDanger = level == SmsRiskLevel.danger;
    final now = DateTime.now().toUtc();
    final msgJson = defaultLevel == SmsRiskLevel.danger
        ? scamSmsJson(
            id: 'sms-${calls.length + 1}',
            memberId: memberId,
            senderName: senderName ?? '금융감독원 민원실(사칭)',
            senderPhone: senderPhone ?? '02-0000-1332',
            body:
                body ??
                '[금융감독원] 김순자님 명의 대포통장 개설 사건이 접수되었습니다. 즉시 본인 확인 바랍니다. 사건 확인 http://fss-verify.invalid/case/8821 담당 조사관 02-0000-1332',
            now: now,
          )
        : normalSmsJson(
            id: 'sms-${calls.length + 1}',
            memberId: memberId,
            senderName: senderName ?? '안심택배',
            senderPhone: senderPhone ?? '1588-0000',
            body: body ?? '[안심택배] 김순자님 주문하신 건강즙 상품이 오늘 오후 배송 완료되었습니다. 문 앞을 확인해 주세요.',
            now: now,
          );
    msgJson['level'] = level.name;
    if (level == SmsRiskLevel.low) {
      msgJson['reasons'] = <String>[];
      msgJson['explanation'] = '사기 의심 징후가 없는 일반 문자예요.';
    } else if (level == SmsRiskLevel.caution) {
      msgJson['explanation'] = '문자 안에 확인이 필요한 링크나 표현이 있어요.';
    }
    final members = snapshotJson['members'];
    var caution = false;
    DateTime? cautionUntil;
    if (members is List) {
      for (final m in members) {
        if (m is Map<String, dynamic> && m['id'] == memberId) {
          final existing = (m['sms_messages'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
          m['sms_messages'] = [msgJson, ...existing];
          m.remove('sms_conversations');
          if (isDanger) {
            m['caution_mode'] = true;
            cautionUntil = now.add(const Duration(hours: 24));
            m['caution_until'] = cautionUntil.toIso8601String();
          }
          caution = m['caution_mode'] == true;
        }
      }
    }
    return _call(
      'receiveSms:$memberId:${kind ?? 'custom'}',
      SmsReceiveResult(
        status: 'received',
        message: SmsMessage.fromJson(msgJson),
        cautionMode: caution,
        cautionUntil: cautionUntil?.toLocal(),
      ),
    );
  }

  RiskAssessment _newAccountRisk(String memberId, int amount) {
    final caution = amount < 100000;
    return RiskAssessment(
      score: caution ? 40 : 79,
      level: caution ? RiskLevel.caution : RiskLevel.high,
      needsApproval: !caution && memberId != 'guardian',
      explanation: '처음 보내는 계좌예요',
      signals: const [RiskSignal(id: 'new', label: '처음 보내는 계좌예요', weight: 35)],
    );
  }

  /// 보호자 본인 송금은 서버처럼 위험해도 승인 없이 보냅니다.
  @override
  Future<TransferPreview> assessTransfer(String memberId, TransferDraft draft) => _call(
    'assess:$memberId:${draft.amount}',
    TransferPreview(
      recipient: _recipient(draft),
      amount: draft.amount,
      risk: draft.newAccount != null
          ? _newAccountRisk(memberId, draft.amount)
          : const RiskAssessment(score: 5, level: RiskLevel.safe),
    ),
  );

  @override
  Future<TransferResult> submitTransfer(String memberId, TransferDraft draft) => _call(
    'transfer:$memberId:${draft.amount}${draft.confirmed ? ':confirmed' : ''}',
    draft.newAccount != null && memberId != 'guardian'
        ? (draft.amount < 100000
              ? (draft.confirmed
                    ? TransferResult(status: 'done', amount: draft.amount, recipient: _recipient(draft))
                    : TransferResult(
                        status: 'caution',
                        amount: draft.amount,
                        recipient: _recipient(draft),
                        risk: _newAccountRisk(memberId, draft.amount),
                      ))
              : TransferResult(status: 'pending', request: ApprovalRequest.fromJson(pendingTransferJson())))
        : TransferResult(status: 'done', amount: draft.amount, recipient: _recipient(draft)),
  );

  Recipient _recipient(TransferDraft draft) => Recipient(
    name: draft.newAccount?.name ?? '김사랑',
    bank: draft.newAccount?.bank ?? '핑거벨',
    number: '333-••••-1024',
    isNew: draft.newAccount != null,
  );

  Merchant _merchant(String memberId, String merchantId) =>
      FamilySnapshot.fromJson(snapshotJson).member(memberId).merchant(merchantId)!;

  @override
  Future<PaymentResult> pay(String memberId, String merchantId) {
    final m = _merchant(memberId, merchantId);
    return _call('pay:$memberId:$merchantId',
        PaymentResult(ok: m.check.ok, code: m.check.code, message: m.check.message, canRequest: m.check.canRequest, merchant: m));
  }

  @override
  Future<PaymentResult> requestPayment(String memberId, String merchantId) =>
      _call('requestPayment:$memberId:$merchantId', PaymentResult(ok: true, code: 'pending', merchant: _merchant(memberId, merchantId)));

  @override
  Future<ModeChangeResult> setMode(String memberId, String modeId, {required bool byGuardian}) =>
      _call('mode:$memberId:$modeId:${byGuardian ? 'guardian' : 'self'}', const ModeChangeResult('done'));

  @override
  Future<void> setDailyLimit(String memberId, int value) => _call('limit:$memberId:$value', null);

  @override
  Future<void> setSleepGuard(String memberId, bool enabled) => _call('sleep:$memberId:$enabled', null);

  void _updateRequestStatus(String requestId, String status, {String? failReason, bool deductBalance = false}) {
    final reqs = snapshotJson['requests'];
    if (reqs is! List) return;
    for (final item in reqs) {
      if (item is Map<String, dynamic> && item['id'] == requestId) {
        item['status'] = status;
        if (failReason != null) item['fail_reason'] = failReason;
        if (deductBalance) {
          final memberId = item['member_id'];
          final amount = (item['amount'] as int?) ?? 0;
          final members = snapshotJson['members'];
          if (members is List && amount > 0) {
            for (final m in members) {
              if (m is Map<String, dynamic> && m['id'] == memberId) {
                m['balance'] = ((m['balance'] as int?) ?? 0) - amount;
              }
            }
          }
        }
      }
    }
  }

  @override
  Future<DecisionResult> decide(String requestId, String guardianId, {required bool approve}) {
    if (approve && failDecisionReason != null) {
      _updateRequestStatus(requestId, 'failed', failReason: failDecisionReason);
      return _call('decide:$requestId:approve', DecisionResult('failed', message: failDecisionReason!));
    }
    _updateRequestStatus(requestId, approve ? 'approved' : 'rejected', deductBalance: approve);
    return _call('decide:$requestId:${approve ? 'approve' : 'reject'}', DecisionResult(approve ? 'approved' : 'rejected'));
  }

  @override
  Future<DecisionResult> extendHold(String requestId, String guardianId) =>
      _call('extend:$requestId', const DecisionResult('extended'));

  @override
  Future<DecisionResult> cancelRequest(String requestId, String memberId) {
    _updateRequestStatus(requestId, 'cancelled');
    return _call('cancel:$requestId:$memberId', const DecisionResult('cancelled'));
  }

  @override
  Future<DecisionResult> reconfirmHold(String requestId, String memberId, {required bool confirm}) {
    if (confirm && failDecisionReason != null) {
      _updateRequestStatus(requestId, 'failed', failReason: failDecisionReason);
      return _call('reconfirm:$requestId:$memberId:$confirm', DecisionResult('failed', message: failDecisionReason!));
    }
    _updateRequestStatus(requestId, confirm ? 'approved' : 'cancelled', deductBalance: confirm);
    return _call('reconfirm:$requestId:$memberId:$confirm', DecisionResult(confirm ? 'approved' : 'cancelled'));
  }

  @override
  Future<void> dismissNotice(String memberId, String noticeId) => _call('dismiss:$noticeId', null);

  @override
  Future<List<IntegrationLogEntry>> integrationLogs({int limit = 30}) => _call('logs', const <IntegrationLogEntry>[]);

  @override
  Future<void> resetDemo() => _call('reset', null);

  @override
  Future<void> dispose() async {
    await _events.close();
    await _connection.close();
  }
}
