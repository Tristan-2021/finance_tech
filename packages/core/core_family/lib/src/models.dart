import 'json.dart';

/// 화면에서 고르는 사용자. 보호자는 가족 전체를 봅니다.
enum Persona {
  senior('어르신'),
  child('아이'),
  guardian('보호자');

  final String label;
  const Persona(this.label);

  /// 보호 대상 사용자 id (보호자는 null).
  String? get memberId => this == Persona.guardian ? null : name;

  static Persona parse(Object? v) =>
      Persona.values.firstWhere((p) => p.name == v, orElse: () => Persona.senior);
}

enum RiskLevel {
  safe('안전', '안전한 거래로 보여요', '평소 거래 패턴과 비슷해요'),
  caution('주의', '한 번 더 확인이 필요해요', '평소와 다른 점이 있어 보내기 전에 한 번 더 확인해요'),
  high('위험', '사기 위험이 높은 거래예요', '보이스피싱에서 자주 보이는 패턴이에요');

  final String label;
  final String title;
  final String desc;
  const RiskLevel(this.label, this.title, this.desc);

  static RiskLevel parse(Object? v) =>
      RiskLevel.values.firstWhere((l) => l.name == v, orElse: () => RiskLevel.safe);
}

/// SOS 동결을 일으킨 방법. 서버 API의 trigger_type 값과 같습니다.
enum SosTrigger {
  shake('SHAKE_MOTION', '흔들기'),
  longPress('LONG_PRESS', '길게 누르기'),
  guardian('GUARDIAN_REMOTE', '보호자 원격');

  final String apiValue;
  final String label;
  const SosTrigger(this.apiValue, this.label);

  static SosTrigger? parse(Object? v) {
    for (final t in SosTrigger.values) {
      if (t.apiValue == v) return t;
    }
    return null;
  }
}

class Guardian {
  final String id;
  final String name;
  final String avatar;
  final String phone;

  /// 보호자 본인 계좌. 가족과 같은 송금·결제·내역 기능을 씁니다.
  final Member? banking;

  const Guardian({required this.id, required this.name, this.avatar = '', this.phone = '', this.banking});

  factory Guardian.fromJson(Json j) => Guardian(
    id: asString(j['id']),
    name: asString(j['name']),
    avatar: asString(j['avatar']),
    phone: asString(j['phone']),
    banking: j['banking'] is Map<String, dynamic> ? Member.fromJson(j['banking'] as Json) : null,
  );
}

class SavingsCancelCalculation {
  final int principal;
  final double interestRate;
  final double earlyCancelRate;
  final int accruedInterest;
  final int earlyCancelInterest;
  final int reducedInterest;
  final int payoutAmount;

  const SavingsCancelCalculation({
    required this.principal,
    required this.interestRate,
    required this.earlyCancelRate,
    required this.accruedInterest,
    required this.earlyCancelInterest,
    required this.reducedInterest,
    required this.payoutAmount,
  });

  factory SavingsCancelCalculation.fromJson(Json j) => SavingsCancelCalculation(
    principal: asInt(j['principal']),
    interestRate: asDouble(j['interest_rate']),
    earlyCancelRate: asDouble(j['early_cancel_rate']),
    accruedInterest: asInt(j['accrued_interest']),
    earlyCancelInterest: asInt(j['early_cancel_interest']),
    reducedInterest: asInt(j['reduced_interest']),
    payoutAmount: asInt(j['payout_amount']),
  );
}

class BankAccount {
  final String id;
  final String name;
  final String bank;
  final String number;
  final String kind;
  final int balance;
  final bool withdrawalBlocked;
  final double interestRate;
  final double earlyCancelRate;
  final DateTime? maturityDate;
  final int accruedInterest;
  final String status;
  final SavingsCancelCalculation? earlyCancelPreview;

  const BankAccount({
    required this.id,
    required this.name,
    required this.bank,
    required this.number,
    this.kind = 'CHECKING',
    this.balance = 0,
    this.withdrawalBlocked = false,
    this.interestRate = 0,
    this.earlyCancelRate = 0,
    this.maturityDate,
    this.accruedInterest = 0,
    this.status = 'active',
    this.earlyCancelPreview,
  });

  bool get isSavings => kind == 'SAVINGS' || kind == 'DEPOSIT';
  bool get isActive => status == 'active';

