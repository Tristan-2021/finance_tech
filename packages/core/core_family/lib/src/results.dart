import 'json.dart';
import 'models.dart';

class NewAccount {
  final String bank;
  final String number;
  final String name;

  const NewAccount({required this.bank, required this.number, required this.name});

  Json toJson() => {'bank': bank, 'number': number, 'name': name};
}

/// 송금 시트에서 만드는 초안. 등록된 받는 분(contactId) 또는 새 계좌 중 하나.
class TransferDraft {
  final String? contactId;
  final NewAccount? newAccount;
  final int amount;
  final bool confirmed;
  final String? questionAnswer;

  const TransferDraft({
    this.contactId,
    this.newAccount,
    this.amount = 0,
    this.confirmed = false,
    this.questionAnswer,
  });

  TransferDraft copyWith({
    String? contactId,
    NewAccount? newAccount,
    int? amount,
    bool? confirmed,
    String? questionAnswer,
    bool clearContact = false,
    bool clearQuestionAnswer = false,
  }) => TransferDraft(
    contactId: clearContact ? null : (contactId ?? this.contactId),
    newAccount: contactId != null ? null : (newAccount ?? this.newAccount),
    amount: amount ?? this.amount,
    confirmed: confirmed ?? this.confirmed,
    questionAnswer: clearQuestionAnswer ? null : (questionAnswer ?? this.questionAnswer),
  );

  Json toJson(String memberId) => {
    'member_id': memberId,
    'contact_id': contactId,
    'new_account': newAccount?.toJson(),
    'amount': amount,
    'confirmed': confirmed,
    'question_answer': ?questionAnswer,
  };
}

class Recipient {
  final String name;
  final String relation;
  final String bank;
  final String number;
  final bool isNew;
  final String? contactId;

  const Recipient({
    required this.name,
    required this.bank,
    required this.number,
    this.relation = '',
    this.isNew = false,
    this.contactId,
  });

  factory Recipient.fromJson(Json j) => Recipient(
    name: asString(j['name']),
    relation: asString(j['relation']),
    bank: asString(j['bank']),
    number: asString(j['number']),
    isNew: asBool(j['is_new']),
    contactId: asStringOrNull(j['contact_id']),
  );
}

/// AI 안심 점검 결과 (송금 전 미리보기).
class TransferPreview {
  final Recipient recipient;
  final int amount;
  final RiskAssessment risk;
  final int avgTransfer;
  final bool needsQuestion;

  const TransferPreview({
    required this.recipient,
    required this.amount,
    required this.risk,
    this.avgTransfer = 0,
    this.needsQuestion = false,
  });

  factory TransferPreview.fromJson(Json j) => TransferPreview(
    recipient: Recipient.fromJson(asJson(j['recipient'])),
    amount: asInt(j['amount']),
    risk: RiskAssessment.fromJson(asJson(j['risk'])),
    avgTransfer: asInt(j['avg_transfer']),
    needsQuestion: asBool(j['needs_question']),
  );
}

class TransferResult {
  /// done: 바로 보냄 / pending: 30분 보류 / caution: 본인 주의 확인 필요 / question: 확인 질문 필요
  final String status;
  final ApprovalRequest? request;
  final Recipient? recipient;
  final int amount;
  final RiskAssessment? risk;
  final ConfirmationQuestion? question;

  const TransferResult({
    required this.status,
    this.request,
    this.recipient,
    this.amount = 0,
    this.risk,
    this.question,
  });

  bool get isPending => status == 'pending';
  bool get isCaution => status == 'caution';
  bool get needsQuestion => status == 'question' && question != null;

  factory TransferResult.fromJson(Json j) => TransferResult(
    status: asString(j['status']),
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
    recipient: j['recipient'] is Map<String, dynamic> ? Recipient.fromJson(j['recipient'] as Json) : null,
    amount: asInt(j['amount'], asInt(asJson(j['request'])['amount'])),
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
    question: j['question'] is Map<String, dynamic> ? ConfirmationQuestion.fromJson(j['question'] as Json) : null,
  );
}

