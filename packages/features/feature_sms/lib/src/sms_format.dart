import 'package:core_family/core_family.dart';
import 'package:flutter/material.dart';

/// iOS 메시지 앱을 흉내 낸 문자 화면용 색 팔레트 (라이트 / 고대비).
final class SmsPalette {
  final bool highContrast;
  final Color ink;
  final Color ink2;
  final Color blue;
  final Color red;
  final Color redSoft;
  final Color redText;
  final Color amber;
  final Color amberSoft;
  final Color divider;
  final Color avatarBg;
  final Color avatarFg;
  final Color threadBg;
  final Color receivedBubble;
  final Color previewCard;
  final Color? bubbleBorder;
  final Color navBg;
  final Color navBorder;

  const SmsPalette._({
    required this.highContrast,
    required this.ink,
    required this.ink2,
    required this.blue,
    required this.red,
    required this.redSoft,
    required this.redText,
    required this.amber,
    required this.amberSoft,
    required this.divider,
    required this.avatarBg,
    required this.avatarFg,
    required this.threadBg,
    required this.receivedBubble,
    required this.previewCard,
    required this.bubbleBorder,
    required this.navBg,
    required this.navBorder,
  });

  factory SmsPalette.of({required bool highContrast}) => SmsPalette._(
    highContrast: highContrast,
    ink: Colors.black,
    ink2: highContrast ? const Color(0xFF1C1C1E) : const Color(0xFF6E6E73),
    blue: highContrast ? const Color(0xFF0051D5) : const Color(0xFF007AFF),
    red: highContrast ? const Color(0xFFB31412) : const Color(0xFFD71913),
    redSoft: highContrast ? const Color(0xFFFFD6DA) : const Color(0xFFFFECEE),
    redText: highContrast ? const Color(0xFF9E0B22) : const Color(0xFFC61C2E),
    amber: highContrast ? const Color(0xFF7A3200) : const Color(0xFFB24A00),
    amberSoft: highContrast ? const Color(0xFFFFE5C2) : const Color(0xFFFFF3E0),
    divider: highContrast ? const Color(0xFF8A929C) : const Color(0xFFE5E5EA),
    avatarBg: highContrast ? const Color(0xFFDADCE0) : const Color(0xFFE5E5EA),
    avatarFg: highContrast ? Colors.black : const Color(0xFF3C3C43),
    threadBg: highContrast ? Colors.white : const Color(0xFFF5F6F5),
    receivedBubble: highContrast ? const Color(0xFFEAECEF) : const Color(0xFFE2E2E3),
    previewCard: highContrast ? const Color(0xFFF2F4F7) : const Color(0xFFE9E9EB),
    bubbleBorder: highContrast ? const Color(0xFF1B1F24) : null,
    navBg: Colors.white.withValues(alpha: highContrast ? 0.98 : 0.90),
    navBorder: highContrast ? const Color(0xFF1B1F24) : const Color(0x333C3C43),
  );
}

/// 대화 목록을 마지막 문자 시각 기준 최신순으로 정렬합니다.
List<SmsConversation> sortSmsConversationsNewestFirst(List<SmsConversation> conversations) {
  final indexed = <(int, SmsConversation)>[
    for (var i = 0; i < conversations.length; i++) (i, conversations[i]),
  ];
  indexed.sort((a, b) {
    final byTime = b.$2.lastMessage.at.compareTo(a.$2.lastMessage.at);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final (_, c) in indexed) c];
}

/// 한 대화 안의 메시지를 오래된 순(시간순)으로 정렬합니다.
List<SmsMessage> sortSmsMessagesChronological(List<SmsMessage> messages) {
  final indexed = <(int, SmsMessage)>[
    for (var i = 0; i < messages.length; i++) (i, messages[i]),
  ];
  indexed.sort((a, b) {
    final byTime = a.$2.at.compareTo(b.$2.at);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final (_, m) in indexed) m];
}

bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatKoreanTime(DateTime local) {
  final period = local.hour < 12 ? '오전' : '오후';
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$period $hour12:$minute';
}

String _weekdayKorean(int weekday) => const ['월', '화', '수', '목', '금', '토', '일'][weekday - 1];

/// 대화 목록 오른쪽 위 시각 표시: 오늘이면 "오후 3:12", 어제면 "어제", 그 전이면 "11월 16일".
String formatSmsListWhen(DateTime at, DateTime now) {
  final a = at.toLocal();
  final n = now.toLocal();
  if (_isSameCalendarDay(a, n)) return _formatKoreanTime(a);
  final yesterday = DateTime(n.year, n.month, n.day - 1);
  if (_isSameCalendarDay(a, yesterday)) return '어제';
  return '${a.month}월 ${a.day}일';
}