  factory BankAccount.fromJson(Json j) => BankAccount(
    id: asString(j['id']),
    name: asString(j['name']),
    bank: asString(j['bank']),
    number: asString(j['number']),
    kind: asString(j['kind'], 'CHECKING'),
    balance: asInt(j['balance']),
    withdrawalBlocked: asBool(j['withdrawal_blocked']),
    interestRate: asDouble(j['interest_rate']),
    earlyCancelRate: asDouble(j['early_cancel_rate']),
    maturityDate: asDate(j['maturity_date']),
    accruedInterest: asInt(j['accrued_interest']),
    status: asString(j['status'], 'active'),
    earlyCancelPreview: j['early_cancel_preview'] is Map<String, dynamic>
        ? SavingsCancelCalculation.fromJson(j['early_cancel_preview'] as Json)
        : null,
  );
}

class LoanProduct {
  final String id;
  final String name;
  final String bank;
  final double interestRate;
  final bool isVariableRate;
  final double prepaymentFeeRate;
  final String repaymentMethod;
  final int termMonths;
  final String repaymentCycle;
  final int minAmount;
  final int maxLimit;
  final double delinquencyRate;
  final int withdrawalRightDays;

  const LoanProduct({
    required this.id,
    required this.name,
    required this.bank,
    required this.interestRate,
    required this.isVariableRate,
    required this.prepaymentFeeRate,
    required this.repaymentMethod,
    required this.termMonths,
    required this.repaymentCycle,
    required this.minAmount,
    required this.maxLimit,
    required this.delinquencyRate,
    required this.withdrawalRightDays,
  });

  static const defaultProduct = LoanProduct(
    id: 'loan-senior-1',
    name: '핑거벨 안심 생활자금 대출',
    bank: '핑거벨',
    interestRate: 5.4,
    isVariableRate: true,
    prepaymentFeeRate: 0.6,
    repaymentMethod: '원리금균등분할상환',
    termMonths: 24,
    repaymentCycle: '매월 같은 날',
    minAmount: 1000000,
    maxLimit: 20000000,
    delinquencyRate: 8.4,
    withdrawalRightDays: 14,
  );

  factory LoanProduct.fromJson(Json j) => LoanProduct(
    id: asString(j['id'], defaultProduct.id),
    name: asString(j['name'], defaultProduct.name),
    bank: asString(j['bank'], defaultProduct.bank),
    interestRate: asDouble(j['interest_rate'], defaultProduct.interestRate),
    isVariableRate: asBool(j['is_variable_rate'], defaultProduct.isVariableRate),
    prepaymentFeeRate: asDouble(j['prepayment_fee_rate'], defaultProduct.prepaymentFeeRate),
    repaymentMethod: asString(j['repayment_method'], defaultProduct.repaymentMethod),
    termMonths: asInt(j['term_months'], defaultProduct.termMonths),
    repaymentCycle: asString(j['repayment_cycle'], defaultProduct.repaymentCycle),
    minAmount: asInt(j['min_amount'], defaultProduct.minAmount),
    maxLimit: asInt(j['max_limit'], defaultProduct.maxLimit),
    delinquencyRate: asDouble(j['delinquency_rate'], defaultProduct.delinquencyRate),
    withdrawalRightDays: asInt(j['withdrawal_right_days'], defaultProduct.withdrawalRightDays),
  );
}

class LoanQuote {
  final int amount;
  final double annualRate;
  final int termMonths;
  final int monthlyPayment;
  final int totalInterest;
  final int totalRepayment;

  const LoanQuote({
    required this.amount,
    required this.annualRate,
    required this.termMonths,
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalRepayment,
  });

  factory LoanQuote.fromJson(Json j) => LoanQuote(
    amount: asInt(j['amount']),
    annualRate: asDouble(j['annual_rate']),
    termMonths: asInt(j['term_months'], 24),
    monthlyPayment: asInt(j['monthly_payment']),
    totalInterest: asInt(j['total_interest']),
    totalRepayment: asInt(j['total_repayment']),
  );
}

class ConfirmationQuestion {
  final String actionKind;
  final String question;
  final List<String> options;
  final String source;
  final bool cached;

  const ConfirmationQuestion({
    required this.actionKind,
    required this.question,
    this.options = const [],
    this.source = 'rule',
    this.cached = false,
  });

  factory ConfirmationQuestion.fromJson(Json j) => ConfirmationQuestion(
    actionKind: asString(j['action_kind']),
    question: asString(j['question']),
    options: asStrings(j['options']),
    source: asString(j['source'], 'rule'),
    cached: asBool(j['cached']),
  );
}

class Contact {
  final String id;
  final String name;
  final String relation;
  final String bank;
  final String number;

  const Contact({required this.id, required this.name, required this.relation, required this.bank, required this.number});

  factory Contact.fromJson(Json j) => Contact(
    id: asString(j['id']),
    name: asString(j['name']),
    relation: asString(j['relation']),
    bank: asString(j['bank']),
    number: asString(j['number']),
  );
}

