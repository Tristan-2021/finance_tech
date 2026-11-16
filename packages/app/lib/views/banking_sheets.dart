import 'dart:async';
import 'dart:math' as math;

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_links.dart';

/// 계좌 조회 시트를 엽니다 (적금·예금 및 대출 진입점).
Future<void> openAccountsSheet(
  BuildContext context,
  String memberId, {
  Duration cardReadDelay = const Duration(seconds: 3),
}) => showFbSheet<void>(
  context,
  builder: (_) => AccountsSheet(memberId: memberId, cardReadDelay: cardReadDelay),
);

/// 적금·예금 만기 전 해지 흐름 시트를 엽니다 (기획서 5.4, 7.2).
Future<void> openSavingsCancelSheet(
  BuildContext context,
  String memberId,
  String accountId, {
  Duration cardReadDelay = const Duration(seconds: 3),
}) => showFbSheet<void>(
  context,
  builder: (_) => SavingsCancelSheet(
    memberId: memberId,
    accountId: accountId,
    cardReadDelay: cardReadDelay,
  ),
);

/// 대출 한도 조회 및 신청 흐름 시트를 엽니다 (기획서 5.4, 7.2).
Future<void> openLoanSheet(
  BuildContext context,
  String memberId, {
  Duration cardReadDelay = const Duration(seconds: 3),
}) => showFbSheet<void>(
  context,
  builder: (_) => LoanSheet(memberId: memberId, cardReadDelay: cardReadDelay),
);

void _callGuardian(BuildContext context, String memberId) =>
    AppLinks.openCall(context.read<ShellCubit>(), peer: 'guardian');

Future<void> _showGlossaryDialog(BuildContext context, String term, String explanation) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(term, style: const TextStyle(fontWeight: FontWeight.w800)),
    content: Text(explanation, style: const TextStyle(height: 1.6)),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('이해했어요')),
    ],
  ),
);

Future<bool> _showDisadvantageConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.fb;
      return AlertDialog(
        icon: Icon(FbIcons.alert, color: c.redStrong, size: 32),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: c.redStrong)),
        content: Text(message, style: TextStyle(height: 1.6, color: c.ink, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('돌아가기')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return res ?? false;
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}년 ${local.month}월 ${local.day}일';
}

/// 계좌 조회 시트: 입출금 통장, 적금·예금(만기 전 해지), 대출 안내, 거래 내역 이동.
class AccountsSheet extends StatelessWidget {
  final String memberId;
  final Duration cardReadDelay;

