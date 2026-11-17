import 'dart:math' as math;

import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'sms_format.dart';

/// iOS 메시지 스타일의 받은 문자 말풍선, iMessage 모양 링크·번호 미리보기 줄, 위험·주의 경고 띠 (기획서 5.2, 7.3).
/// 정상 문자는 말풍선만 표시하고, 링크·번호가 있는 문자는 57dp 이상 미리보기 줄을 붙이며,
/// 위험·주의 문자는 그 아래 알림 카드로 쉬운 설명과 [사기 신고·도움]을 붙입니다.
class SmsBubble extends StatefulWidget {
  final SmsMessage message;
  final DateTime? now;
  final ValueChanged<String> onTapLink;
  final ValueChanged<String>? onTapPhone;
  final VoidCallback? onCallGuardian;

  const SmsBubble({
    super.key,
    required this.message,
    this.now,
    required this.onTapLink,
    this.onTapPhone,
    this.onCallGuardian,
  });

  @override
  State<SmsBubble> createState() => _SmsBubbleState();
}

class _SmsBubbleState extends State<SmsBubble> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<SmsBodySegment> _segments;

  @override
  void initState() {
    super.initState();
    _rebuildSegments();
  }

  @override
  void didUpdateWidget(SmsBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.body != widget.message.body ||
        oldWidget.message.links != widget.message.links ||
        oldWidget.message.phones != widget.message.phones ||
        (oldWidget.onTapPhone == null) != (widget.onTapPhone == null)) {
      _rebuildSegments();
    }
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _rebuildSegments() {
    _disposeRecognizers();
    _segments = parseSmsBodySegments(
      widget.message.body,
      links: widget.message.links,
      phones: widget.message.phones,
    );
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = context.fb.cardBorder != null;
    final palette = SmsPalette.of(highContrast: highContrast);

    _disposeRecognizers();
    const baseStyle = TextStyle(
      fontSize: 15,
      height: 1.2,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w400,
    );
    final normalStyle = baseStyle.copyWith(color: palette.ink);
    final linkStyle = baseStyle.copyWith(
      color: palette.blue,
      decoration: TextDecoration.underline,
      decorationColor: palette.blue,
    );

    final spans = <InlineSpan>[];
    final previewLinks = <String>[];
    final previewPhones = <String>[];

    for (final seg in _segments) {
      if (seg.kind == SmsSegmentKind.link) {
        final tap = TapGestureRecognizer()..onTap = () => widget.onTapLink(seg.text);
        _recognizers.add(tap);
        spans.add(
          TextSpan(
            text: seg.text,
            style: linkStyle,
            recognizer: tap,
            semanticsLabel: '문자 속 인터넷 주소 ${seg.text}',
          ),
        );
        if (!previewLinks.contains(seg.text)) {
          previewLinks.add(seg.text);
        }
      } else if (seg.kind == SmsSegmentKind.phone && widget.onTapPhone != null) {
        final tap = TapGestureRecognizer()..onTap = () => widget.onTapPhone!(seg.text);
        _recognizers.add(tap);
        spans.add(
          TextSpan(
            text: seg.text,
            style: linkStyle,
            recognizer: tap,
            semanticsLabel: '${seg.text} 번호로 통화',
          ),
        );
        if (!previewPhones.contains(seg.text)) {
          previewPhones.add(seg.text);
        }
      } else {
        spans.add(TextSpan(text: seg.text, style: normalStyle));
      }
    }

    final screenWidth = MediaQuery.sizeOf(context).width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAvailable = constraints.hasBoundedWidth
            ? math.max(0.0, constraints.maxWidth - _ReceivedBubblePainter.tailWidth)
            : screenWidth * 0.72;
        final bubbleBodyMaxWidth = math.min(math.min(263.0, screenWidth * 0.72), maxAvailable);
        final bubbleMaxWidth = bubbleBodyMaxWidth + _ReceivedBubblePainter.tailWidth;

        final bubble = Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
            child: CustomPaint(
              painter: _ReceivedBubblePainter(
                fillColor: palette.receivedBubble,
                borderColor: palette.bubbleBorder,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _ReceivedBubblePainter.tailWidth + 13,
                  9,
                  13,
                  9 + _ReceivedBubblePainter.tailDip,
                ),
                child: Text.rich(
                  TextSpan(children: spans),
                  key: ValueKey('sms-bubble-text-${widget.message.id}'),
                  softWrap: true,
                ),
              ),
            ),
          ),
        );

        final hasPreviews = previewLinks.isNotEmpty || previewPhones.isNotEmpty;
        if (!hasPreviews && !widget.message.hasWarning) {
          return bubble;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bubble,
            for (final url in previewLinks) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: _ReceivedBubblePainter.tailWidth),
                  child: SizedBox(
                    width: bubbleBodyMaxWidth,
                    child: _SmsActionPreviewRow(
                      key: ValueKey('sms-link-preview-$url'),
                      icon: Icons.link_rounded,
                      title: extractSmsLinkHost(url),
                      subtitle: '링크',
                      semanticLabel: '문자 속 인터넷 주소 $url',
                      palette: palette,
                      onTap: () => widget.onTapLink(url),
                    ),
                  ),
                ),
              ),
            ],
            for (final phone in previewPhones) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: _ReceivedBubblePainter.tailWidth),
                  child: SizedBox(
                    width: bubbleBodyMaxWidth,
                    child: _SmsActionPreviewRow(
                      key: ValueKey('sms-phone-preview-$phone'),
                      icon: Icons.phone_outlined,
                      title: phone,
                      subtitle: '전화 걸기',
                      semanticLabel: '$phone 번호로 통화',
                      palette: palette,
                      onTap: () => widget.onTapPhone!(phone),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.message.hasWarning) ...[
              const SizedBox(height: 8),
              _SmsWarningCard(
                message: widget.message,
                palette: palette,
                onCallGuardian: widget.onCallGuardian,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SmsActionPreviewRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String semanticLabel;
  final SmsPalette palette;
  final VoidCallback onTap;

  const _SmsActionPreviewRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = palette.highContrast
        ? const Color(0xFF1B1F24)
        : const Color(0x18000000);
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: palette.previewCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor,
            width: palette.highContrast ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: const Color(0x14000000),
          onTap: onTap,
          child: ConstrainedBox(
            // 58dp ensures the rounded physical height stays >= 57dp at 2.625x density.
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: palette.highContrast
                          ? Border.all(color: const Color(0xFF1B1F24), width: 1)
                          : null,
                    ),
                    child: Icon(icon, size: 20, color: palette.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.2,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: palette.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: palette.ink2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceivedBubblePainter extends CustomPainter {
  static const double tailWidth = 6.0;
  static const double tailDip = 1.5;

  final Color fillColor;
  final Color? borderColor;

  const _ReceivedBubblePainter({required this.fillColor, this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= tailWidth || h <= tailDip) return;

    const left = tailWidth;
    final bottom = h - tailDip;
    final r = math.min(20.0, math.min((w - left) / 2, bottom / 2));
    final tailJoinX = math.min(left + 12.0, w - r);
    final tailStartY = math.max(r, bottom - 11.0);

    final path = Path()
      ..moveTo(left + r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, bottom - r)
      ..arcToPoint(Offset(w - r, bottom), radius: Radius.circular(r))
      ..lineTo(tailJoinX, bottom)
      ..cubicTo(left + 5.0, bottom, 3.0, h, 0, h)
      ..cubicTo(3.0, h - 1.0, left, bottom - 3.5, left, tailStartY)
      ..lineTo(left, r)
      ..arcToPoint(Offset(left + r, 0), radius: Radius.circular(r))
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (borderColor != null) {
      final strokePaint = Paint()
        ..color = borderColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_ReceivedBubblePainter oldDelegate) =>
      oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor;
}

class _SmsWarningCard extends StatelessWidget {
  final SmsMessage message;
  final SmsPalette palette;
  final VoidCallback? onCallGuardian;

  const _SmsWarningCard({
    required this.message,
    required this.palette,
    this.onCallGuardian,
  });

  @override
  Widget build(BuildContext context) {
    final danger = message.isDanger;
    final accent = danger ? palette.red : palette.amber;
    final title = danger ? '사기 의심 문자' : '주의가 필요한 문자';

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: palette.highContrast ? accent : accent.withValues(alpha: 0.42),
            width: palette.highContrast ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  label: danger ? '위험 경고' : '주의',
                  child: Icon(Icons.warning_amber_rounded, size: 20, color: accent),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: accent),
                  ),
                ),
              ],
            ),
            if (message.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.explanation,
                style: TextStyle(
                  fontSize: 13.6,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: palette.ink,
                ),
              ),
            ],
            if (message.reasons.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final reason in message.reasons)
                BulletText(
                  reason,
                  style: TextStyle(fontSize: 12.8, height: 1.5, color: palette.ink2),
                ),
            ],
            const SizedBox(height: 12),
            FraudHelpButton(onCallGuardian: onCallGuardian),
          ],
        ),
      ),
    );
  }
}