/// 거래 내역 한 줄. kind: in(입금) / out(출금) / protect(보호 조치).
class LedgerEntry {
  final String id;
  final String kind;
  final String title;
  final String desc;
  final int amount;
  final String emoji;
  final String? tag;
  final String? tone;
  final DateTime at;

  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.desc,
    required this.amount,
    required this.at,
    this.emoji = '',
    this.tag,
    this.tone,
  });

  bool get isProtect => kind == 'protect';
  bool get isDanger => tone == 'red' || tone == 'amber';

  factory LedgerEntry.fromJson(Json j) => LedgerEntry(
    id: asString(j['id']),
    kind: asString(j['kind']),
    title: asString(j['title']),
    desc: asString(j['desc']),
    amount: asInt(j['amount']),
    emoji: asString(j['emoji']),
    tag: asStringOrNull(j['tag']),
    tone: asStringOrNull(j['tone']),
    at: asDateOr(j['at'], DateTime.fromMillisecondsSinceEpoch(0)),
  );
}

/// 보호자 결정 결과 배너.
class Notice {
  final String id;
  final String? requestId;
  final String status;
  final String title;
  final int amount;
  final String reason;

  const Notice({required this.id, required this.status, required this.title, this.requestId, this.amount = 0, this.reason = ''});

  factory Notice.fromJson(Json j) => Notice(
    id: asString(j['id']),
    requestId: asStringOrNull(j['request_id']),
    status: asString(j['status']),
    title: asString(j['title']),
    amount: asInt(j['amount']),
    reason: asString(j['reason']),
  );
}

class PaymentCheck {
  final bool ok;
  final String code;
  final String message;
  final bool canRequest;

  const PaymentCheck({required this.ok, required this.code, this.message = '', this.canRequest = false});

  factory PaymentCheck.fromJson(Json j) => PaymentCheck(
    ok: asBool(j['ok']),
    code: asString(j['code'], 'ok'),
    message: asString(j['message']),
    canRequest: asBool(j['can_request']),
  );
}

class Merchant {
  final String id;
  final String name;
  final String category;
  final String categoryLabel;
  final String mcc;
  final int amount;
  final String emoji;
  final PaymentCheck check;

  const Merchant({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.amount,
    this.mcc = '',
    this.emoji = '',
    this.check = const PaymentCheck(ok: true, code: 'ok'),
  });

  factory Merchant.fromJson(Json j) => Merchant(
    id: asString(j['id']),
    name: asString(j['name']),
    category: asString(j['category']),
    categoryLabel: asString(j['category_label']),
    mcc: asString(j['mcc']),
    amount: asInt(j['amount']),
    emoji: asString(j['emoji']),
    check: PaymentCheck.fromJson(asJson(j['check'])),
  );
}

class LimitRange {
  final int min;
  final int max;
  final int step;

  const LimitRange({required this.min, required this.max, required this.step});

  factory LimitRange.fromJson(Json j) => LimitRange(min: asInt(j['min']), max: asInt(j['max'], 1), step: asInt(j['step'], 1));
}

/// 문자 위험 판정 단계 (기획서 5.5: 낮음 / 주의 / 위험).
enum SmsRiskLevel {
  low('낮음'),
  caution('주의'),
  danger('위험');

  final String label;
  const SmsRiskLevel(this.label);

  static SmsRiskLevel parse(Object? v) => switch (v) {
    'danger' || 'high' => SmsRiskLevel.danger,
    'caution' => SmsRiskLevel.caution,
    _ => SmsRiskLevel.low,
  };
}

/// 수신 문자 한 건과 서버 위험 판정 결과 (기획서 5.2, 5.5).
class SmsMessage {
  final String id;
  final String memberId;
  final String senderName;
  final String senderPhone;
  final String body;
  final SmsRiskLevel level;
  final List<String> reasons;
  final String explanation;
  final List<String> links;
  final List<String> phones;
  final DateTime at;

  const SmsMessage({
    required this.id,
    required this.memberId,
    required this.senderPhone,
    required this.body,
    required this.at,
    this.senderName = '',
    this.level = SmsRiskLevel.low,
    this.reasons = const [],
    this.explanation = '',
    this.links = const [],
    this.phones = const [],
  });

  bool get isDanger => level == SmsRiskLevel.danger;
  bool get isCaution => level == SmsRiskLevel.caution;
  bool get hasWarning => isDanger || isCaution;
  String get displaySender => senderName.isNotEmpty ? senderName : senderPhone;

