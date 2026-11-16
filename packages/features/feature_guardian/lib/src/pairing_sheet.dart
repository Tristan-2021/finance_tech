import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR 스캐너 위젯 빌더 (테스트에서는 카메라 없이 가짜 스캐너를 주입할 수 있습니다).
typedef PairingQrScannerBuilder = Widget Function(BuildContext context, ValueChanged<String> onCodeDetected);

/// 보호자 연결 (QR 코드 + 직접 코드 입력 + 어르신 동의) 5단계 시트를 엽니다 (기획서 5.8, 7.1 Ⅱ-④).
Future<void> openPairingSheet(
  BuildContext context, {
  String initialMemberId = 'senior',
  int initialStep = 0,
  PairingQrScannerBuilder? qrScannerBuilder,
}) => showFbSheet<void>(
  context,
  builder: (_) => PairingSheet(
    initialMemberId: initialMemberId,
    initialStep: initialStep,
    qrScannerBuilder: qrScannerBuilder,
  ),
);

enum _PairingStep { overview, guardianQr, seniorScan, consent, done }

class PairingSheet extends StatefulWidget {
  final String initialMemberId;
  final int initialStep;
  final PairingQrScannerBuilder? qrScannerBuilder;

  const PairingSheet({
    super.key,
    this.initialMemberId = 'senior',
    this.initialStep = 0,
    this.qrScannerBuilder,
  });

  @override
  State<PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends State<PairingSheet> {
  late String _memberId;
  late _PairingStep _step;
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  PairingCodeResult? _issued;
  PairingConnectResult? _connected;
  bool _issuing = false;
  bool _connecting = false;
  bool _scannerOpen = false;
  String? _issueError;
  String? _codeError;
  String? _connectError;
  int _issueSeq = 0;

  @override
  void initState() {
    super.initState();
    _memberId = widget.initialMemberId;
    _step = _PairingStep.values[widget.initialStep.clamp(0, _PairingStep.values.length - 1)];
    if (_step == _PairingStep.guardianQr) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _issueCode();
      });
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _stepText => switch (_step) {
    _PairingStep.overview => '1 / 5',
    _PairingStep.guardianQr => '2 / 5',
    _PairingStep.seniorScan => '3 / 5',
    _PairingStep.consent => '4 / 5',
    _PairingStep.done => '5 / 5',
  };

  void _go(_PairingStep next) {
    setState(() {
      _step = next;
      _codeError = null;
      _connectError = null;
      if (next != _PairingStep.seniorScan) _scannerOpen = false;
    });
    if (next == _PairingStep.guardianQr && _issued == null && !_issuing) {
      _issueCode();
    }
  }

  void _close() => Navigator.of(context).maybePop();