  const AccountsSheet({
    super.key,
    required this.memberId,
    this.cardReadDelay = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final m = state.data.memberOrNull(memberId);
        if (m == null) return const EmptyText('사용자를 찾을 수 없어요');
        final hidden = context.select((ShellCubit s) => s.state.prefs.hideBalance);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHead(title: '계좌 조회', onClose: () => Navigator.of(context).maybePop()),
            Text('${m.name}님의 보유 계좌예요.', style: FbText.hint(c)),
            const SizedBox(height: 12),
            for (final acct in m.accounts) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: c.cardBorder != null ? Border.all(color: c.cardBorder!) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            acct.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.ink),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: acct.isSavings ? c.blueSoft : c.card,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            acct.isSavings ? '적금·예금' : '입출금',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: acct.isSavings ? c.blueStrong : c.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${acct.bank} ${acct.number}', style: FbText.small(c)),
                    const SizedBox(height: 8),
                    Text(
                      acct.isActive ? wonOrHidden(acct.balance, hidden: hidden) : '만기 전 해지 완료',
                      style: FbText.bigAmount(c).copyWith(color: acct.isActive ? c.ink : c.muted),
                    ),
                    if (acct.isSavings && acct.isActive) ...[
                      const SizedBox(height: 8),
                      Text(
                        '금리 연 ${acct.interestRate.toStringAsFixed(1)}% · 쌓인 이자 ${wonOrHidden(acct.accruedInterest, hidden: hidden)}',
                        style: FbText.small(c).copyWith(color: c.ink2, fontWeight: FontWeight.w600),
                      ),
                      if (acct.maturityDate != null)
                        Text('만기일 ${_formatDate(acct.maturityDate!)}', style: FbText.small(c)),
                      const SizedBox(height: 12),
                      FbButton.gray(
                        '만기 전 해지',
                        onPressed: () {
                          Navigator.of(context).pop();
                          openSavingsCancelSheet(context, m.id, acct.id, cardReadDelay: cardReadDelay);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!m.isChild) ...[
              FbListRow(
                leading: const TxLogo(icon: FbIcons.card, blue: true),
                title: const Text('대출 한도 조회·신청'),
                subtitle: '금리·상환 금액을 먼저 쉬운 설명으로 확인해요',
                chevron: true,
                onTap: () {
                  Navigator.of(context).pop();
                  openLoanSheet(context, m.id, cardReadDelay: cardReadDelay);
                },
              ),
            ],
            FbListRow(
              leading: const TxLogo(icon: FbIcons.list),
              title: const Text('거래 내역 보기'),
              subtitle: '입금·출금·보호 기록을 확인해요',
              chevron: true,
              onTap: () {
                Navigator.of(context).pop();
                context.read<ShellCubit>().switchTab(AppTab.history);
              },
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// 적금·예금 만기 전 해지 흐름 (기획서 5.4, 7.2)
// ============================================================================

enum _SavingsStep { rate, loss, payout, comprehension, question, caution, waiting, done }

class SavingsCancelSheet extends StatefulWidget {
  final String memberId;
  final String accountId;
  final Duration cardReadDelay;

  const SavingsCancelSheet({
    super.key,
    required this.memberId,
    required this.accountId,
    this.cardReadDelay = const Duration(seconds: 3),
  });

  @override
  State<SavingsCancelSheet> createState() => _SavingsCancelSheetState();
}

class _SavingsCancelSheetState extends State<SavingsCancelSheet> {
  _SavingsStep _step = _SavingsStep.rate;
  Timer? _readTimer;
  bool _canAdvance = false;
  int? _comprehensionIndex;
  String? _comprehensionHint;
  bool _busy = false;

  ConfirmationQuestion? _question;
  String? _questionAnswer;
  RiskAssessment? _cautionRisk;
  SavingsCancelCalculation? _resultCalc;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _armReadTimer();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  void _armReadTimer() {
    _readTimer?.cancel();
    if (widget.cardReadDelay <= Duration.zero) {
      _canAdvance = true;
      return;
    }
    _canAdvance = false;
    _readTimer = Timer(widget.cardReadDelay, () {
      if (mounted) setState(() => _canAdvance = true);
    });
  }

  void _go(_SavingsStep next) {
    setState(() {
      _step = next;
      _comprehensionHint = null;
      if (next == _SavingsStep.rate || next == _SavingsStep.loss || next == _SavingsStep.payout) {
        _armReadTimer();
      }
    });
  }

  void _close() => Navigator.of(context).maybePop();

  Future<void> _confirmBeforeComprehension(SavingsCancelCalculation calc) async {
    final ok = await _showDisadvantageConfirmDialog(
      context,
      title: '줄어드는 이자를 확인하셨나요?',
      message: '만기 전에 해지하면 받을 수 있는 이자가 ${won(calc.reducedInterest)} 줄어들어 ${won(calc.earlyCancelInterest)}만 받게 돼요.\n그래도 해지를 계속 알아볼까요?',
      confirmLabel: '확인했어요',
    );
    if (ok && mounted) _go(_SavingsStep.comprehension);
  }

  Future<void> _submitCancel({String? answer, bool confirmed = false}) async {
    setState(() => _busy = true);
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      final res = await family.cancelSavings(
        widget.memberId,
        widget.accountId,
        questionAnswer: answer,
        confirmed: confirmed,
      );
      if (!mounted) return;
      if (res.needsQuestion) {
        setState(() {
          _busy = false;
          _question = res.question;
          _step = _SavingsStep.question;
        });
        return;
      }
      if (res.isCaution) {
        setState(() {
          _busy = false;
          _cautionRisk = res.risk;
          _resultCalc = res.calculation;
          _step = _SavingsStep.caution;
        });
        shell.say(
          '주의가 필요해요 · ${res.risk?.easyExplanation ?? '주의 모드 중 적금을 해지하려고 해요. 다시 한 번 확인해 주세요.'}',
          toast: false,
          vibrate: const [60],
          speak: true,
        );
        return;
      }
      if (res.isPending) {
        setState(() {
          _busy = false;
          _requestId = res.request?.id;
          _resultCalc = res.calculation;
          _step = _SavingsStep.waiting;
        });
        shell.say('해지를 30분 동안 보류하고 보호자에게 알렸어요', toast: false, vibrate: const [60]);
        return;
      }
      setState(() {
        _busy = false;
        _resultCalc = res.calculation;
        _step = _SavingsStep.done;
      });
      shell.say('적금을 만기 전 해지했어요', toast: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      shell.say(e.message, vibrate: const [80, 40, 80]);
    }
  }

  SavingsCancelCalculation _calcFor(BankAccount acct) =>
      acct.earlyCancelPreview ??
      SavingsCancelCalculation(
        principal: acct.balance,
        interestRate: acct.interestRate,
        earlyCancelRate: acct.earlyCancelRate,
        accruedInterest: acct.accruedInterest,
        earlyCancelInterest: acct.interestRate == 0
            ? 0
            : (acct.accruedInterest * (acct.earlyCancelRate / acct.interestRate)).round(),
        reducedInterest: acct.interestRate == 0
            ? 0
            : math.max(0, acct.accruedInterest - (acct.accruedInterest * (acct.earlyCancelRate / acct.interestRate)).round()),
        payoutAmount: acct.balance +
            (acct.interestRate == 0 ? 0 : (acct.accruedInterest * (acct.earlyCancelRate / acct.interestRate)).round()),
      );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        final data = state.data;
        final member = data.memberOrNull(widget.memberId);
        if (member == null) return const EmptyText('사용자를 찾을 수 없어요');
        final acct = member.accounts.where((a) => a.id == widget.accountId).firstOrNull;
        final calc = _resultCalc ?? (acct != null ? _calcFor(acct) : null);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              _SavingsStep.rate => _rateCard(acct!, calc!),
              _SavingsStep.loss => _lossCard(acct!, calc!),
              _SavingsStep.payout => _payoutCard(acct!, calc!),
              _SavingsStep.comprehension => _comprehensionCard(calc!),
              _SavingsStep.question => ConfirmationQuestionView(
                question: _question!.question,
                options: _question!.options,
                busy: _busy,
                onBack: () => _go(_SavingsStep.comprehension),
                onClose: _close,
                onAskGuardian: () => _callGuardian(context, widget.memberId),
                onSelected: (opt) {
                  _questionAnswer = opt;
                  _submitCancel(answer: opt);
                },
              ),
              _SavingsStep.caution => _cautionCard(),
              _SavingsStep.waiting => _HoldWaitingPanel(
                member: member,
                data: data,
                requestId: _requestId,
                doneTitle: '적금 해지를 마쳤어요',
                doneBody: '보류가 해제되어 입출금 통장으로 입금되었어요.',
                onClose: _close,
              ),
              _SavingsStep.done => _doneCard(calc!),
            },
          ),
        );
      },
    );
  }

  Widget _rateCard(BankAccount acct, SavingsCancelCalculation calc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '만기 전 해지 안내', onClose: _close),
        _DisclosureHeader(stepText: '1 / 4', cardTitle: '이자율과 만기 안내'),
        const SizedBox(height: 12),
        _InfoCardBox(
          children: [
            _KeyValueLine('약정 이자율', '연 ${calc.interestRate.toStringAsFixed(1)}%', highlight: true),
            const SizedBox(height: 8),
            _KeyValueLine('만기 전 해지 이율', '연 ${calc.earlyCancelRate.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            _KeyValueLine('원금', won(calc.principal)),
            const SizedBox(height: 8),
            _KeyValueLine('지금까지 쌓인 이자', won(calc.accruedInterest)),
            if (acct.maturityDate != null) ...[
              const SizedBox(height: 8),
              _KeyValueLine('만기일', _formatDate(acct.maturityDate!)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _TermGlossaryRow(
          terms: const [
            ('만기 전 해지 이율', '약속한 만기 날짜 전에 적금을 깰 때 대신 적용되는 낮은 이자율이에요.'),
            ('약정 금리', '만기까지 기다렸을 때 받기로 약속한 이자율이에요.'),
          ],
        ),
        const SizedBox(height: 14),
        _ReadAdvanceControls(
          canAdvance: _canAdvance,
          delaySeconds: widget.cardReadDelay.inSeconds,
          nextLabel: '다음',
          onNext: () => _go(_SavingsStep.loss),
          onAskGuardian: () => _callGuardian(context, widget.memberId),
        ),
      ],
    );
  }

  Widget _lossCard(BankAccount acct, SavingsCancelCalculation calc) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '만기 전 해지 안내', onBack: () => _go(_SavingsStep.rate), onClose: _close),
        _DisclosureHeader(stepText: '2 / 4', cardTitle: '줄어드는 이자 (불이익)'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.redSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.red.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FbIcons.alert, size: 20, color: c.redStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '줄어드는 이자 ${won(calc.reducedInterest)}',
                      style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: c.redStrong),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '지금 ${acct.name}을 해지하면 약정 이자 ${won(calc.accruedInterest)} 대신 ${won(calc.earlyCancelInterest)}만 받게 되어 ${won(calc.reducedInterest)}의 손해가 생겨요.',
                style: TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w700, color: c.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoCardBox(
          children: [
            _KeyValueLine('만기 시 쌓인 이자', won(calc.accruedInterest)),
            const SizedBox(height: 8),
            _KeyValueLine('만기 전 해지 시 이자', won(calc.earlyCancelInterest)),
            const SizedBox(height: 8),
            _KeyValueLine('줄어드는 이자', '-${won(calc.reducedInterest)}', danger: true),
          ],
        ),
        const SizedBox(height: 14),
        _ReadAdvanceControls(
          canAdvance: _canAdvance,
          delaySeconds: widget.cardReadDelay.inSeconds,
          nextLabel: '다음',
          onNext: () => _go(_SavingsStep.payout),
          onAskGuardian: () => _callGuardian(context, widget.memberId),
        ),
      ],
    );
  }

  Widget _payoutCard(BankAccount acct, SavingsCancelCalculation calc) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '만기 전 해지 안내', onBack: () => _go(_SavingsStep.loss), onClose: _close),
        _DisclosureHeader(stepText: '3 / 4', cardTitle: '실제 받는 금액 확인'),
        const SizedBox(height: 12),
        _InfoCardBox(
          children: [
            _KeyValueLine('해지 계좌', acct.name),
            const SizedBox(height: 8),
            _KeyValueLine('원금', won(calc.principal)),
            const SizedBox(height: 8),
            _KeyValueLine('해지 시 받는 이자', won(calc.earlyCancelInterest)),
            const SizedBox(height: 8),
            _KeyValueLine('실제 받는 총 금액', won(calc.payoutAmount), highlight: true),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '입출금 통장으로 입금되며, 한 번 해지하면 되돌릴 수 없어요.',
          style: FbText.hint(c),
        ),
        const SizedBox(height: 14),
        _ReadAdvanceControls(
          canAdvance: _canAdvance,
          delaySeconds: widget.cardReadDelay.inSeconds,
          nextLabel: '다음',
          onNext: () => _confirmBeforeComprehension(calc),
          onAskGuardian: () => _callGuardian(context, widget.memberId),
        ),
      ],
    );
  }

  Widget _comprehensionCard(SavingsCancelCalculation calc) {
    final options = [
      '약정 금리 그대로 이자를 모두 받아요',
      '만기 전 해지 이율로 계산되어 이자 ${won(calc.reducedInterest)}이 줄어들어요',
      '원금에서도 수수료가 빠져요',
    ];
    return _ComprehensionCheckPanel(
      stepText: '4 / 4',
      question: '지금 적금을 만기 전에 해지하면 이자는 어떻게 되나요?',
      options: options,
      selectedIndex: _comprehensionIndex,
      hintText: _comprehensionHint,
      confirmLabel: '해지 신청하기',
      busy: _busy,
      onBack: () => _go(_SavingsStep.payout),
      onClose: _close,
      onAskGuardian: () => _callGuardian(context, widget.memberId),
      onSelectOption: (idx) => setState(() {
        _comprehensionIndex = idx;
        _comprehensionHint = idx == 1 ? null : '방금 설명한 내용을 다시 확인해 주세요. 만기 전에 해지하면 이자가 줄어들어요.';
      }),
      onSubmit: () {
        if (_comprehensionIndex != 1) {
          setState(() => _comprehensionHint = '정확한 내용을 선택해 주세요.');
          return;
        }
        _submitCancel();
      },
    );
  }

  Widget _cautionCard() {
    final c = context.fb;
    final exp = _cautionRisk?.easyExplanation ?? '주의 모드 중 적금을 해지하려고 해요. 다시 한 번 확인해 주세요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '한 번 더 확인해 주세요', onClose: _close),
        RiskBox(title: '주의가 필요해요', danger: true, items: [exp]),
        const SizedBox(height: 12),
        Text('누군가 전화나 문자로 해지를 시킨 것이 아닌지 꼭 확인하세요.', style: TextStyle(color: c.redStrong, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        FbButtonRow(
          children: [
            FbButton.gray('취소', onPressed: _close),
            FbButton('확인했어요, 해지 진행', busy: _busy, onPressed: () => _submitCancel(answer: _questionAnswer, confirmed: true)),
          ],
        ),
        const SizedBox(height: 8),
        FraudHelpButton(onCallGuardian: () => _callGuardian(context, widget.memberId)),
      ],
    );
  }

  Widget _doneCard(SavingsCancelCalculation calc) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetHead(onClose: _close),
      CenterBlock(
        icon: const ResultIcon(FbIcons.check),
        title: '만기 전 해지를 마쳤어요',
        body: '입출금 통장으로 ${won(calc.payoutAmount)}이 들어왔어요.\n(줄어든 이자 ${won(calc.reducedInterest)})',
      ),
      const SizedBox(height: 20),
      FbButton('확인', onPressed: _close),
    ],
  );
}