  factory SmsMessage.fromJson(Json j) => SmsMessage(
    id: asString(j['id']),
    memberId: asString(j['member_id'], 'senior'),
    senderName: asString(j['sender_name']),
    senderPhone: asString(j['sender_phone']),
    body: asString(j['body']),
    level: SmsRiskLevel.parse(j['level']),
    reasons: asStrings(j['reasons']),
    explanation: asString(j['explanation']),
    links: asStrings(j['links']),
    phones: asStrings(j['phones']),
    at: asDateOr(j['at'], DateTime.fromMillisecondsSinceEpoch(0)),
  );
}

/// 발신 번호별 대화 목록 항목 (기획서 5.2).
class SmsConversation {
  final String senderPhone;
  final String senderName;
  final SmsMessage lastMessage;
  final int dangerCount;
  final List<SmsMessage> messages;

  const SmsConversation({
    required this.senderPhone,
    required this.lastMessage,
    required this.messages,
    this.senderName = '',
    this.dangerCount = 0,
  });

  bool get hasDanger => dangerCount > 0 || messages.any((m) => m.isDanger);
  String get displaySender => senderName.isNotEmpty ? senderName : senderPhone;

  factory SmsConversation.fromJson(Json j) {
    final messages = asList(j['messages'], SmsMessage.fromJson);
    final last = j['last_message'] is Map<String, dynamic>
        ? SmsMessage.fromJson(j['last_message'] as Json)
        : (messages.lastOrNull ??
              SmsMessage(
                id: '',
                memberId: 'senior',
                senderPhone: asString(j['sender_phone']),
                body: '',
                at: DateTime.fromMillisecondsSinceEpoch(0),
              ));
    return SmsConversation(
      senderPhone: asString(j['sender_phone']),
      senderName: asString(j['sender_name'], last.senderName),
      lastMessage: last,
      dangerCount: asInt(j['danger_count'], messages.where((m) => m.isDanger).length),
      messages: messages,
    );
  }

  static List<SmsConversation> groupFromMessages(List<SmsMessage> messagesDesc) {
    final grouped = <String, List<SmsMessage>>{};
    for (final m in messagesDesc) {
      grouped.putIfAbsent(m.senderPhone, () => []).add(m);
    }
    return [
      for (final entry in grouped.entries)
        SmsConversation(
          senderPhone: entry.key,
          senderName: entry.value.first.senderName,
          lastMessage: entry.value.first,
          dangerCount: entry.value.where((m) => m.isDanger).length,
          messages: entry.value.reversed.toList(growable: false),
        ),
    ];
  }
}

/// 사건의 시간순 항목 (기획서 5.1).
class IncidentItem {
  final String id;
  final String kind;
  final String summary;
  final DateTime at;

  const IncidentItem({required this.id, required this.kind, required this.summary, required this.at});

  factory IncidentItem.fromJson(Json j) => IncidentItem(
    id: asString(j['id']),
    kind: asString(j['kind']),
    summary: asString(j['summary']),
    at: asDateOr(j['at'], DateTime.fromMillisecondsSinceEpoch(0)),
  );
}

/// 주의 모드 한 번 동안 쌓인 사건 기록 (기획서 5.1).
class Incident {
  final String id;
  final String memberId;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime? endedAt;
  final String? endedBy;
  final List<IncidentItem> items;

  const Incident({
    required this.id,
    required this.memberId,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    this.endedAt,
    this.endedBy,
    this.items = const [],
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  factory Incident.fromJson(Json j) => Incident(
    id: asString(j['id']),
    memberId: asString(j['member_id']),
    status: asString(j['status'], 'open'),
    startedAt: asDateOr(j['started_at'], DateTime.fromMillisecondsSinceEpoch(0)),
    expiresAt: asDateOr(j['expires_at'], DateTime.fromMillisecondsSinceEpoch(0)),
    endedAt: asDate(j['ended_at']),
    endedBy: asStringOrNull(j['ended_by']),
    items: asList(j['items'], IncidentItem.fromJson),
  );
}

/// 통화 세션 상태 (기획서 5.3: 발신/수신 대기, 통화 중, 종료).
enum CallStatus {
  ringing('발신 중'),
  active('통화 중'),
  ended('통화 종료');

  final String label;
  const CallStatus(this.label);

  static CallStatus parse(Object? v) => switch (v) {
    'active' => CallStatus.active,
    'ended' => CallStatus.ended,
    _ => CallStatus.ringing,
  };
}

/// 앱 안 통화 세션과 실시간 위험 경고 요약 (기획서 5.3, 5.5).
class CallSession {
  final String id;
  final String callerId;
  final String calleeId;
  final String? memberId;
  final String peerName;
  final String peerPhone;
  final CallStatus status;
  final bool analyzed;
  final SmsRiskLevel warningLevel;
  final List<String> warningReasons;
  final String warningExplanation;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  const CallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.status,
    required this.createdAt,
    this.memberId,
    this.peerName = '',
    this.peerPhone = '',
    this.analyzed = true,
    this.warningLevel = SmsRiskLevel.low,
    this.warningReasons = const [],
    this.warningExplanation = '',
    this.answeredAt,
    this.endedAt,
  });