class ConfirmationQuestionResult {
  final bool needsQuestion;
  final bool cautionMode;
  final ConfirmationQuestion? question;

  const ConfirmationQuestionResult({
    required this.needsQuestion,
    this.cautionMode = false,
    this.question,
  });

  factory ConfirmationQuestionResult.fromJson(Json j) => ConfirmationQuestionResult(
    needsQuestion: asBool(j['needs_question']),
    cautionMode: asBool(j['caution_mode']),
    question: j['question'] is Map<String, dynamic> ? ConfirmationQuestion.fromJson(j['question'] as Json) : null,
  );
}

class SavingsCancelResult {
  final String status; // done / question / caution / pending
  final BankAccount? account;
  final SavingsCancelCalculation? calculation;
  final ConfirmationQuestion? question;
  final ApprovalRequest? request;
  final RiskAssessment? risk;

  const SavingsCancelResult({
    required this.status,
    this.account,
    this.calculation,
    this.question,
    this.request,
    this.risk,
  });

  bool get needsQuestion => status == 'question' && question != null;
  bool get isCaution => status == 'caution';
  bool get isPending => status == 'pending';

  factory SavingsCancelResult.fromJson(Json j) => SavingsCancelResult(
    status: asString(j['status']),
    account: j['account'] is Map<String, dynamic> ? BankAccount.fromJson(j['account'] as Json) : null,
    calculation: j['calculation'] is Map<String, dynamic>
        ? SavingsCancelCalculation.fromJson(j['calculation'] as Json)
        : null,
    question: j['question'] is Map<String, dynamic> ? ConfirmationQuestion.fromJson(j['question'] as Json) : null,
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
  );
}

class LoanLimitResult {
  final String status; // done / question / caution / danger
  final LoanProduct? product;
  final int maxLimit;
  final LoanQuote? sampleQuote;
  final ConfirmationQuestion? question;
  final RiskAssessment? risk;
  final bool guardianNotified;

  const LoanLimitResult({
    required this.status,
    this.product,
    this.maxLimit = 0,
    this.sampleQuote,
    this.question,
    this.risk,
    this.guardianNotified = false,
  });

  bool get needsQuestion => status == 'question' && question != null;
  bool get isCaution => status == 'caution';
  bool get isDanger => status == 'danger';

  factory LoanLimitResult.fromJson(Json j) => LoanLimitResult(
    status: asString(j['status']),
    product: j['product'] is Map<String, dynamic> ? LoanProduct.fromJson(j['product'] as Json) : null,
    maxLimit: asInt(j['max_limit']),
    sampleQuote: j['sample_quote'] is Map<String, dynamic> ? LoanQuote.fromJson(j['sample_quote'] as Json) : null,
    question: j['question'] is Map<String, dynamic> ? ConfirmationQuestion.fromJson(j['question'] as Json) : null,
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
    guardianNotified: asBool(j['guardian_notified']),
  );
}

class LoanApplyResult {
  final String status; // done / question / caution / pending
  final LoanProduct? product;
  final LoanQuote? quote;
  final int amount;
  final ConfirmationQuestion? question;
  final ApprovalRequest? request;
  final RiskAssessment? risk;

  const LoanApplyResult({
    required this.status,
    this.product,
    this.quote,
    this.amount = 0,
    this.question,
    this.request,
    this.risk,
  });

  bool get needsQuestion => status == 'question' && question != null;
  bool get isCaution => status == 'caution';
  bool get isPending => status == 'pending';

  factory LoanApplyResult.fromJson(Json j) => LoanApplyResult(
    status: asString(j['status']),
    product: j['product'] is Map<String, dynamic> ? LoanProduct.fromJson(j['product'] as Json) : null,
    quote: j['quote'] is Map<String, dynamic> ? LoanQuote.fromJson(j['quote'] as Json) : null,
    amount: asInt(j['amount']),
    question: j['question'] is Map<String, dynamic> ? ConfirmationQuestion.fromJson(j['question'] as Json) : null,
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
    risk: j['risk'] is Map<String, dynamic> ? RiskAssessment.fromJson(j['risk'] as Json) : null,
  );
}