// ============================================================================
// 대출 한도 조회 및 신청 흐름 (기획서 5.4, 7.2)
// ============================================================================

enum _LoanStep { rateFee, repayment, rights, amountQuote, comprehension, question, caution, dangerLimit, waiting, done }

class LoanSheet extends StatefulWidget {
  final String memberId;
  final Duration cardReadDelay;

  const LoanSheet({
    super.key,
    required this.memberId,
    this.cardReadDelay = const Duration(seconds: 3),
  });

  @override
  State<LoanSheet> createState() => _LoanSheetState();
}

class _LoanSheetState extends State<LoanSheet> {
  _LoanStep _step = _LoanStep.rateFee;
  Timer? _readTimer;
  bool _canAdvance = false;
  bool _busy = false;
  int _selectedAmount = 5000000;
  LoanQuote? _quote;
  int? _comprehensionIndex;
  String? _comprehensionHint;
  String? _amountError;

  String _activeActionKind = 'loan_apply'; // 'loan_limit' | 'loan_apply'
  ConfirmationQuestion? _question;
  String? _questionAnswer;
  RiskAssessment? _cautionRisk;
  LoanLimitResult? _limitResult;
  String? _requestId;

  final _customAmountCtrl = TextEditingController(text: '5,000,000');
  final _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _armReadTimer();
    _quote = _computeLocalQuote(_selectedAmount, LoanProduct.defaultProduct);
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    _customAmountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _armReadTimer() {
    _readTimer?.cancel();
    if (widget.cardReadDelay <= Duration.zero) {
      _canAdvance = true;
      return;
    }
    _canAdvance = false;
    _readTimer = Timer(widget.cardReadDelay, () {
      if (mounted) setState(() => _canAdvance = true);
    });
  }