  bool get isRinging => status == CallStatus.ringing;
  bool get isActive => status == CallStatus.active;
  bool get isEnded => status == CallStatus.ended;
  bool get isDanger => warningLevel == SmsRiskLevel.danger;
  bool get isCaution => warningLevel == SmsRiskLevel.caution;
  bool get hasWarning => isDanger || isCaution;
  String get displayPeer => peerName.isNotEmpty ? peerName : (peerPhone.isNotEmpty ? peerPhone : '시연 상대');

  bool involves(String participantId) => callerId == participantId || calleeId == participantId;

  factory CallSession.fromJson(Json j) => CallSession(
    id: asString(j['id']),
    callerId: asString(j['caller_id'], 'senior'),
    calleeId: asString(j['callee_id'], 'counterpart'),
    memberId: asStringOrNull(j['member_id']),
    peerName: asString(j['peer_name']),
    peerPhone: asString(j['peer_phone']),
    status: CallStatus.parse(j['status']),
    analyzed: asBool(j['analyzed'], true),
    warningLevel: SmsRiskLevel.parse(j['warning_level']),
    warningReasons: asStrings(j['warning_reasons']),
    warningExplanation: asString(j['warning_explanation']),
    createdAt: asDateOr(j['created_at'], DateTime.now()),
    answeredAt: asDate(j['answered_at']),
    endedAt: asDate(j['ended_at']),
  );
}

/// 시연용 통화 대본 (기획서 8절).
class CallScript {
  final String id;
  final String kind;
  final String title;
  final String callerName;
  final String callerPhone;
  final List<String> lines;

  const CallScript({
    required this.id,
    required this.kind,
    required this.title,
    required this.callerName,
    required this.callerPhone,
    this.lines = const [],
  });

  bool get isPhishing => kind == 'phishing' || kind == 'scam' || id == 'phishing';

  factory CallScript.fromJson(Json j) => CallScript(
    id: asString(j['id']),
    kind: asString(j['kind']),
    title: asString(j['title']),
    callerName: asString(j['caller_name']),
    callerPhone: asString(j['caller_phone']),
    lines: asStrings(j['lines']),
  );
}

/// 계좌를 가진 사용자: 보호 대상 가족(어르신·아이) 또는 보호자 본인([Guardian.banking]).
class Member {
  final String id;
  final String role;
  final String name;
  final String? nickname;
  final String relationLabel;
  final String guardianRelation;
  final String avatar;
  final int balance;
  final BankAccount account;
  final List<BankAccount> accounts;
  final int spentToday;
  final int dailyLimit;
  final LimitRange limitRange;
  final int approvalThreshold;
  final int avgTransfer;
  final String mode;
  final List<String> modes;
  final bool requireApprovalToLoosen;
  final bool sleepGuard;
  final bool sleepActive;
  final bool isFrozen;
  final DateTime? frozenUntil;
  final SosTrigger? frozenSource;
  final bool cautionMode;
  final DateTime? cautionUntil;
  final DateTime? pairedAt;
  final DateTime? consentAt;
  final Incident? activeIncident;
  final List<SmsMessage> smsMessages;
  final List<SmsConversation> smsConversations;
  final List<Contact> contacts;
  final List<LedgerEntry> ledger;
  final List<Notice> notices;
  final List<Merchant> merchants;

  const Member({
    required this.id,
    required this.role,
    required this.name,
    required this.relationLabel,
    required this.guardianRelation,
    required this.balance,
    required this.account,
    required this.dailyLimit,
    required this.limitRange,
    required this.approvalThreshold,
    required this.mode,
    this.nickname,
    this.avatar = '',
    this.accounts = const [],
    this.spentToday = 0,
    this.avgTransfer = 0,
    this.modes = const [],
    this.requireApprovalToLoosen = false,
    this.sleepGuard = false,
    this.sleepActive = false,
    this.isFrozen = false,
    this.frozenUntil,
    this.frozenSource,
    this.cautionMode = false,
    this.cautionUntil,
    this.pairedAt,
    this.consentAt,
    this.activeIncident,
    this.smsMessages = const [],
    this.smsConversations = const [],
    this.contacts = const [],
    this.ledger = const [],
    this.notices = const [],
    this.merchants = const [],
  });

  bool get isChild => role == 'CHILD';

