/// 테스트용 가짜 저장소와 시연 데이터. 앱·기능 패키지의 위젯 테스트에서 씁니다.
library;

import 'dart:async';
import 'dart:math' as math;

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
  String senderPhone = '02-0000-5880',
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
    'phones': <String>[senderPhone],
    'at': t.toIso8601String(),
  };
}

List<Map<String, dynamic>> defaultCallScriptsJson() => [
  {
    'id': 'phishing',
    'kind': 'phishing',
    'title': '사기 대본 (금융감독원 사칭 → 적금 해지 요구)',
    'caller_name': '금융감독원 민원실(사칭)',
    'caller_phone': '02-0000-1332',
    'lines': [
      '여기는 금융감독원 민원실 김철수 조사관입니다. 어르신 명의 대포통장이 개설되어 사건이 접수되었습니다.',
      '지금 당장 노후 적금을 만기 전 해지하시고 금융감독원 안전계좌로 전액 이체하셔야 자금을 보호할 수 있습니다.',
      '수사 기밀이니 가족이나 은행 직원에게는 절대 비밀로 하시고 지금 바로 처리해 주세요.',
    ],
  },
  {
    'id': 'normal',
    'kind': 'normal',
    'title': '정상 대본 (가족 안부)',
    'caller_name': '김사랑 (딸)',
    'caller_phone': '010-0000-1024',
    'lines': [
      '엄마, 오늘 점심 식사는 맛있게 챙겨 드셨어요?',
      '이번 주말에 민준이랑 좋아하는 반찬 가지고 집에 들를게요.',
      '날씨가 쌀쌀하니까 외출하실 때 따뜻한 옷 챙겨 입으세요.',
    ],
  },
];

Map<String, dynamic> demoSnapshotJson({
  DateTime? now,
  bool seniorFrozen = false,
  bool seniorCautionMode = false,
  List<Map<String, dynamic>> requests = const [],
  List<Map<String, dynamic>>? seniorSmsMessages,
  Map<String, dynamic>? seniorActiveIncident,
  List<Map<String, dynamic>> incidents = const [],
  Map<String, dynamic>? activeCall,
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
      senderPhone: '02-0000-5990',
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
          {
            'id': 'a2',
            'name': '노후 생활비 통장',
            'bank': '핑거벨',
            'number': '3333-15-••••-2086',
            'balance': 18400000,
            'kind': 'SAVINGS',
            'interest_rate': 4.2,
            'early_cancel_rate': 1.0,
            'maturity_date': t.add(const Duration(days: 180)).toIso8601String(),
            'accrued_interest': 1159200,
            'status': 'active',
            'early_cancel_preview': {
              'principal': 18400000,
              'interest_rate': 4.2,
              'early_cancel_rate': 1.0,
              'accrued_interest': 1159200,
              'early_cancel_interest': 276000,
              'reduced_interest': 883200,
              'payout_amount': 18676000,
            },
          },
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
        'paired_at': ago(const Duration(days: 30)),
        'consent_at': ago(const Duration(days: 30)),
        'active_incident': seniorActiveIncident,
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
        'paired_at': ago(const Duration(days: 30)),
        'consent_at': ago(const Duration(days: 30)),
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
    'incidents': [
      ?seniorActiveIncident,
      ...incidents,
    ],
    'active_call': activeCall,
    'calls': activeCall != null ? [activeCall] : <Map<String, dynamic>>[],
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
      'call_scripts': defaultCallScriptsJson(),
      'loan_product': {
        'id': 'loan-senior-1',
        'name': '핑거벨 안심 생활자금 대출',
        'bank': '핑거벨',
        'interest_rate': 5.4,
        'is_variable_rate': true,
        'prepayment_fee_rate': 0.6,
        'repayment_method': '원리금균등분할상환',
        'term_months': 24,
        'repayment_cycle': '매월 같은 날',
        'min_amount': 1000000,
        'max_limit': 20000000,
        'delinquency_rate': 8.4,
        'withdrawal_right_days': 14,
      },
    },
  };
}