class PaymentResult {
  final bool ok;
  final String code;
  final String message;
  final bool canRequest;
  final Merchant merchant;
  final ApprovalRequest? request;

  const PaymentResult({
    required this.ok,
    required this.code,
    required this.merchant,
    this.message = '',
    this.canRequest = false,
    this.request,
  });

  bool get isPending => ok && code == 'pending';

  factory PaymentResult.fromJson(Json j) => PaymentResult(
    ok: asBool(j['ok']),
    code: asString(j['code']),
    message: asString(j['message']),
    canRequest: asBool(j['can_request']),
    merchant: Merchant.fromJson(asJson(j['merchant'])),
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
  );
}

class ModeChangeResult {
  /// done / pending / same
  final String status;
  final ApprovalRequest? request;

  const ModeChangeResult(this.status, [this.request]);

  factory ModeChangeResult.fromJson(Json j) => ModeChangeResult(
    asString(j['status']),
    j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
  );
}

class FreezeResult {
  final bool alreadyFrozen;
  final int frozenAccountsCount;
  final DateTime? expiresAt;
  final bool guardianNotified;

  const FreezeResult({
    required this.alreadyFrozen,
    required this.frozenAccountsCount,
    required this.guardianNotified,
    this.expiresAt,
  });

  factory FreezeResult.fromJson(Json j) => FreezeResult(
    alreadyFrozen: asBool(j['already_frozen']),
    frozenAccountsCount: asInt(j['frozen_accounts_count']),
    expiresAt: asDate(j['freeze_expires_at']),
    guardianNotified: asBool(j['guardian_notified']),
  );
}

class DecisionResult {
  final String status; // approved / rejected / failed
  final String message;
  final ApprovalRequest? request;

  const DecisionResult(this.status, {this.message = '', this.request});

  factory DecisionResult.fromJson(Json j) => DecisionResult(
    asString(j['status']).toLowerCase(),
    message: asString(j['message']),
    request: j['request'] is Map<String, dynamic> ? ApprovalRequest.fromJson(j['request'] as Json) : null,
  );
}

/// 시연 문자 수신 결과 (기획서 5.2, 5.5).
class SmsReceiveResult {
  final String status;
  final SmsMessage message;
  final bool cautionMode;
  final DateTime? cautionUntil;

  const SmsReceiveResult({
    required this.status,
    required this.message,
    this.cautionMode = false,
    this.cautionUntil,
  });

  factory SmsReceiveResult.fromJson(Json j) => SmsReceiveResult(
    status: asString(j['status'], 'received'),
    message: SmsMessage.fromJson(asJson(j['message'])),
    cautionMode: asBool(j['caution_mode']),
    cautionUntil: asDate(j['caution_until']),
  );
}

/// 통화 음성 조각·대본 문장 분석 결과 (기획서 5.3, 5.5).
class CallAnalysisResult {
  final String status; // analyzed / empty / ignored
  final bool analyzed;
  final CallSession? call;
  final SmsRiskLevel level;
  final List<String> reasons;
  final String explanation;
  final bool cautionMode;
  final DateTime? cautionUntil;

  const CallAnalysisResult({
    required this.status,
    this.analyzed = true,
    this.call,
    this.level = SmsRiskLevel.low,
    this.reasons = const [],
    this.explanation = '',
    this.cautionMode = false,
    this.cautionUntil,
  });

  bool get isDanger => level == SmsRiskLevel.danger;

  factory CallAnalysisResult.fromJson(Json j) {
    final verdict = asJson(j['verdict']);
    return CallAnalysisResult(
      status: asString(j['status'], 'analyzed'),
      analyzed: asBool(j['analyzed'], true),
      call: j['call'] is Map<String, dynamic> ? CallSession.fromJson(j['call'] as Json) : null,
      level: SmsRiskLevel.parse(verdict['level']),
      reasons: asStrings(verdict['reasons']),
      explanation: asString(verdict['explanation']),
      cautionMode: asBool(j['caution_mode']),
      cautionUntil: asDate(j['caution_until']),
    );
  }
}