  /// 보호자 본인 계좌. 보호자 승인·안심 모드·SOS 동결 없이 바로 보냅니다.
  bool get isGuardian => role == 'GUARDIAN';
  bool get isPaired => pairedAt != null && consentAt != null;
  String get callName => nickname ?? name;

  /// "어머니 김순자"
  String get label => '$relationLabel $name';

  int get dangerSmsCount => smsMessages.where((m) => m.isDanger).length;

  Merchant? merchant(String id) => merchants.where((m) => m.id == id).firstOrNull;
  Contact? contact(String id) => contacts.where((c) => c.id == id).firstOrNull;

  factory Member.fromJson(Json j) {
    final accounts = asList(j['accounts'], BankAccount.fromJson);
    final smsMessages = asList(j['sms_messages'], SmsMessage.fromJson);
    final rawConvs = asList(j['sms_conversations'], SmsConversation.fromJson);
    return Member(
      id: asString(j['id']),
      role: asString(j['role']),
      name: asString(j['name']),
      nickname: asStringOrNull(j['nickname']),
      relationLabel: asString(j['relation_label']),
      guardianRelation: asString(j['guardian_relation']),
      avatar: asString(j['avatar']),
      balance: asInt(j['balance']),
      account: j['account'] is Map<String, dynamic>
          ? BankAccount.fromJson(j['account'] as Json)
          : (accounts.firstOrNull ?? const BankAccount(id: '', name: '', bank: '', number: '')),
      accounts: accounts,
      spentToday: asInt(j['spent_today']),
      dailyLimit: asInt(j['daily_limit'], 1),
      limitRange: LimitRange.fromJson(asJson(j['limit_range'])),
      approvalThreshold: asInt(j['approval_threshold']),
      avgTransfer: asInt(j['avg_transfer']),
      mode: asString(j['mode'], 'normal'),
      modes: asStrings(j['modes']),
      requireApprovalToLoosen: asBool(j['require_approval_to_loosen']),
      sleepGuard: asBool(j['sleep_guard']),
      sleepActive: asBool(j['sleep_active']),
      isFrozen: asBool(j['is_frozen']),
      frozenUntil: asDate(j['frozen_until']),
      frozenSource: SosTrigger.parse(j['frozen_source']),
      cautionMode: asBool(j['caution_mode']),
      cautionUntil: asDate(j['caution_until']),
      pairedAt: asDate(j['paired_at']),
      consentAt: asDate(j['consent_at']),
      activeIncident: j['active_incident'] is Map<String, dynamic> ? Incident.fromJson(j['active_incident'] as Json) : null,
      smsMessages: smsMessages,
      smsConversations: rawConvs.isNotEmpty ? rawConvs : SmsConversation.groupFromMessages(smsMessages),
      contacts: asList(j['contacts'], Contact.fromJson),
      ledger: asList(j['ledger'], LedgerEntry.fromJson),
      notices: asList(j['notices'], Notice.fromJson),
      merchants: asList(j['merchants'], Merchant.fromJson),
    );
  }
}

class RiskSignal {
  final String id;
  final String label;
  final int weight;

  const RiskSignal({required this.id, required this.label, this.weight = 0});

  factory RiskSignal.fromJson(Json j) =>
      RiskSignal(id: asString(j['id']), label: asString(j['label']), weight: asInt(j['weight']));
}

/// Isolation Forest 판정 정보.
class AnomalyInfo {
  final bool anomaly;
  final double strength;
  final int trainedOn;

  const AnomalyInfo({required this.anomaly, required this.strength, required this.trainedOn});

  factory AnomalyInfo.fromJson(Json j) =>
      AnomalyInfo(anomaly: asBool(j['anomaly']), strength: asDouble(j['strength']), trainedOn: asInt(j['trained_on']));
}

/// AI FDS 위험도 판정.
class RiskAssessment {
  final int score;
  final RiskLevel level;
  final List<RiskSignal> signals;
  final String explanation;
  final bool needsApproval;
  final bool sleepWindow;
  final AnomalyInfo? model;

  const RiskAssessment({
    required this.score,
    required this.level,
    this.signals = const [],
    this.explanation = '',
    this.needsApproval = false,
    this.sleepWindow = false,
    this.model,
  });

  bool get isSafe => level == RiskLevel.safe;

  String get easyExplanation {
    if (explanation.isNotEmpty) return explanation;
    if (signals.isNotEmpty) return signals.map((s) => s.label).join(' · ');
    return level.desc;
  }