/// 대화 화면 말풍선 묶음 위 가운데 시각 표시:
/// 오늘이면 "오늘 오후 3:12", 날짜가 다르면 "11월 16일 (일) 오후 3:12".
String formatSmsThreadWhen(DateTime at, DateTime now) {
  final a = at.toLocal();
  final n = now.toLocal();
  if (_isSameCalendarDay(a, n)) return '오늘 ${_formatKoreanTime(a)}';
  return '${a.month}월 ${a.day}일 (${_weekdayKorean(a.weekday)}) ${_formatKoreanTime(a)}';
}

/// 대화 화면에서 첫 메시지이거나 날짜가 바뀌거나 이전 메시지와 15분 이상 차이나면 시각 줄을 띄웁니다.
bool shouldShowThreadTimestamp(List<SmsMessage> messagesChronological, int index) {
  if (index == 0) return true;
  final prev = messagesChronological[index - 1].at.toLocal();
  final curr = messagesChronological[index].at.toLocal();
  if (!_isSameCalendarDay(prev, curr)) return true;
  return curr.difference(prev).abs() >= const Duration(minutes: 15);
}

enum SmsSegmentKind { text, link, phone }

class SmsBodySegment {
  final SmsSegmentKind kind;
  final String text;

  const SmsBodySegment(this.kind, this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsBodySegment && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'SmsBodySegment($kind, "$text")';
}

/// 문자 본문을 일반 글자·링크·전화번호 조각으로 나눕니다.
/// 겹칠 때는 링크를 우선하고 더 긴 토큰을 먼저 일치시킵니다.
/// 본문에 없는 [links]는 안전하게 눌러 차단 화면을 열 수 있도록 끝에 이어 붙입니다.
List<SmsBodySegment> parseSmsBodySegments(
  String body, {
  List<String> links = const [],
  List<String> phones = const [],
  bool includeFallbackLinks = true,
}) {
  final cleanLinks = links.where((e) => e.isNotEmpty).toSet().toList();
  final cleanPhones = phones.where((e) => e.isNotEmpty).toSet().toList();
  final tokens = <({SmsSegmentKind kind, String text})>[
    for (final l in cleanLinks) (kind: SmsSegmentKind.link, text: l),
    for (final p in cleanPhones) (kind: SmsSegmentKind.phone, text: p),
  ];
  tokens.sort((a, b) {
    final lenCmp = b.text.length.compareTo(a.text.length);
    if (lenCmp != 0) return lenCmp;
    return a.kind == SmsSegmentKind.link ? -1 : (b.kind == SmsSegmentKind.link ? 1 : 0);
  });

  final segments = <SmsBodySegment>[];
  final matchedLinks = <String>{};
  var pos = 0;

  while (pos < body.length) {
    var bestIndex = -1;
    ({SmsSegmentKind kind, String text})? bestToken;

    for (final token in tokens) {
      final idx = body.indexOf(token.text, pos);
      if (idx == -1) continue;
      if (bestIndex == -1 || idx < bestIndex) {
        bestIndex = idx;
        bestToken = token;
      } else if (idx == bestIndex && bestToken != null) {
        final preferLink = token.kind == SmsSegmentKind.link && bestToken.kind != SmsSegmentKind.link;
        final sameKindLonger =
            token.kind == bestToken.kind && token.text.length > bestToken.text.length;
        if (preferLink || sameKindLonger) {
          bestToken = token;
        }
      }
    }

    if (bestToken == null) {
      segments.add(SmsBodySegment(SmsSegmentKind.text, body.substring(pos)));
      break;
    }
    if (bestIndex > pos) {
      segments.add(SmsBodySegment(SmsSegmentKind.text, body.substring(pos, bestIndex)));
    }
    segments.add(SmsBodySegment(bestToken.kind, bestToken.text));
    if (bestToken.kind == SmsSegmentKind.link) {
      matchedLinks.add(bestToken.text);
    }
    pos = bestIndex + bestToken.text.length;
  }

  if (includeFallbackLinks) {
    for (final link in cleanLinks) {
      if (!matchedLinks.contains(link)) {
        if (segments.isNotEmpty) {
          segments.add(const SmsBodySegment(SmsSegmentKind.text, '\n'));
        }
        segments.add(SmsBodySegment(SmsSegmentKind.link, link));
      }
    }
  }

  return segments;
}

/// 링크 미리보기 줄에 표시할 호스트를 뽑습니다(예: `http://fss-verify.invalid/case/8821` → `fss-verify.invalid`).
String extractSmsLinkHost(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.host.isNotEmpty) return parsed.host;
  if (!trimmed.contains('://')) {
    final withScheme = Uri.tryParse('https://$trimmed');
    if (withScheme != null && withScheme.host.isNotEmpty) return withScheme.host;
  }
  return trimmed;
}