/// 서버 실시간 이벤트. [fromThisDevice]이면 이 기기의 요청으로 생긴 이벤트입니다.
class FamilyEvent {
  final String type;
  final String message;
  final String? memberId;
  final String? requestId;
  final String? smsId;
  final String? callId;
  final String? level;
  final String? explanation;
  final List<String> reasons;
  final bool fromThisDevice;

  const FamilyEvent({
    required this.type,
    this.message = '',
    this.memberId,
    this.requestId,
    this.smsId,
    this.callId,
    this.level,
    this.explanation,
    this.reasons = const [],
    this.fromThisDevice = false,
  });

  factory FamilyEvent.fromJson(Json j, {required String clientId}) => FamilyEvent(
    type: asString(j['type']),
    message: asString(j['message']),
    memberId: asStringOrNull(j['member_id']),
    requestId: asStringOrNull(j['request_id']),
    smsId: asStringOrNull(j['sms_id']),
    callId: asStringOrNull(j['call_id']),
    level: asStringOrNull(j['level']),
    explanation: asStringOrNull(j['explanation']),
    reasons: asStrings(j['reasons']),
    fromThisDevice: j['origin'] == clientId,
  );
}

/// 외부 연동 기록 (오픈뱅킹 · FCM · SMS).
class IntegrationLogEntry {
  final String id;
  final DateTime at;
  final String channel;
  final String action;
  final String target;
  final String message;

  const IntegrationLogEntry({
    required this.id,
    required this.at,
    required this.channel,
    required this.action,
    required this.target,
    required this.message,
  });

  factory IntegrationLogEntry.fromJson(Json j) => IntegrationLogEntry(
    id: asString(j['id']),
    at: asDateOr(j['at'], DateTime.now()),
    channel: asString(j['channel']),
    action: asString(j['action']),
    target: asString(j['target']),
    message: asString(j['message']),
  );
}

/// 보호자 연결 QR/코드 발급 결과 (기획서 5.8).
class PairingCodeResult {
  final String code;
  final String qrValue;
  final String guardianId;
  final String guardianName;
  final String memberId;
  final String memberName;
  final DateTime expiresAt;
  final int expiresInSeconds;

  const PairingCodeResult({
    required this.code,
    required this.qrValue,
    required this.guardianId,
    required this.guardianName,
    required this.memberId,
    required this.memberName,
    required this.expiresAt,
    this.expiresInSeconds = 300,
  });

  factory PairingCodeResult.fromJson(Json j) => PairingCodeResult(
    code: asString(j['code']),
    qrValue: asString(j['qr_value'], asString(j['code'])),
    guardianId: asString(j['guardian_id'], 'guardian'),
    guardianName: asString(j['guardian_name']),
    memberId: asString(j['member_id'], 'senior'),
    memberName: asString(j['member_name']),
    expiresAt: asDateOr(j['expires_at'], DateTime.now().add(const Duration(minutes: 5))),
    expiresInSeconds: asInt(j['expires_in_seconds'], 300),
  );
}

/// 보호자 연결 및 동의 완료 결과 (기획서 5.8).
class PairingConnectResult {
  final String status;
  final String memberId;
  final String guardianId;
  final String guardianName;
  final DateTime? pairedAt;
  final DateTime? consentAt;

  const PairingConnectResult({
    required this.status,
    required this.memberId,
    required this.guardianId,
    required this.guardianName,
    this.pairedAt,
    this.consentAt,
  });

  factory PairingConnectResult.fromJson(Json j) => PairingConnectResult(
    status: asString(j['status'], 'connected'),
    memberId: asString(j['member_id'], 'senior'),
    guardianId: asString(j['guardian_id'], 'guardian'),
    guardianName: asString(j['guardian_name']),
    pairedAt: asDate(j['paired_at']),
    consentAt: asDate(j['consent_at']),
  );
}