  factory RiskAssessment.fromJson(Json j) => RiskAssessment(
    score: asInt(j['score']),
    level: RiskLevel.parse(j['level']),
    signals: asList(j['signals'], RiskSignal.fromJson),
    explanation: asString(j['explanation']),
    needsApproval: asBool(j['needs_approval']),
    sleepWindow: asBool(j['sleep_window']),
    model: j['model'] is Map<String, dynamic> ? AnomalyInfo.fromJson(j['model'] as Json) : null,
  );
}

/// 거래 보류 및 보호자 확인 요청.
class ApprovalRequest {
  final String id;
  final String memberId;
  final String type; // transfer / payment / mode / unfreeze
  final String title;
  final int amount;
  final String detail;
  final RiskAssessment? risk;
  final String? incidentId;
  final String status; // pending / reconfirm / approved / rejected / cancelled / expired / failed
  final String channel;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? reconfirmUntil;
  final DateTime? decidedAt;
  final String? decidedBy;
  final String? failReason;

  const ApprovalRequest({
    required this.id,
    required this.memberId,
    required this.type,
    required this.title,
    required this.status,
    required this.createdAt,
    this.amount = 0,
    this.detail = '',
    this.risk,
    this.incidentId,
    this.channel = '앱 알림',
    this.expiresAt,
    this.reconfirmUntil,
    this.decidedAt,
    this.decidedBy,
    this.failReason,
  });

  bool get isHold => type == 'transfer' || type == 'savings_cancel' || type == 'loan_apply';
  bool get isPending => status == 'pending';
  bool get isReconfirm => status == 'reconfirm';
  bool get isActive => status == 'pending' || status == 'reconfirm';
  String get easyExplanation => risk?.easyExplanation ?? detail;

  factory ApprovalRequest.fromJson(Json j) => ApprovalRequest(
    id: asString(j['id']),
    memberId: asString(j['member_id']),
    type: asString(j['type']),
    title: asString(j['title']),
    amount: asInt(j['amount']),
    detail: asString(j['detail']),
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
    incidentId: asStringOrNull(j['incident_id']),
    status: asString(j['status']),
    channel: asString(j['channel'], '앱 알림'),
    createdAt: asDateOr(j['created_at'], DateTime.now()),
    expiresAt: asDate(j['expires_at']),
    reconfirmUntil: asDate(j['reconfirm_until']),
    decidedAt: asDate(j['decided_at']),
    decidedBy: asStringOrNull(j['decided_by']),
    failReason: asStringOrNull(j['fail_reason']),
  );
}

/// 보호자에게 보이는 가족 알림.
class FamilyAlert {
  final String id;
  final String memberId;
  final String title;
  final int amount;
  final String status;
  final String emoji;
  final String? requestId;
  final DateTime at;

  const FamilyAlert({
    required this.id,
    required this.memberId,
    required this.title,
    required this.status,
    required this.at,
    this.amount = 0,
    this.emoji = '',
    this.requestId,
  });

  factory FamilyAlert.fromJson(Json j) => FamilyAlert(
    id: asString(j['id']),
    memberId: asString(j['member_id']),
    title: asString(j['title']),
    amount: asInt(j['amount']),
    status: asString(j['status']),
    emoji: asString(j['emoji']),
    requestId: asStringOrNull(j['request_id']),
    at: asDateOr(j['at'], DateTime.fromMillisecondsSinceEpoch(0)),
  );
}

/// 상황별 안심 모드 (MCC 화이트리스트).
class ModeInfo {
  final String id;
  final String label;
  final String short;
  final String icon;
  final String desc;
  final String schedule;
  final List<String>? allow;
  final List<String> allowedMcc;

  const ModeInfo({
    required this.id,
    required this.label,
    required this.short,
    required this.desc,
    this.icon = '',
    this.schedule = '',
    this.allow,
    this.allowedMcc = const [],
  });

  bool get restricted => allow != null;

  factory ModeInfo.fromJson(Json j) => ModeInfo(
    id: asString(j['id']),
    label: asString(j['label']),
    short: asString(j['short']),
    icon: asString(j['icon']),
    desc: asString(j['desc']),
    schedule: asString(j['schedule']),
    allow: j['allow'] is List ? asStrings(j['allow']) : null,
    allowedMcc: asStrings(j['allowed_mcc']),
  );
}

class ApprovalConfig {
  final int holdSeconds;
  final int reconfirmSeconds;
  final int approvalTimeoutSeconds;
  final int cautionModeHours;
  final int freezeHours;

  const ApprovalConfig({
    this.holdSeconds = 1800,
    this.reconfirmSeconds = 86400,
    this.approvalTimeoutSeconds = 180,
    this.cautionModeHours = 24,
    this.freezeHours = 24,
  });