  void _go(_LoanStep next) {
    setState(() {
      _step = next;
      _comprehensionHint = null;
      _amountError = null;
      if (next == _LoanStep.rateFee || next == _LoanStep.repayment || next == _LoanStep.rights) {
        _armReadTimer();
      }
    });
  }

  void _close() => Navigator.of(context).maybePop();

  static LoanQuote _computeLocalQuote(int amount, LoanProduct p) {
    final monthlyRate = p.interestRate / 100.0 / 12.0;
    final factor = math.pow(1.0 + monthlyRate, p.termMonths).toDouble();
    final monthly = monthlyRate == 0
        ? (amount / p.termMonths).round()
        : (amount * (monthlyRate * factor) / (factor - 1.0)).round();
    final total = monthly * p.termMonths;
    return LoanQuote(
      amount: amount,
      annualRate: p.interestRate,
      termMonths: p.termMonths,
      monthlyPayment: monthly,
      totalInterest: math.max(0, total - amount),
      totalRepayment: total,
    );
  }

  Future<void> _selectAmount(int amount, LoanProduct p) async {
    _customAmountCtrl.text = formatNumber(amount);
    setState(() {
      _selectedAmount = amount;
      _amountError = null;
      _quote = _computeLocalQuote(amount, p);
    });
    try {
      final serverQuote = await context.read<FamilyCubit>().quoteLoan(amount);
      if (mounted && _selectedAmount == amount) {
        setState(() => _quote = serverQuote);
      }
    } on ApiException {
      // 오프라인/모의 예외 시 로컬 계산 값을 그대로 유지합니다.
    }
  }