  Future<void> _issueCode() async {
    final targetMemberId = _memberId;
    final seq = ++_issueSeq;
    setState(() {
      _issuing = true;
      _issueError = null;
    });
    final family = context.read<FamilyCubit>();
    try {
      final res = await family.issuePairingCode(targetMemberId);
      if (!mounted || seq != _issueSeq || res.memberId != _memberId) return;
      setState(() {
        _issued = res;
        _issuing = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _issueSeq || targetMemberId != _memberId) return;
      setState(() {
        _issuing = false;
        _issueError = e.message;
      });
    }
  }

  void _onQrDetected(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return;
    _codeCtrl.text = trimmed;
    setState(() {
      _scannerOpen = false;
      _codeError = null;
      _step = _PairingStep.consent;
    });
  }

  void _goToConsent() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = '연결 코드 6자리를 입력하거나 QR 코드를 찍어 주세요.');
      _codeFocus.requestFocus();
      return;
    }
    _go(_PairingStep.consent);
  }

  Future<void> _submitConsent() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _go(_PairingStep.seniorScan);
      return;
    }
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      final res = await family.connectPairing(_memberId, code, consented: true);
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = res;
        _step = _PairingStep.done;
      });
      shell.say('보호자 연결과 동의를 마쳤어요', toast: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        if (!state.isReady) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final data = state.data;
        final member = data.memberOrNull(_memberId) ?? data.members.first;
        if (member.id != _memberId) _memberId = member.id;
        final now = context.read<FamilyCubit>().now;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              _PairingStep.overview => _overviewCard(data, member, now()),
              _PairingStep.guardianQr => _guardianQrCard(member, now),
              _PairingStep.seniorScan => _seniorScanCard(),
              _PairingStep.consent => _consentCard(data, member),
              _PairingStep.done => _doneCard(data, member, now()),
            },
          ),
        );
      },
    );
  }

  Widget _stepHeader(String title) {
    final c = context.fb;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: c.blueSoft, borderRadius: BorderRadius.circular(99)),
          child: Text(
            _stepText,
            style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w800, color: c.blueStrong),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w800, color: c.ink)),
        ),
      ],
    );
  }

  Widget _overviewCard(FamilySnapshot data, Member member, DateTime current) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '보호자 연결', onClose: _close),
        _stepHeader('연결 방법 안내'),
        const SizedBox(height: 10),
        // 5단계 흐름이므로 시작할 때 전체 단계를 보여 줍니다 (기획서 7.1 Ⅱ-④).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: c.blueSoft, borderRadius: BorderRadius.circular(12)),
          child: Text(
            '전체 5단계: 1. 연결 안내 → 2. 보호자 QR·코드 → 3. 어르신 스캔·입력 → 4. 공유 내용 동의 → 5. 연결 완료',
            style: TextStyle(fontSize: 12.6, height: 1.5, fontWeight: FontWeight.w700, color: c.blueStrong),
          ),
        ),
        const SizedBox(height: 12),
        if (data.members.length > 1) ...[
          Text('연결할 가족', style: FbText.small(c)),
          const SizedBox(height: 6),
          FbSegmented<String>(
            options: [for (final m in data.members) (m.id, m.label)],
            value: member.id,
            onChanged: (id) {
              if (id == _memberId) return;
              setState(() {
                _memberId = id;
                _issued = null;
                _issueError = null;
                _issuing = false;
                _issueSeq += 1;
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.isPaired
                    ? '${data.guardian.name} 보호자님과 연결되어 있어요'
                    : '아직 보호자와 연결되지 않았어요',
                style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w800, color: c.ink),
              ),
              if (member.consentAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '마지막 동의: ${formatWhen(member.consentAt!, current)}',
                  style: FbText.small(c),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '보호자 기기에서 연결 QR을 보여 주고, 어르신 기기에서 QR을 읽거나 연결 코드를 입력한 뒤 동의하면 연결이 완료돼요.',
                style: FbText.small(c).copyWith(color: c.ink2, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FbButton('보호자 QR 코드 만들기', icon: FbIcons.qr, onPressed: () => _go(_PairingStep.guardianQr)),
        const SizedBox(height: 8),
        FbButton.gray('이미 코드가 있어요 (어르신 기기)', onPressed: () => _go(_PairingStep.seniorScan)),
      ],
    );
  }

  Widget _guardianQrCard(Member member, DateTime Function() now) {
    final c = context.fb;
    final issued = _issued;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '보호자 연결', onBack: () => _go(_PairingStep.overview), onClose: _close),
        _stepHeader('보호자 기기: 연결 QR 보여주기'),
        const SizedBox(height: 10),
        Text(
          '${member.label} 기기에서 아래 QR 코드를 찍거나, 카메라가 없으면 숫자 코드 6자리를 그대로 입력하세요.',
          style: FbText.hint(c),
        ),
        const SizedBox(height: 14),
        if (_issuing)
          const SizedBox(height: 190, child: Center(child: CircularProgressIndicator()))
        else if (_issueError != null) ...[
          RiskBox(title: '코드를 만들지 못했어요', danger: true, items: [_issueError!]),
          const SizedBox(height: 12),
          FbButton.gray('다시 시도', onPressed: _issueCode),
        ] else if (issued != null) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.line),
              ),
              child: Semantics(
                label: '보호자 연결 QR 코드 ${issued.code}',
                child: QrImageView(
                  data: issued.qrValue,
                  version: QrVersions.auto,
                  size: 176,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text('연결 코드', style: FbText.small(c)),
                const SizedBox(height: 4),
                SelectableText(
                  issued.code,
                  style: FbText.tabular(TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: 4)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('유효 시간 ', style: FbText.small(c)),
                    CountdownText(
                      until: issued.expiresAt,
                      now: now,
                      format: formatMinSec,
                      style: FbText.small(c).copyWith(fontWeight: FontWeight.w800, color: c.blueStrong),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FbButton.gray('새 코드 발급', icon: FbIcons.reset, onPressed: _issueCode),
        ],
        const SizedBox(height: 10),
        FbButton('어르신 기기에서 입력하기', onPressed: issued == null ? null : () => _go(_PairingStep.seniorScan)),
      ],
    );
  }

  Widget _seniorScanCard() {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '보호자 연결', onBack: () => _go(_PairingStep.overview), onClose: _close),
        _stepHeader('어르신 기기: QR 읽기 또는 코드 입력'),
        const SizedBox(height: 10),
        Text(
          '보호자 기기 화면의 QR 코드를 찍거나, 카메라를 쓸 수 없다면 6자리 연결 코드를 직접 입력해 주세요.',
          style: FbText.hint(c),
        ),
        const SizedBox(height: 12),
        FbButton.gray(
          _scannerOpen ? '카메라 닫기' : '카메라로 QR 찍기',
          icon: FbIcons.qrScanner,
          onPressed: () => setState(() => _scannerOpen = !_scannerOpen),
        ),
        if (_scannerOpen) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: widget.qrScannerBuilder != null
                  ? widget.qrScannerBuilder!(context, _onQrDetected)
                  : MobileScanner(
                      onDetect: (capture) {
                        final raw = capture.barcodes.firstOrNull?.rawValue;
                        if (raw != null && raw.trim().isNotEmpty) {
                          _onQrDetected(raw);
                        }
                      },
                    ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('pairing-code-input'),
          controller: _codeCtrl,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '연결 코드 직접 입력 (6자리)',
            hintText: '예: 482910',
            errorText: _codeError,
          ),
          onChanged: (_) {
            if (_codeError != null) setState(() => _codeError = null);
          },
          onSubmitted: (_) => _goToConsent(),
        ),
        if (_issued != null && _issued!.memberId == _memberId) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FbTextButton(
              '방금 발급한 코드(${_issued!.code}) 채우기',
              onPressed: () {
                _codeCtrl.text = _issued!.code;
                setState(() => _codeError = null);
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        FbButton('다음', onPressed: _goToConsent),
      ],
    );
  }

  Widget _consentCard(FamilySnapshot data, Member member) {
    final c = context.fb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '연결 동의', onBack: () => _go(_PairingStep.seniorScan), onClose: _close),
        _stepHeader('보호자가 보게 되는 내용 확인'),
        const SizedBox(height: 10),
        Text(
          '${member.label}님, ${data.guardian.name} 보호자님과 연결하면 보호자 화면에 아래 내용이 보여요.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.5, color: c.ink),
        ),
        const SizedBox(height: 12),
        const _ConsentItemBox(
          icon: FbIcons.bell,
          title: '위험 알림',
          desc: '사기 의심 문자·통화나 비상 동결(SOS)이 생기면 보호자에게 바로 알려요.',
        ),
        const SizedBox(height: 8),
        const _ConsentItemBox(
          icon: FbIcons.list,
          title: '위험 근거 요약',
          desc: '문자·통화 원문은 저장하거나 보여주지 않고, 왜 위험한지 짧은 요약만 보여줘요.',
        ),
        const SizedBox(height: 8),
        const _ConsentItemBox(
          icon: FbIcons.clock,
          title: '보류 상태',
          desc: '위험한 송금·적금 해지·대출이 잠시 멈췄을 때 보호자가 확인하고 해제·연장할 수 있어요.',
        ),
        if (_connectError != null) ...[
          const SizedBox(height: 12),
          RiskBox(title: '연결하지 못했어요', danger: true, items: [_connectError!]),
          const SizedBox(height: 8),
          FbButton.gray('코드 다시 입력하기', onPressed: () => _go(_PairingStep.seniorScan)),
        ],
        const SizedBox(height: 16),
        FbButton('동의', busy: _connecting, onPressed: _connecting ? null : _submitConsent),
      ],
    );
  }

  Widget _doneCard(FamilySnapshot data, Member member, DateTime current) {
    final c = context.fb;
    final at = _connected?.consentAt ?? member.consentAt ?? current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHead(title: '보호자 연결', onClose: _close),
        _stepHeader('연결 완료'),
        const SizedBox(height: 8),
        CenterBlock(
          icon: const ResultIcon(FbIcons.check),
          title: '보호자와 연결했어요',
          body: '${data.guardian.name} 보호자님이 위험 알림, 근거 요약, 보류 상태를 확인할 수 있어요.\n동의 시각: ${formatWhen(at, current)}',
        ),
        const SizedBox(height: 8),
        Text(
          '연결 안내에 동의한 시각이 서버에 기록되었어요.',
          textAlign: TextAlign.center,
          style: FbText.small(c),
        ),
        const SizedBox(height: 18),
        FbButton('확인', onPressed: _close),
      ],
    );
  }
}

class _ConsentItemBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _ConsentItemBox({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(14),
        border: c.cardBorder != null ? Border.all(color: c.cardBorder!) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TxLogo(icon: icon, blue: true, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.ink)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 13.2, height: 1.45, color: c.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