  factory ApprovalConfig.fromJson(Json j) => ApprovalConfig(
    holdSeconds: asInt(j['hold_seconds'], 1800),
    reconfirmSeconds: asInt(j['reconfirm_seconds'], 86400),
    approvalTimeoutSeconds: asInt(j['approval_timeout_seconds'], 180),
    cautionModeHours: asInt(j['caution_mode_hours'], 24),
    freezeHours: asInt(j['freeze_hours'], 24),
  );
}

/// /api/v1/state 전체.
class FamilySnapshot {
  final DateTime serverTime;
  final ApprovalConfig config;
  final Guardian guardian;
  final List<Member> members;
  final List<ApprovalRequest> requests;
  final List<Incident> incidents;
  final CallSession? activeCall;
  final List<CallSession> calls;
  final List<FamilyAlert> alerts;
  final List<ModeInfo> modes;
  final List<String> banks;
  final List<CallScript> callScripts;
  final LoanProduct loanProduct;
  final int blockedToday;
  final int riskyTransfers;

  const FamilySnapshot({
    required this.serverTime,
    required this.guardian,
    required this.members,
    this.config = const ApprovalConfig(),
    this.requests = const [],
    this.incidents = const [],
    this.activeCall,
    this.calls = const [],
    this.alerts = const [],
    this.modes = const [],
    this.banks = const [],
    this.callScripts = const [],
    this.loanProduct = LoanProduct.defaultProduct,
    this.blockedToday = 0,
    this.riskyTransfers = 0,
  });

  factory FamilySnapshot.fromJson(Json j) {
    final catalog = asJson(j['catalog']);
    final stats = asJson(j['stats']);
    final calls = asList(j['calls'], CallSession.fromJson);
    final activeCall = j['active_call'] is Map<String, dynamic>
        ? CallSession.fromJson(j['active_call'] as Json)
        : calls.where((c) => !c.isEnded).firstOrNull;
    return FamilySnapshot(
      serverTime: asDateOr(j['server_time'], DateTime.now()),
      config: ApprovalConfig.fromJson(asJson(j['config'])),
      guardian: Guardian.fromJson(asJson(j['guardian'])),
      members: asList(j['members'], Member.fromJson),
      requests: asList(j['requests'], ApprovalRequest.fromJson),
      incidents: asList(j['incidents'], Incident.fromJson),
      activeCall: activeCall,
      calls: calls,
      alerts: asList(j['alerts'], FamilyAlert.fromJson),
      modes: asList(catalog['modes'], ModeInfo.fromJson),
      banks: asStrings(catalog['banks']),
      callScripts: asList(catalog['call_scripts'], CallScript.fromJson),
      loanProduct: catalog['loan_product'] is Map<String, dynamic>
          ? LoanProduct.fromJson(catalog['loan_product'] as Json)
          : LoanProduct.defaultProduct,
      blockedToday: asInt(stats['blocked_today']),
      riskyTransfers: asInt(stats['risky_transfers']),
    );
  }

  CallSession? callOrNull(String? id) {
    if (id == null || id.isEmpty) return activeCall;
    if (activeCall?.id == id) return activeCall;
    return calls.where((c) => c.id == id).firstOrNull;
  }

  /// 계좌 주인 (보호 대상 가족 또는 보호자 본인).
  Member? memberOrNull(String id) =>
      members.where((m) => m.id == id).firstOrNull ?? (guardian.banking?.id == id ? guardian.banking : null);

  /// 이 사용자가 쓰는 내 계좌 (보호자는 본인 계좌).
  Member? accountOf(Persona p) => p.memberId == null ? guardian.banking : memberOrNull(p.memberId!);

  Member member(String id) {
    final m = memberOrNull(id);
    if (m == null) throw StateError('알 수 없는 사용자: $id');
    return m;
  }

  ModeInfo mode(String id) =>
      modes.where((m) => m.id == id).firstOrNull ?? ModeInfo(id: id, label: id, short: id, desc: '');

  ApprovalRequest? request(String id) => requests.where((r) => r.id == id).firstOrNull;

  List<ApprovalRequest> pending([String? memberId]) =>
      requests.where((r) => r.isActive && (memberId == null || r.memberId == memberId)).toList(growable: false);

  bool hasPending(String memberId, String type) => pending(memberId).any((r) => r.type == type);

  Incident? incidentOrNull(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final m in members) {
      if (m.activeIncident?.id == id) return m.activeIncident;
    }
    return incidents.where((i) => i.id == id).firstOrNull;
  }

  Incident? openIncidentFor(String memberId) =>
      memberOrNull(memberId)?.activeIncident ??
      incidents.where((i) => i.memberId == memberId && i.isOpen).firstOrNull;

  List<Incident> get closedIncidents => incidents.where((i) => i.isClosed).toList(growable: false);
}