  Future<void> _checkLimit({String? answer, bool confirmed = false}) async {
    _activeActionKind = 'loan_limit';
    setState(() => _busy = true);
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      final res = await family.checkLoanLimit(widget.memberId, questionAnswer: answer, confirmed: confirmed);
      if (!mounted) return;
      if (res.needsQuestion) {
        setState(() {
          _busy = false;
          _question = res.question;
          _step = _LoanStep.question;
        });
        return;
      }
      if (res.isDanger) {
        setState(() {
          _busy = false;
          _limitResult = res;
          _cautionRisk = res.risk;
          _step = _LoanStep.dangerLimit;
        });
        shell.say(
          '대출 한도 조회에서 위험이 감지되어 보호자에게 알렸어요 · ${res.risk?.easyExplanation ?? ''}',
          toast: false,
          vibrate: const [80, 40, 80],
          speak: true,
          alertSound: true,
        );
        return;
      }
      if (res.isCaution) {
        setState(() {
          _busy = false;
          _limitResult = res;
          _cautionRisk = res.risk;
          _step = _LoanStep.caution;
        });
        shell.say(
          '주의가 필요해요 · ${res.risk?.easyExplanation ?? ''}',
          toast: false,
          vibrate: const [60],
          speak: true,
        );
        return;
      }
      setState(() {
        _busy = false;
        _limitResult = res;
        _step = _LoanStep.amountQuote;
      });
      shell.say('최대 한도 ${won(res.maxLimit)}까지 이용할 수 있어요');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      shell.say(e.message);
    }
  }

  Future<void> _proceedToApplyComprehension(LoanProduct p) async {
    final parsed = int.tryParse(digitsOnly(_customAmountCtrl.text)) ?? 0;
    if (parsed < p.minAmount || parsed > p.maxLimit) {
      setState(() => _amountError = '대출 금액은 ${won(p.minAmount)}~${won(p.maxLimit)} 사이로 입력해 주세요.');
      _amountFocus.requestFocus();
      return;
    }
    _selectedAmount = parsed;
    _quote = _computeLocalQuote(parsed, p);

    final ok = await _showDisadvantageConfirmDialog(
      context,
      title: '연체 불이익과 취소 권리를 확인하셨나요?',
      message: '• 연체 시 연 ${p.delinquencyRate.toStringAsFixed(1)}%의 이자가 붙고 신용에 불이익이 생겨요.\n'
          '• 계약 뒤 ${p.withdrawalRightDays}일 안에 취소할 수 있어요(청약철회권).\n\n위 내용을 확인하고 이해 확인으로 넘어갈까요?',
      confirmLabel: '확인했어요',
    );
    if (ok && mounted) _go(_LoanStep.comprehension);
  }

  Future<void> _submitApply({String? answer, bool confirmed = false}) async {
    _activeActionKind = 'loan_apply';
    setState(() => _busy = true);
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      final res = await family.applyLoan(
        widget.memberId,
        _selectedAmount,
        questionAnswer: answer,
        confirmed: confirmed,
      );
      if (!mounted) return;
      if (res.needsQuestion) {
        setState(() {
          _busy = false;
          _question = res.question;
          _step = _LoanStep.question;
        });
        return;
      }
      if (res.isCaution) {
        setState(() {
          _busy = false;
          _cautionRisk = res.risk;
          _quote = res.quote ?? _quote;
          _step = _LoanStep.caution;
        });
        shell.say(
          '주의가 필요해요 · ${res.risk?.easyExplanation ?? ''}',
          toast: false,
          vibrate: const [60],
          speak: true,
        );
        return;
      }
      if (res.isPending) {
        setState(() {
          _busy = false;
          _requestId = res.request?.id;
          _quote = res.quote ?? _quote;
          _step = _LoanStep.waiting;
        });
        shell.say('대출 신청을 30분 동안 보류하고 보호자에게 알렸어요', toast: false, vibrate: const [60]);
        return;
      }
      setState(() {
        _busy = false;
        _quote = res.quote ?? _quote;
        _step = _LoanStep.done;
      });
      shell.say('대출 ${won(_selectedAmount)} 신청을 마쳤어요', toast: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      shell.say(e.message, vibrate: const [80, 40, 80]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        final data = state.data;
        final member = data.memberOrNull(widget.memberId);
        if (member == null) return const EmptyText('사용자를 찾을 수 없어요');
        final product = data.loanProduct;
        final quote = _quote ?? _computeLocalQuote(_selectedAmount, product);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              _LoanStep.rateFee => _rateFeeCard(product),
              _LoanStep.repayment => _repaymentCard(product),
              _LoanStep.rights => _rightsCard(product),
              _LoanStep.amountQuote => _amountQuoteCard(product, quote),
              _LoanStep.comprehension => _comprehensionCard(product),
              _LoanStep.question => ConfirmationQuestionView(
                question: _question!.question,
                options: _question!.options,
                busy: _busy,
                onBack: () => _go(_activeActionKind == 'loan_limit' ? _LoanStep.amountQuote : _LoanStep.comprehension),
                onClose: _close,
                onAskGuardian: () => _callGuardian(context, widget.memberId),
                onSelected: (opt) {
                  _questionAnswer = opt;
                  if (_activeActionKind == 'loan_limit') {
                    _checkLimit(answer: opt);
                  } else {
                    _submitApply(answer: opt);
                  }
                },
              ),
              _LoanStep.caution => _cautionCard(),
              _LoanStep.dangerLimit => _dangerLimitCard(data),
              _LoanStep.waiting => _HoldWaitingPanel(
                member: member,
                data: data,
                requestId: _requestId,
                doneTitle: '대출 실행을 마쳤어요',
                doneBody: '보류가 해제되어 입출금 통장으로 입금되었어요.',
                onClose: _close,
              ),
              _LoanStep.done => _doneCard(product, quote),
            },
          ),
        );
      },
    );
  }

  Widget _rateFeeCard(LoanProduct p) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: p.name, onClose: _close),
        _DisclosureHeader(stepText: '1 / 5', cardTitle: '금리와 수수료'),
        const SizedBox(height: 8),
        // 5단계 이상 흐름이므로 시작할 때 전체 단계를 먼저 보여 줍니다 (기획서 7.1 Ⅱ-④).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: c.blueSoft, borderRadius: BorderRadius.circular(12)),
          child: Text(
            '전체 5단계: 1. 금리·수수료 → 2. 상환·부담 금액 → 3. 불이익·취소 권리 → 4. 한도·금액 계산 → 5. 이해 확인',
            style: TextStyle(fontSize: 12.6, height: 1.5, fontWeight: FontWeight.w700, color: c.blueStrong),
          ),
        ),
        const SizedBox(height: 12),
        _InfoCardBox(
          children: [
            _KeyValueLine('이자율 (금리)', '연 ${p.interestRate.toStringAsFixed(1)}%', highlight: true),
            const SizedBox(height: 8),
            _KeyValueLine('금리 변동 여부', p.isVariableRate ? '변동금리 (시장 금리에 따라 바뀔 수 있어요)' : '고정금리'),
            const SizedBox(height: 8),
            _KeyValueLine('중도상환수수료', '미리 갚을 때 ${p.prepaymentFeeRate.toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            _KeyValueLine('최대 한도', won(p.maxLimit)),
          ],
        ),
        const SizedBox(height: 10),
        const _TermGlossaryRow(
          terms: [
            ('변동금리', '시장 금리가 오르거나 내리면 내 대출 이자율도 함께 바뀔 수 있는 방식이에요.'),
            ('중도상환수수료', '약속한 날짜보다 미리 돈을 갚을 때 일부 내는 수수료예요.'),
          ],
        ),
        const SizedBox(height: 14),
        _ReadAdvanceControls(
          canAdvance: _canAdvance,
          delaySeconds: widget.cardReadDelay.inSeconds,
          nextLabel: '다음',
          onNext: () => _go(_LoanStep.repayment),
          onAskGuardian: () => _callGuardian(context, widget.memberId),
        ),
      ],
    );
  }

  Widget _repaymentCard(LoanProduct p) {
    final sample = _computeLocalQuote(5000000, p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: p.name, onBack: () => _go(_LoanStep.rateFee), onClose: _close),
        _DisclosureHeader(stepText: '2 / 5', cardTitle: '상환 금액·이자율·시기와 부담 금액'),
        const SizedBox(height: 12),
        _InfoCardBox(
          children: [
            _KeyValueLine('상환 방식', p.repaymentMethod),
            const SizedBox(height: 8),
            _KeyValueLine('상환 시기·기간', '${p.repaymentCycle} · ${p.termMonths}개월'),
            const SizedBox(height: 8),
            _KeyValueLine('예시 (500만원 빌릴 때) 월 납입액', won(sample.monthlyPayment), highlight: true),
            const SizedBox(height: 8),
            _KeyValueLine('예시 총 이자', won(sample.totalInterest)),
            const SizedBox(height: 8),
            _KeyValueLine('예시 내가 갚을 총 금액', won(sample.totalRepayment)),
          ],
        ),
        const SizedBox(height: 10),
        const _TermGlossaryRow(
          terms: [
            ('원리금균등분할상환', '빌린 돈과 이자를 합쳐 매달 똑같은 금액으로 나누어 갚는 방식이에요.'),
          ],
        ),
        const SizedBox(height: 14),
        _ReadAdvanceControls(
          canAdvance: _canAdvance,
          delaySeconds: widget.cardReadDelay.inSeconds,
          nextLabel: '다음',
          onNext: () => _go(_LoanStep.rights),
          onAskGuardian: () => _callGuardian(context, widget.memberId),
        ),
      ],
    );
  }

  Widget _rightsCard(LoanProduct p) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: p.name, onBack: () => _go(_LoanStep.repayment), onClose: _close),
        _DisclosureHeader(stepText: '3 / 5', cardTitle: '연체 불이익과 취소 권리'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: c.redSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.red.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FbIcons.alert, size: 20, color: c.redStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '연체 불이익 (연 ${p.delinquencyRate.toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.redStrong),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '매달 내는 날짜에 돈을 내지 못하면 연체 이자가 연 ${p.delinquencyRate.toStringAsFixed(1)}%로 올라가고 신용점수가 떨어질 수 있어요.',
                style: TextStyle(fontSize: 13.8, height: 1.55, fontWeight: FontWeight.w700, color: c.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: c.blueSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(FbIcons.shield, size: 20, color: c.blueStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '청약철회권 (${p.withdrawalRightDays}일 안에 취소 가능)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.blueStrong),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '대출을 받은 뒤 마음이 바뀌면 ${p.withdrawalRightDays}일 안에 원금과 그날까지의 이자만 돌려주고 취소할 수 있어요.',
                style: TextStyle(fontSize: 13.8, height: 1.55, fontWeight: FontWeight.w700, color: c.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _TermGlossaryRow(
          terms: [
            ('청약철회권', '대출 계약을 맺은 뒤 14일 안에 불이익 없이 계약을 취소할 수 있는 권리예요.'),
            ('연체 이자', '내야 할 날짜를 넘겼을 때 추가로 내는 더 높은 이자예요.'),
          ],
        ),
        const SizedBox(height: 14),
        _ReadAdvanceControls(
          canAdvance: _canAdvance,
          delaySeconds: widget.cardReadDelay.inSeconds,
          nextLabel: '다음',
          onNext: () => _go(_LoanStep.amountQuote),
          onAskGuardian: () => _callGuardian(context, widget.memberId),
        ),
      ],
    );
  }

  Widget _amountQuoteCard(LoanProduct p, LoanQuote quote) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '한도 조회 · 금액 계산', onBack: () => _go(_LoanStep.rights), onClose: _close),
        _DisclosureHeader(stepText: '4 / 5', cardTitle: '빌릴 금액과 상환 계산'),
        const SizedBox(height: 10),
        FbButton.gray(
          _limitResult == null ? '내 한도 조회하기' : '조회된 최대 한도: ${won(_limitResult!.maxLimit)}',
          busy: _busy,
          onPressed: _busy ? null : () => _checkLimit(),
        ),
        const SizedBox(height: 12),
        Text('빌릴 금액을 고르면 월 납입액과 총 이자가 바로 계산돼요.', style: FbText.hint(c)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amt in const [1000000, 3000000, 5000000, 10000000, 20000000])
              ChoiceChip(
                label: Text('${amt ~/ 10000}만원'),
                selected: _selectedAmount == amt,
                onSelected: (_) => _selectAmount(amt, p),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _customAmountCtrl,
          focusNode: _amountFocus,
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsFormatter()],
          decoration: InputDecoration(
            labelText: '직접 입력 (원)',
            hintText: '예: 5,000,000',
            suffixText: '원',
            errorText: _amountError,
          ),
          onChanged: (v) {
            if (_amountError != null) setState(() => _amountError = null);
            final parsed = int.tryParse(digitsOnly(v));
            if (parsed != null && parsed >= p.minAmount && parsed <= p.maxLimit) {
              _selectAmount(parsed, p);
            }
          },
        ),
        const SizedBox(height: 12),
        _InfoCardBox(
          children: [
            _KeyValueLine('선택한 대출 금액', won(quote.amount)),
            const SizedBox(height: 8),
            _KeyValueLine('예상 월 납입액 (${quote.termMonths}개월)', won(quote.monthlyPayment), highlight: true),
            const SizedBox(height: 8),
            _KeyValueLine('예상 총 이자', won(quote.totalInterest)),
            const SizedBox(height: 8),
            _KeyValueLine('총 상환 금액', won(quote.totalRepayment)),
          ],
        ),
        const SizedBox(height: 14),
        FbButton('이 금액으로 신청 계속하기', busy: _busy, onPressed: _busy ? null : () => _proceedToApplyComprehension(p)),
        const SizedBox(height: 8),
        _AskGuardianFooterButton(onPressed: () => _callGuardian(context, widget.memberId)),
      ],
    );
  }

  Widget _comprehensionCard(LoanProduct p) => _ComprehensionCheckPanel(
    stepText: '5 / 5',
    question: '대출을 받은 뒤 마음을 바꾸면 언제까지 취소할 수 있고, 연체하면 어떻게 되나요?',
    options: [
      '계약 뒤 ${p.withdrawalRightDays}일 안에 취소할 수 있고, 연체하면 연 ${p.delinquencyRate.toStringAsFixed(1)}%의 불이익이 생겨요',
      '한 번 받으면 다음 날에도 취소할 수 없어요',
      '날짜가 지나도 추가 이자는 붙지 않아요',
    ],
    selectedIndex: _comprehensionIndex,
    hintText: _comprehensionHint,
    confirmLabel: '대출 신청하기',
    busy: _busy,
    onBack: () => _go(_LoanStep.amountQuote),
    onClose: _close,
    onAskGuardian: () => _callGuardian(context, widget.memberId),
    onSelectOption: (idx) => setState(() {
      _comprehensionIndex = idx;
      _comprehensionHint = idx == 0 ? null : '앞에서 본 연체 이자와 14일 안에 취소할 수 있는 권리를 다시 확인해 주세요.';
    }),
    onSubmit: () {
      if (_comprehensionIndex != 0) {
        setState(() => _comprehensionHint = '정확한 내용을 선택해 주세요.');
        return;
      }
      _submitApply();
    },
  );

  Widget _cautionCard() {
    final c = context.fb;
    final exp = _cautionRisk?.easyExplanation ?? '주의 모드 중 대출을 진행하려고 해요. 다시 한 번 확인해 주세요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '한 번 더 확인해 주세요', onClose: _close),
        RiskBox(title: '주의가 필요해요', danger: true, items: [exp]),
        const SizedBox(height: 12),
        Text('누군가 전화나 문자로 대출을 받으라고 시킨 것이 아닌지 꼭 확인하세요.', style: TextStyle(color: c.redStrong, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        FbButtonRow(
          children: [
            FbButton.gray('취소', onPressed: _close),
            FbButton(
              '확인했어요, 계속 진행',
              busy: _busy,
              onPressed: () {
                if (_activeActionKind == 'loan_limit') {
                  _checkLimit(answer: _questionAnswer, confirmed: true);
                } else {
                  _submitApply(answer: _questionAnswer, confirmed: true);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        FraudHelpButton(onCallGuardian: () => _callGuardian(context, widget.memberId)),
      ],
    );
  }

  Widget _dangerLimitCard(FamilySnapshot data) {
    final exp = _cautionRisk?.easyExplanation ?? '주의 모드 중 대출 한도 조회에서 사기 위험이 감지되었어요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '위험 경고', onClose: _close),
        CenterBlock(
          icon: const ResultIcon(FbIcons.alert, tone: ResultTone.red),
          title: '대출 한도 조회가 위험해 보여요',
          body: '$exp\n보호자 ${data.guardian.name}님께 바로 알림을 보냈어요.',
        ),
        const SizedBox(height: 14),
        FbButton(
          '보호자에게 전화',
          icon: FbIcons.phone,
          onPressed: () => _callGuardian(context, widget.memberId),
        ),
        const SizedBox(height: 8),
        FraudHelpButton(onCallGuardian: () => _callGuardian(context, widget.memberId), guardianName: data.guardian.name),
        const SizedBox(height: 8),
        FbButton.gray('닫기', onPressed: _close),
      ],
    );
  }

  Widget _doneCard(LoanProduct p, LoanQuote quote) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetHead(onClose: _close),
      CenterBlock(
        icon: const ResultIcon(FbIcons.check),
        title: '대출 신청을 마쳤어요',
        body: '${p.name} ${won(quote.amount)}이 입출금 통장으로 들어왔어요.\n예상 월 납입액 ${won(quote.monthlyPayment)} (${quote.termMonths}개월)',
      ),
      const SizedBox(height: 20),
      FbButton('확인', onPressed: _close),
    ],
  );
}