Map<String, dynamic> pendingTransferJson({
  String id = 'req-1',
  String memberId = 'senior',
  String status = 'pending',
  String? incidentId,
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
    'incident_id': ?incidentId,
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

Map<String, dynamic> incidentJson({
  String id = 'inc-1',
  String memberId = 'senior',
  String status = 'open',
  String? endedBy,
  DateTime? now,
  List<Map<String, dynamic>>? items,
}) {
  final t = (now ?? DateTime.now()).toUtc();
  final started = t.subtract(const Duration(minutes: 20));
  return {
    'id': id,
    'member_id': memberId,
    'status': status,
    'started_at': started.toIso8601String(),
    'expires_at': started.add(const Duration(hours: 24)).toIso8601String(),
    'ended_at': status == 'closed' ? t.toIso8601String() : null,
    'ended_by': status == 'closed' ? (endedBy ?? 'guardian') : null,
    'items': items ??
        [
          {
            'id': 'ev-1',
            'kind': 'sms',
            'summary': '위험 문자 수신 (금융감독원 민원실(사칭)) · 기관 사칭 의심',
            'at': started.toIso8601String(),
          },
          {
            'id': 'ev-2',
            'kind': 'call',
            'summary': '위험 통화 감지 (금융감독원 민원실(사칭)) · 적금 해지 요구',
            'at': started.add(const Duration(minutes: 3)).toIso8601String(),
          },
          {
            'id': 'ev-3',
            'kind': 'action',
            'summary': '노후 생활비 통장 만기 전 해지 시도 (18,676,000원)',
            'at': started.add(const Duration(minutes: 6)).toIso8601String(),
          },
          {
            'id': 'ev-4',
            'kind': 'answer',
            'summary': '확인 질문 응답: 금융감독원·검찰·은행 직원이 해지하라고 했어요',
            'at': started.add(const Duration(minutes: 7)).toIso8601String(),
          },
          {
            'id': 'ev-5',
            'kind': 'judgment',
            'summary': '만기 전 해지 시도 판정 danger · 사기 의심 연락 뒤 시도예요',
            'at': started.add(const Duration(minutes: 7, seconds: 5)).toIso8601String(),
          },
          {
            'id': 'ev-6',
            'kind': 'hold',
            'summary': '노후 생활비 통장 만기 전 해지 18,676,000원 보류',
            'at': started.add(const Duration(minutes: 7, seconds: 10)).toIso8601String(),
          },
          if (status == 'closed')
            {
              'id': 'ev-7',
              'kind': 'guardian',
              'summary': '주의 모드 해제 (보호자 해제)',
              'at': t.toIso8601String(),
            },
        ],
  };
}

/// 메모리에서 동작하는 가짜 저장소. 호출 기록은 [calls]에 남습니다.
class FakeFamilyRepository implements FamilyRepository {
  Map<String, dynamic> snapshotJson;
  final List<String> calls = [];
  final List<Map<String, dynamic>> sentSignals = [];
  final _events = StreamController<FamilyEvent>.broadcast();
  final _rtcSignals = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  bool failNetwork = false;
  String? failDecisionReason;
  SmsRiskLevel? forceSmsLevel;
  String? forcePairingCode;
  final Map<String, ({String guardianId, String memberId, DateTime expiresAt, bool used})> _pairingCodes = {};
  final List<Map<String, dynamic>> submittedFeedback = [];
  int _pairingSeq = 0;

  FakeFamilyRepository([Map<String, dynamic>? snapshot]) : snapshotJson = snapshot ?? demoSnapshotJson();

  void emitEvent(FamilyEvent e) => _events.add(e);
  void emitRtcSignal(Map<String, dynamic> signal) => _rtcSignals.add(signal);

  Future<T> _call<T>(String name, T value) async {
    calls.add(name);
    if (failNetwork) throw const ApiException(Failure('서버에 연결할 수 없어요.', 'network'));
    return value;
  }

  @override
  Stream<FamilyEvent> get events => _events.stream;

  @override
  Stream<Map<String, dynamic>> get rtcSignals => _rtcSignals.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  void connect() => _connection.add(true);

  @override
  void sendRtcSignal(Map<String, dynamic> signal) {
    sentSignals.add(signal);
    if (!_rtcSignals.isClosed) {
      _rtcSignals.add(signal);
    }
  }

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
  Future<void> releaseCautionMode(String memberId, String guardianId) {
    final now = DateTime.now().toUtc();
    final members = snapshotJson['members'];
    if (members is List) {
      for (final m in members) {
        if (m is Map<String, dynamic> && m['id'] == memberId) {
          m['caution_mode'] = false;
          m['caution_until'] = null;
          final active = m['active_incident'];
          if (active is Map<String, dynamic>) {
            active['status'] = 'closed';
            active['ended_at'] = now.toIso8601String();
            active['ended_by'] = 'guardian';
          }
          m['active_incident'] = null;
        }
      }
    }
    final incs = snapshotJson['incidents'];
    if (incs is List) {
      for (final inc in incs) {
        if (inc is Map<String, dynamic> && inc['member_id'] == memberId && inc['status'] == 'open') {
          inc['status'] = 'closed';
          inc['ended_at'] = now.toIso8601String();
          inc['ended_by'] = 'guardian';
        }
      }
    }
    return _call('releaseCautionMode:$memberId', null);
  }

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
            senderPhone: senderPhone ?? '02-0000-5880',
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

  static const _scamCallKeywords = <String>[
    '금융감독원',
    '금감원',
    '검찰',
    '수사관',
    '조사관',
    '대포통장',
    '명의도용',
    '안전계좌',
    '안전 계좌',
    '보호계좌',
    '적금 해지',
    '만기 전 해지',
    '적금을 만기 전 해지',
    '비밀로',
    '지금 당장',
    '지급정지',
    '구속영장',
  ];

  @override
  Future<CallSession> startCall({
    required String callerId,
    required String calleeId,
    String? peerPhone,
    String? peerName,
  }) {
    final now = DateTime.now().toUtc();
    final participants = {callerId, calleeId};
    final analyzed = participants.contains('counterpart') &&
        (participants.contains('senior') || participants.contains('child'));
    final memberId = participants.contains('senior')
        ? 'senior'
        : (participants.contains('child') ? 'child' : null);
    final phone = peerPhone ?? (participants.contains('guardian') ? '010-••••-1024' : '02-0000-1332');
    final name = peerName ??
        (participants.contains('guardian')
            ? (callerId == 'guardian' ? '어머니 김순자' : '보호자 김사랑')
            : (phone == '02-0000-1332' ? '금융감독원 민원실(사칭)' : '시연 상대'));
    final callJson = <String, dynamic>{
      'id': 'call-${calls.length + 1}',
      'caller_id': callerId,
      'callee_id': calleeId,
      'member_id': memberId,
      'peer_name': name,
      'peer_phone': phone,
      'status': 'ringing',
      'analyzed': analyzed,
      'warning_level': 'low',
      'warning_reasons': <String>[],
      'warning_explanation': '',
      'created_at': now.toIso8601String(),
    };
    snapshotJson['active_call'] = callJson;
    snapshotJson['calls'] = [callJson];
    return _call('startCall:$callerId:$calleeId:$phone', CallSession.fromJson(callJson));
  }

  @override
  Future<CallSession> answerCall(String callId) {
    final now = DateTime.now().toUtc();
    final callJson = (snapshotJson['active_call'] as Map<String, dynamic>?) ??
        <String, dynamic>{
          'id': callId,
          'caller_id': 'senior',
          'callee_id': 'counterpart',
          'member_id': 'senior',
          'peer_name': '금융감독원 민원실(사칭)',
          'peer_phone': '02-0000-1332',
          'status': 'active',
          'analyzed': true,
          'warning_level': 'low',
          'warning_reasons': <String>[],
          'warning_explanation': '',
          'created_at': now.toIso8601String(),
        };
    callJson['status'] = 'active';
    callJson['answered_at'] = now.toIso8601String();
    snapshotJson['active_call'] = callJson;
    snapshotJson['calls'] = [callJson];
    return _call('answerCall:$callId', CallSession.fromJson(callJson));
  }

  @override
  Future<CallSession> endCall(String callId) {
    final now = DateTime.now().toUtc();
    final callJson = (snapshotJson['active_call'] as Map<String, dynamic>?) ??
        <String, dynamic>{
          'id': callId,
          'caller_id': 'senior',
          'callee_id': 'counterpart',
          'member_id': 'senior',
          'peer_name': '시연 상대',
          'peer_phone': '02-0000-1332',
          'status': 'ended',
          'analyzed': true,
          'warning_level': 'low',
          'warning_reasons': <String>[],
          'warning_explanation': '',
          'created_at': now.toIso8601String(),
        };
    callJson['status'] = 'ended';
    callJson['ended_at'] = now.toIso8601String();
    final active = snapshotJson['active_call'];
    if (active is Map<String, dynamic> && (active['id'] == callId || callId.isEmpty)) {
      snapshotJson['active_call'] = null;
    }
    snapshotJson['calls'] = [callJson];
    return _call('endCall:$callId', CallSession.fromJson(callJson));
  }

  @override
  Future<CallAnalysisResult> sendCallAudio(
    String callId, {
    required String audioBase64,
    String audioFormat = 'wav',
  }) {
    final callJson = snapshotJson['active_call'] as Map<String, dynamic>?;
    final analyzed = callJson == null ? true : (callJson['analyzed'] as bool? ?? true);
    return _call(
      'sendCallAudio:$callId:$audioFormat',
      CallAnalysisResult(
        status: analyzed ? 'empty' : 'ignored',
        analyzed: analyzed,
        call: callJson != null ? CallSession.fromJson(callJson) : null,
        level: SmsRiskLevel.low,
      ),
    );
  }

  @override
  Future<CallAnalysisResult> sendCallTranscript(String callId, {required String text}) {
    final now = DateTime.now().toUtc();
    final callJson = (snapshotJson['active_call'] as Map<String, dynamic>?) ??
        <String, dynamic>{
          'id': callId,
          'caller_id': 'senior',
          'callee_id': 'counterpart',
          'member_id': 'senior',
          'peer_name': '금융감독원 민원실(사칭)',
          'peer_phone': '02-0000-1332',
          'status': 'active',
          'analyzed': true,
          'warning_level': 'low',
          'warning_reasons': <String>[],
          'warning_explanation': '',
          'created_at': now.toIso8601String(),
        };
    callJson['status'] = 'active';
    final analyzed = callJson['analyzed'] as bool? ?? true;
    if (!analyzed) {
      return _call(
        'sendCallTranscript:$callId:ignored',
        CallAnalysisResult(
          status: 'ignored',
          analyzed: false,
          call: CallSession.fromJson(callJson),
          level: SmsRiskLevel.low,
        ),
      );
    }
    final isDanger = _scamCallKeywords.any((kw) => text.contains(kw));
    const explanation = '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.';
    final reasons = isDanger
        ? const <String>[
            '공공·금융기관 사칭 의심 표현이 나왔어요',
            '적금·예금 해지나 안전 계좌 이체를 요구하는 표현이 나왔어요',
          ]
        : const <String>[];
    var caution = false;
    DateTime? cautionUntil;
    if (isDanger) {
      callJson['warning_level'] = 'danger';
      callJson['warning_reasons'] = reasons;
      callJson['warning_explanation'] = explanation;
      snapshotJson['active_call'] = callJson;
      snapshotJson['calls'] = [callJson];
      final memberId = (callJson['member_id'] as String?) ?? 'senior';
      final members = snapshotJson['members'];
      if (members is List) {
        for (final m in members) {
          if (m is Map<String, dynamic> && m['id'] == memberId) {
            m['caution_mode'] = true;
            cautionUntil = now.add(const Duration(hours: 24));
            m['caution_until'] = cautionUntil.toIso8601String();
            caution = true;
          }
        }
      }
      final alerts = (snapshotJson['alerts'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
      snapshotJson['alerts'] = [
        {
          'id': 'al-call-${calls.length + 1}',
          'member_id': memberId,
          'title': '보이스피싱 의심 통화 경고 (${callJson['peer_name'] ?? '시연 상대'})',
          'amount': 0,
          'status': 'danger',
          'at': now.toIso8601String(),
        },
        ...alerts,
      ];
    }
    return _call(
      'sendCallTranscript:$callId:${isDanger ? 'danger' : 'low'}',
      CallAnalysisResult(
        status: 'analyzed',
        analyzed: true,
        call: CallSession.fromJson(callJson),
        level: isDanger ? SmsRiskLevel.danger : SmsRiskLevel.low,
        reasons: reasons,
        explanation: isDanger ? explanation : '사기 의심 징후가 없는 일반 통화예요.',
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

  String? _activeIncidentId(String memberId) {
    final members = snapshotJson['members'];
    if (members is! List) return null;
    for (final m in members) {
      if (m is Map<String, dynamic> && m['id'] == memberId) {
        final inc = m['active_incident'];
        if (inc is Map<String, dynamic>) {
          return inc['id'] as String?;
        }
      }
    }
    return null;
  }

  bool _isCautionMode(String memberId) {
    final members = snapshotJson['members'];
    if (members is! List) return false;
    for (final m in members) {
      if (m is Map<String, dynamic> && m['id'] == memberId) {
        return m['caution_mode'] == true;
      }
    }
    return false;
  }

  int _avgTransfer(String memberId) {
    final members = snapshotJson['members'];
    if (members is! List) return 100000;
    for (final m in members) {
      if (m is Map<String, dynamic> && m['id'] == memberId) {
        return (m['avg_transfer'] as int?) ?? 100000;
      }
    }
    return 100000;
  }

  ConfirmationQuestion _questionFor(String actionKind) => switch (actionKind) {
    'savings_cancel' => const ConfirmationQuestion(
      actionKind: 'savings_cancel',
      question: '적금을 만기 전에 해지하려고 하시네요. 혹시 누가 해지하라고 했나요?',
      options: [
        '금융감독원·검찰·은행 직원이 해지하라고 했어요',
        '괜찮아요, 아는 사람이에요',
        '가족(보호자)과 이미 상의했어요',
        '잘 모르겠어요',
      ],
    ),
    'loan_apply' => const ConfirmationQuestion(
      actionKind: 'loan_apply',
      question: '대출을 신청하려고 하시네요. 혹시 누가 대출을 받으라고 했나요?',
      options: [
        '금융감독원·검찰·은행 직원이 대출을 받으라고 했어요',
        '괜찮아요, 아는 사람이에요',
        '가족(보호자)과 이미 상의했어요',
        '잘 모르겠어요',
      ],
    ),
    'loan_limit' => const ConfirmationQuestion(
      actionKind: 'loan_limit',
      question: '대출 한도를 조회하려고 하시네요. 혹시 누가 대출을 알아보라고 했나요?',
      options: [
        '금융감독원·검찰·은행 직원이 알아보라고 했어요',
        '괜찮아요, 아는 사람이에요',
        '가족(보호자)과 이미 상의했어요',
        '잘 모르겠어요',
      ],
    ),
    _ => const ConfirmationQuestion(
      actionKind: 'transfer',
      question: '평소보다 큰 금액을 보내려고 하시네요. 혹시 누가 이 돈을 보내라고 했나요?',
      options: [
        '금융감독원·검찰·수사관이 안전계좌로 보내라고 했어요',
        '괜찮아요, 아는 사람이에요',
        '가족(보호자)과 이미 상의했어요',
        '잘 모르겠어요',
      ],
    ),
  };

  String _classifyAnswer(String answer) {
    if (answer.contains('금융감독원') || answer.contains('검찰') || answer.contains('잘 모르겠어요')) {
      return 'danger';
    }
    if (answer.contains('가족') || answer.contains('보호자')) {
      return 'low';
    }
    return 'caution';
  }

  RiskAssessment _cautionRisk(String level, String answer) => switch (level) {
    'danger' => RiskAssessment(
      score: 85,
      level: RiskLevel.high,
      needsApproval: true,
      explanation: '사기 의심 연락 뒤에 이어진 시도로 보이스피싱 위험이 매우 높아요.',
      signals: [RiskSignal(id: 'inc-1', label: '확인 질문 응답: $answer', weight: 20)],
    ),
    'caution' => RiskAssessment(
      score: 45,
      level: RiskLevel.caution,
      needsApproval: false,
      explanation: '주의 모드 중 거래를 진행하고 있어요. 다시 한 번 확인해 주세요.',
      signals: [RiskSignal(id: 'inc-1', label: '확인 질문 응답: $answer', weight: 20)],
    ),
    _ => const RiskAssessment(
      score: 15,
      level: RiskLevel.safe,
      needsApproval: false,
      explanation: '보호자와 상의한 거래로 확인되어 진행해요.',
      signals: [RiskSignal(id: 'inc-1', label: '보호자와 이미 상의했어요', weight: 20)],
    ),
  };

  LoanQuote _calcLoanQuote(int amount) {
    const rate = 5.4;
    const months = 24;
    final monthlyRate = rate / 100.0 / 12.0;
    final factor = math.pow(1.0 + monthlyRate, months).toDouble();
    final monthly = (amount * (monthlyRate * factor) / (factor - 1.0)).round();
    final total = monthly * months;
    return LoanQuote(
      amount: amount,
      annualRate: rate,
      termMonths: months,
      monthlyPayment: monthly,
      totalInterest: math.max(0, total - amount),
      totalRepayment: total,
    );
  }

  /// 보호자 본인 송금은 서버처럼 위험해도 승인 없이 보냅니다.
  @override
  Future<TransferPreview> assessTransfer(String memberId, TransferDraft draft) => _call(
    'assess:$memberId:${draft.amount}',
    TransferPreview(
      recipient: _recipient(draft),
      amount: draft.amount,
      avgTransfer: _avgTransfer(memberId),
      needsQuestion: memberId != 'guardian' && _isCautionMode(memberId) && draft.amount > _avgTransfer(memberId),
      risk: draft.newAccount != null
          ? _newAccountRisk(memberId, draft.amount)
          : const RiskAssessment(score: 5, level: RiskLevel.safe),
    ),
  );

  @override
  Future<TransferResult> submitTransfer(String memberId, TransferDraft draft) {
    final inCaution = memberId != 'guardian' && _isCautionMode(memberId) && draft.amount > _avgTransfer(memberId);
    if (inCaution) {
      final ans = draft.questionAnswer?.trim() ?? '';
      if (ans.isEmpty) {
        return _call(
          'transfer:$memberId:${draft.amount}:question',
          TransferResult(status: 'question', amount: draft.amount, recipient: _recipient(draft), question: _questionFor('transfer')),
        );
      }
      final level = _classifyAnswer(ans);
      final risk = _cautionRisk(level, ans);
      final fdsHigh = draft.newAccount != null && draft.amount >= 100000;
      if (level == 'danger' || fdsHigh || draft.amount >= 300000) {
        final reqJson = pendingTransferJson(
          id: 'req-tr-${calls.length + 1}',
          memberId: memberId,
          incidentId: _activeIncidentId(memberId),
        );
        reqJson['amount'] = draft.amount;
        final existingReqs = (snapshotJson['requests'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
        snapshotJson['requests'] = [reqJson, ...existingReqs];
        return _call(
          'transfer:$memberId:${draft.amount}:pending',
          TransferResult(status: 'pending', request: ApprovalRequest.fromJson(reqJson), risk: risk),
        );
      }
      if (level == 'caution' && !draft.confirmed) {
        return _call(
          'transfer:$memberId:${draft.amount}:caution',
          TransferResult(status: 'caution', amount: draft.amount, recipient: _recipient(draft), risk: risk),
        );
      }
      return _call(
        'transfer:$memberId:${draft.amount}:done',
        TransferResult(status: 'done', amount: draft.amount, recipient: _recipient(draft), risk: risk),
      );
    }
    return _call(
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
  }

  @override
  Future<ConfirmationQuestionResult> fetchConfirmationQuestion(String memberId, String actionKind, {int? amount}) {
    final caution = memberId != 'guardian' && _isCautionMode(memberId);
    final needs = caution && (actionKind != 'transfer' || amount == null || amount > _avgTransfer(memberId));
    return _call(
      'question:$memberId:$actionKind',
      ConfirmationQuestionResult(
        needsQuestion: needs,
        cautionMode: caution,
        question: needs ? _questionFor(actionKind) : null,
      ),
    );
  }

  @override
  Future<SavingsCancelResult> cancelSavings(
    String memberId,
    String accountId, {
    String? questionAnswer,
    bool confirmed = false,
  }) {
    final snap = FamilySnapshot.fromJson(snapshotJson);
    final acct = snap.member(memberId).accounts.firstWhere((a) => a.id == accountId);
    final calc = acct.earlyCancelPreview ??
        const SavingsCancelCalculation(
          principal: 18400000,
          interestRate: 4.2,
          earlyCancelRate: 1.0,
          accruedInterest: 1159200,
          earlyCancelInterest: 276000,
          reducedInterest: 883200,
          payoutAmount: 18676000,
        );
    final inCaution = memberId != 'guardian' && _isCautionMode(memberId);
    if (inCaution) {
      final ans = questionAnswer?.trim() ?? '';
      if (ans.isEmpty) {
        return _call(
          'cancelSavings:$memberId:$accountId:question',
          SavingsCancelResult(status: 'question', account: acct, calculation: calc, question: _questionFor('savings_cancel')),
        );
      }
      final level = _classifyAnswer(ans);
      final risk = _cautionRisk(level, ans);
      if (level == 'danger') {
        final now = DateTime.now().toUtc();
        final incId = _activeIncidentId(memberId);
        final reqJson = <String, dynamic>{
          'id': 'req-sav-${calls.length + 1}',
          'member_id': memberId,
          'type': 'savings_cancel',
          'title': '${acct.name} 만기 전 해지',
          'amount': calc.payoutAmount,
          'detail': '원금 18,400,000원 · 줄어드는 이자 883,200원',
          'incident_id': ?incId,
          'status': 'pending',
          'channel': '앱 알림',
          'created_at': now.toIso8601String(),
          'expires_at': now.add(const Duration(minutes: 30)).toIso8601String(),
          'risk': {
            'score': risk.score,
            'level': 'high',
            'needs_approval': true,
            'explanation': risk.explanation,
            'signals': [for (final s in risk.signals) {'id': s.id, 'label': s.label, 'weight': s.weight}],
          },
        };
        final existingReqs = (snapshotJson['requests'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
        snapshotJson['requests'] = [reqJson, ...existingReqs];
        return _call(
          'cancelSavings:$memberId:$accountId:pending',
          SavingsCancelResult(
            status: 'pending',
            account: acct,
            calculation: calc,
            request: ApprovalRequest.fromJson(reqJson),
            risk: risk,
          ),
        );
      }
      if (level == 'caution' && !confirmed) {
        return _call(
          'cancelSavings:$memberId:$accountId:caution',
          SavingsCancelResult(status: 'caution', account: acct, calculation: calc, risk: risk),
        );
      }
    }
    _markSavingsCancelled(memberId, accountId, calc.payoutAmount);
    return _call(
      'cancelSavings:$memberId:$accountId:done',
      SavingsCancelResult(status: 'done', account: acct, calculation: calc),
    );
  }

  void _markSavingsCancelled(String memberId, String accountId, int payout) {
    final members = snapshotJson['members'];
    if (members is! List) return;
    for (final m in members) {
      if (m is Map<String, dynamic> && m['id'] == memberId) {
        m['balance'] = ((m['balance'] as int?) ?? 0) + payout;
        final accts = m['accounts'];
        if (accts is List) {
          for (final a in accts) {
            if (a is Map<String, dynamic> && a['id'] == accountId) {
              a['balance'] = 0;
              a['status'] = 'cancelled';
            }
          }
        }
      }
    }
  }

  @override
  Future<LoanQuote> quoteLoan(int amount) => _call('quoteLoan:$amount', _calcLoanQuote(amount));

  @override
  Future<LoanLimitResult> checkLoanLimit(String memberId, {String? questionAnswer, bool confirmed = false}) {
    final quote = _calcLoanQuote(5000000);
    final inCaution = memberId != 'guardian' && _isCautionMode(memberId);
    if (inCaution) {
      final ans = questionAnswer?.trim() ?? '';
      if (ans.isEmpty) {
        return _call(
          'loanLimit:$memberId:question',
          LoanLimitResult(status: 'question', product: LoanProduct.defaultProduct, question: _questionFor('loan_limit')),
        );
      }
      final level = _classifyAnswer(ans);
      final risk = _cautionRisk(level, ans);
      if (level == 'danger') {
        return _call(
          'loanLimit:$memberId:danger',
          LoanLimitResult(
            status: 'danger',
            product: LoanProduct.defaultProduct,
            maxLimit: LoanProduct.defaultProduct.maxLimit,
            sampleQuote: quote,
            risk: risk,
            guardianNotified: true,
          ),
        );
      }
      if (level == 'caution' && !confirmed) {
        return _call(
          'loanLimit:$memberId:caution',
          LoanLimitResult(
            status: 'caution',
            product: LoanProduct.defaultProduct,
            maxLimit: LoanProduct.defaultProduct.maxLimit,
            sampleQuote: quote,
            risk: risk,
          ),
        );
      }
    }
    return _call(
      'loanLimit:$memberId:done',
      LoanLimitResult(
        status: 'done',
        product: LoanProduct.defaultProduct,
        maxLimit: LoanProduct.defaultProduct.maxLimit,
        sampleQuote: quote,
      ),
    );
  }

  @override
  Future<LoanApplyResult> applyLoan(
    String memberId,
    int amount, {
    String? questionAnswer,
    bool confirmed = false,
  }) {
    final quote = _calcLoanQuote(amount);
    final inCaution = memberId != 'guardian' && _isCautionMode(memberId);
    if (inCaution) {
      final ans = questionAnswer?.trim() ?? '';
      if (ans.isEmpty) {
        return _call(
          'applyLoan:$memberId:$amount:question',
          LoanApplyResult(
            status: 'question',
            product: LoanProduct.defaultProduct,
            quote: quote,
            amount: amount,
            question: _questionFor('loan_apply'),
          ),
        );
      }
      final level = _classifyAnswer(ans);
      final risk = _cautionRisk(level, ans);
      if (level == 'danger') {
        final now = DateTime.now().toUtc();
        final incId = _activeIncidentId(memberId);
        final reqJson = <String, dynamic>{
          'id': 'req-loan-${calls.length + 1}',
          'member_id': memberId,
          'type': 'loan_apply',
          'title': '${LoanProduct.defaultProduct.name} 신청',
          'amount': amount,
          'detail': '월 ${quote.monthlyPayment}원 · 24개월',
          'incident_id': ?incId,
          'status': 'pending',
          'channel': '앱 알림',
          'created_at': now.toIso8601String(),
          'expires_at': now.add(const Duration(minutes: 30)).toIso8601String(),
          'risk': {
            'score': risk.score,
            'level': 'high',
            'needs_approval': true,
            'explanation': risk.explanation,
            'signals': [for (final s in risk.signals) {'id': s.id, 'label': s.label, 'weight': s.weight}],
          },
        };
        final existingReqs = (snapshotJson['requests'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
        snapshotJson['requests'] = [reqJson, ...existingReqs];
        return _call(
          'applyLoan:$memberId:$amount:pending',
          LoanApplyResult(
            status: 'pending',
            product: LoanProduct.defaultProduct,
            quote: quote,
            amount: amount,
            request: ApprovalRequest.fromJson(reqJson),
            risk: risk,
          ),
        );
      }
      if (level == 'caution' && !confirmed) {
        return _call(
          'applyLoan:$memberId:$amount:caution',
          LoanApplyResult(
            status: 'caution',
            product: LoanProduct.defaultProduct,
            quote: quote,
            amount: amount,
            risk: risk,
          ),
        );
      }
    }
    return _call(
      'applyLoan:$memberId:$amount:done',
      LoanApplyResult(status: 'done', product: LoanProduct.defaultProduct, quote: quote, amount: amount),
    );
  }

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
          final memberId = item['member_id'] as String? ?? '';
          final reqType = item['type'] as String? ?? 'transfer';
          final amount = (item['amount'] as int?) ?? 0;
          if (reqType == 'savings_cancel') {
            _markSavingsCancelled(memberId, 'a2', amount);
          } else {
            final members = snapshotJson['members'];
            if (members is List && amount > 0) {
              for (final m in members) {
                if (m is Map<String, dynamic> && m['id'] == memberId) {
                  final current = (m['balance'] as int?) ?? 0;
                  m['balance'] = reqType == 'loan_apply' ? current + amount : current - amount;
                }
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
  Future<PairingCodeResult> issuePairingCode(String guardianId, String memberId) {
    _pairingSeq += 1;
    final code = forcePairingCode ?? (482909 + _pairingSeq).toString();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(minutes: 5));
    _pairingCodes[code] = (guardianId: guardianId, memberId: memberId, expiresAt: expiresAt, used: false);
    final snap = FamilySnapshot.fromJson(snapshotJson);
    final m = snap.memberOrNull(memberId);
    return _call(
      'issuePairingCode:$guardianId:$memberId:$code',
      PairingCodeResult(
        code: code,
        qrValue: code,
        guardianId: snap.guardian.id,
        guardianName: snap.guardian.name,
        memberId: memberId,
        memberName: m?.name ?? memberId,
        expiresAt: expiresAt.toLocal(),
        expiresInSeconds: 300,
      ),
    );
  }

  @override
  Future<PairingConnectResult> connectPairing(String memberId, String code, {required bool consented}) {
    final clean = code.trim().toUpperCase();
    calls.add('connectPairing:$memberId:$clean:$consented');
    if (failNetwork) throw const ApiException(Failure('서버에 연결할 수 없어요.', 'network'));
    if (!consented) {
      throw const ApiException(Failure('보호자 연결 안내에 동의해 주세요.', 'consent-required'), 400);
    }
    final entry = _pairingCodes[clean];
    if (entry == null || entry.memberId != memberId) {
      throw const ApiException(Failure('연결 코드가 올바르지 않아요.', 'invalid-code'), 400);
    }
    if (entry.used) {
      throw const ApiException(Failure('이미 사용된 연결 코드예요.', 'code-used'), 409);
    }
    final now = DateTime.now().toUtc();
    if (!now.isBefore(entry.expiresAt)) {
      throw const ApiException(Failure('연결 코드의 유효 시간이 지났어요. 새 코드를 발급받아 주세요.', 'code-expired'), 400);
    }
    _pairingCodes[clean] = (guardianId: entry.guardianId, memberId: entry.memberId, expiresAt: entry.expiresAt, used: true);
    final members = snapshotJson['members'];
    if (members is List) {
      for (final m in members) {
        if (m is Map<String, dynamic> && m['id'] == memberId) {
          m['paired_at'] = now.toIso8601String();
          m['consent_at'] = now.toIso8601String();
        }
      }
    }
    final snap = FamilySnapshot.fromJson(snapshotJson);
    return Future.value(
      PairingConnectResult(
        status: 'connected',
        memberId: memberId,
        guardianId: snap.guardian.id,
        guardianName: snap.guardian.name,
        pairedAt: now.toLocal(),
        consentAt: now.toLocal(),
      ),
    );
  }

  @override
  Future<List<IntegrationLogEntry>> integrationLogs({int limit = 30}) => _call('logs', const <IntegrationLogEntry>[]);

  @override
  Future<UserFeedbackResult> submitFeedback(String memberId, {required String category, String message = ''}) {
    final cleanCat = category.trim();
    if (cleanCat.isEmpty) {
      throw const ApiException(Failure('불편한 점 종류를 선택해 주세요.', 'category'), 400);
    }
    final now = DateTime.now().toUtc();
    final item = {
      'id': 'fb-${submittedFeedback.length + 1}',
      'member_id': memberId,
      'category': cleanCat,
      'message': message.trim(),
      'created_at': now.toIso8601String(),
    };
    submittedFeedback.insert(0, item);
    return _call('submitFeedback:$memberId:$cleanCat', UserFeedbackResult.fromJson(item));
  }

  @override
  Future<void> resetDemo() {
    snapshotJson['active_call'] = null;
    snapshotJson['calls'] = <Map<String, dynamic>>[];
    return _call('reset', null);
  }

  @override
  Future<void> dispose() async {
    await _events.close();
    await _rtcSignals.close();
    await _connection.close();
  }
}