// ============================================================================
// 공통 보조 위젯 (설명의무 헤더 · 3초 읽기 대기 · 이해 확인 · 보류 대기 재사용)
// ============================================================================

class _DisclosureHeader extends StatelessWidget {
  final String stepText;
  final String cardTitle;

  const _DisclosureHeader({required this.stepText, required this.cardTitle});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '꼭 알아야 할 내용',
                style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w800, color: c.blueStrong),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(8)),
              child: Text(stepText, style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w800, color: c.ink)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text('금융소비자보호법 제19조의 중요한 사항입니다', style: FbText.small(c)),
        const SizedBox(height: 8),
        Text(cardTitle, style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, color: c.ink)),
      ],
    );
  }
}

class _InfoCardBox extends StatelessWidget {
  final List<Widget> children;
  const _InfoCardBox({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(14),
        border: c.cardBorder != null ? Border.all(color: c.cardBorder!) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool danger;

  const _KeyValueLine(this.label, this.value, {this.highlight = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final valColor = danger ? c.redStrong : (highlight ? c.blueStrong : c.ink);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: c.muted, fontWeight: FontWeight.w600))),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: highlight || danger ? 15.5 : 14.2, fontWeight: FontWeight.w800, color: valColor),
          ),
        ),
      ],
    );
  }
}

class _TermGlossaryRow extends StatelessWidget {
  final List<(String term, String meaning)> terms;
  const _TermGlossaryRow({required this.terms});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (term, meaning) in terms)
          ActionChip(
            avatar: Icon(FbIcons.sparkle, size: 15, color: c.blue),
            label: Text('$term 뜻 보기', style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w700, color: c.blueStrong)),
            backgroundColor: c.blueSoft,
            side: BorderSide.none,
            onPressed: () => _showGlossaryDialog(context, term, meaning),
          ),
      ],
    );
  }
}

class _AskGuardianFooterButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AskGuardianFooterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      button: true,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(FbIcons.phone, size: 18, color: c.blue),
        label: Text('보호자에게 물어보기', style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(57, 57),
          side: BorderSide(color: c.cardBorder ?? c.faint),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _ReadAdvanceControls extends StatelessWidget {
  final bool canAdvance;
  final int delaySeconds;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback onAskGuardian;

  const _ReadAdvanceControls({
    required this.canAdvance,
    required this.delaySeconds,
    required this.nextLabel,
    required this.onNext,
    required this.onAskGuardian,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canAdvance)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '내용을 천천히 읽을 수 있도록 $delaySeconds초 뒤에 다음 버튼이 켜져요.',
              textAlign: TextAlign.center,
              style: FbText.small(c),
            ),
          ),
        FbButton(nextLabel, onPressed: canAdvance ? onNext : null),
        const SizedBox(height: 8),
        _AskGuardianFooterButton(onPressed: onAskGuardian),
      ],
    );
  }
}

class _ComprehensionCheckPanel extends StatelessWidget {
  final String stepText;
  final String question;
  final List<String> options;
  final int? selectedIndex;
  final String? hintText;
  final String confirmLabel;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback onAskGuardian;
  final ValueChanged<int> onSelectOption;
  final VoidCallback onSubmit;

  const _ComprehensionCheckPanel({
    required this.stepText,
    required this.question,
    required this.options,
    required this.selectedIndex,
    required this.hintText,
    required this.confirmLabel,
    required this.busy,
    required this.onBack,
    required this.onClose,
    required this.onAskGuardian,
    required this.onSelectOption,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '이해 확인', onBack: onBack, onClose: onClose),
        _DisclosureHeader(stepText: stepText, cardTitle: '중요한 내용을 확인해 주세요'),
        const SizedBox(height: 10),
        Text(question, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.45, color: c.ink)),
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Semantics(
            key: ValueKey('comprehension-option-$i'),
            button: true,
            selected: selectedIndex == i,
            child: Material(
              color: selectedIndex == i ? c.blueSoft : c.soft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy ? null : () => onSelectOption(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedIndex == i ? c.blue : (c.cardBorder ?? c.line),
                      width: selectedIndex == i ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedIndex == i ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: selectedIndex == i ? c.blue : c.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          options[i],
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.4, color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(12)),
          child: Text(
            '이해하지 못한 채 확인하면 나중에 분쟁에서 불리할 수 있어요',
            style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.redStrong),
          ),
        ),
        if (hintText != null) ...[
          const SizedBox(height: 8),
          Text(hintText!, style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.redStrong)),
        ],
        const SizedBox(height: 14),
        FbButton(confirmLabel, busy: busy, onPressed: busy || selectedIndex == null ? null : onSubmit),
        const SizedBox(height: 8),
        _AskGuardianFooterButton(onPressed: onAskGuardian),
      ],
    );
  }
}

class _HoldWaitingPanel extends StatefulWidget {
  final Member member;
  final FamilySnapshot data;
  final String? requestId;
  final String doneTitle;
  final String doneBody;
  final VoidCallback onClose;

  const _HoldWaitingPanel({
    required this.member,
    required this.data,
    required this.requestId,
    required this.doneTitle,
    required this.doneBody,
    required this.onClose,
  });

  @override
  State<_HoldWaitingPanel> createState() => _HoldWaitingPanelState();
}

class _HoldWaitingPanelState extends State<_HoldWaitingPanel> {
  bool _busy = false;

  Future<void> _cancel(String reqId) async {
    setState(() => _busy = true);
    final shell = context.read<ShellCubit>();
    try {
      await context.read<FamilyCubit>().cancelRequest(reqId, widget.member.id);
      shell.say('보류 중인 거래를 취소했어요');
    } on ApiException catch (e) {
      shell.say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reconfirm(String reqId, {required bool confirm}) async {
    setState(() => _busy = true);
    final shell = context.read<ShellCubit>();
    try {
      final r = await context.read<FamilyCubit>().reconfirmHold(reqId, widget.member.id, confirm: confirm);
      if (r.status == 'failed') {
        shell.say('처리하지 못했어요 · ${r.message}', vibrate: const [80, 40, 80]);
      } else {
        shell.say(confirm ? '재확인 후 거래를 진행했어요' : '거래를 그만두었어요');
      }
    } on ApiException catch (e) {
      shell.say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final req = widget.requestId == null ? null : widget.data.request(widget.requestId!);
    if (req != null && !req.isActive) {
      final ok = req.status == 'approved';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHead(onClose: widget.onClose),
          CenterBlock(
            icon: ResultIcon(ok ? FbIcons.check : FbIcons.close, tone: ok ? ResultTone.blue : ResultTone.red),
            title: ok ? widget.doneTitle : '요청이 취소되었어요',
            body: ok ? widget.doneBody : (req.failReason ?? '거래가 실행되지 않았어요.'),
          ),
          const SizedBox(height: 18),
          FbButton('확인', onPressed: widget.onClose),
        ],
      );
    }
    if (req != null && req.isReconfirm && !widget.member.isChild) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHead(onClose: widget.onClose),
          CenterBlock(
            icon: const ResultIcon(FbIcons.alert, tone: ResultTone.red),
            title: '본인 재확인 대기',
            body: '${req.title} · ${won(req.amount)}\n${req.easyExplanation}',
          ),
          const SizedBox(height: 18),
          FbButtonRow(
            children: [
              FbButton.gray('그만두기', busy: _busy, onPressed: () => _reconfirm(req.id, confirm: false)),
              FbButton.gray('그래도 진행', busy: _busy, onPressed: () => _reconfirm(req.id, confirm: true)),
            ],
          ),
          const SizedBox(height: 8),
          FbButton.gray(
            '보호자에게 전화',
            icon: FbIcons.phone,
            onPressed: () => _callGuardian(context, widget.member.id),
          ),
          const SizedBox(height: 8),
          FraudHelpButton(
            onCallGuardian: () => _callGuardian(context, widget.member.id),
            guardianName: widget.data.guardian.name,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(onClose: widget.onClose),
        CenterBlock(
          icon: const ResultIcon(FbIcons.clock, tone: ResultTone.soft, ringing: true),
          title: '거래를 30분 동안 보류했어요',
          body: '${req?.easyExplanation ?? ''}\n${widget.data.guardian.name}님께 알림을 보냈어요.',
        ),
        if (req?.expiresAt != null)
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('보류 남은 시간 · ', style: FbText.hint(c)),
              CountdownText(
                until: req!.expiresAt!,
                now: context.read<FamilyCubit>().now,
                format: formatMinSec,
                style: FbText.hint(c).copyWith(fontWeight: FontWeight.w800, color: c.ink2),
              ),
            ],
          ),
        const SizedBox(height: 20),
        if (req != null) ...[
          FbButton.gray('취소', busy: _busy, onPressed: () => _cancel(req.id)),
          const SizedBox(height: 8),
        ],
        FbButton(
          '보호자 화면에서 확인하기 (시연)',
          onPressed: () => context.read<ShellCubit>().goto(Persona.guardian, AppTab.home),
        ),
        const SizedBox(height: 8),
        FraudHelpButton(
          onCallGuardian: () => _callGuardian(context, widget.member.id),
          guardianName: widget.data.guardian.name,
        ),
        const SizedBox(height: 8),
        FbButton.gray('닫기', onPressed: widget.onClose),
      ],
    );
  }
}
