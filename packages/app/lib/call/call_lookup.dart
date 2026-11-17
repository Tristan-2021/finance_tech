import 'package:core_family/core_family.dart';

/// 번호 비교를 위해 하이픈과 공백을 뺍니다.
String normalizeCallPhone(String raw) => raw.replaceAll(RegExp(r'[-\s]+'), '');

/// 키패드에 입력한 번호를 한국 전화번호 형식(예: `010-1234-5678`, `02-0000-1332`)으로 다듬습니다.
String formatDialPadNumber(String raw) {
  final clean = normalizeCallPhone(raw);
  if (clean.isEmpty) return '';
  if (clean.contains('#') || !RegExp(r'^[0-9*]+$').hasMatch(clean)) {
    return clean;
  }
  if (clean.startsWith('02') && RegExp(r'^\d+$').hasMatch(clean) && clean.length <= 10) {
    if (clean.length <= 2) return clean;
    if (clean.length <= 6) return '${clean.substring(0, 2)}-${clean.substring(2)}';
    if (clean.length <= 9) {
      return '${clean.substring(0, 2)}-${clean.substring(2, 5)}-${clean.substring(5)}';
    }
    return '${clean.substring(0, 2)}-${clean.substring(2, 6)}-${clean.substring(6)}';
  }
  if (clean.startsWith('0') &&
      !clean.startsWith('02') &&
      clean.length <= 11 &&
      (clean.length < 3 || RegExp(r'^0\d{2}[0-9*]*$').hasMatch(clean))) {
    if (clean.length <= 3) return clean;
    if (clean.length <= 7) return '${clean.substring(0, 3)}-${clean.substring(3)}';
    if (clean.length <= 10) {
      return '${clean.substring(0, 3)}-${clean.substring(3, 6)}-${clean.substring(6)}';
    }
    return '${clean.substring(0, 3)}-${clean.substring(3, 7)}-${clean.substring(7)}';
  }
  if (RegExp(r'^(15|16|18)\d+$').hasMatch(clean) && clean.length <= 8) {
    if (clean.length <= 4) return clean;
    return '${clean.substring(0, 4)}-${clean.substring(4)}';
  }
  return clean;
}

class CallPeerTarget {
  final String peerId;
  final String peerName;
  final String peerPhone;

  const CallPeerTarget({
    required this.peerId,
    required this.peerName,
    required this.peerPhone,
  });
}

/// 서버 상태에 있는 보호자 번호, 문자 발신·본문 번호, 통화 대본 번호로 통화 상대를 찾습니다.
/// 일치하는 번호가 없으면 null을 돌려줍니다.
CallPeerTarget? resolveCallTargetByPhone(
  FamilySnapshot snapshot,
  String rawPhone, {
  Persona? localPersona,
}) {
  final normalized = normalizeCallPhone(rawPhone);
  if (normalized.isEmpty) return null;

  bool matches(String candidate, {bool allowBulletAsStar = false}) {
    final cNorm = normalizeCallPhone(candidate);
    if (cNorm.isEmpty) return false;
    if (normalized == cNorm) return true;
    // 시연 데이터의 마스킹 번호(예: 010-••••-1024)를 키패드의 *로 입력한 경우도 허용합니다.
    if (allowBulletAsStar && cNorm.contains('•')) {
      return normalized == cNorm.replaceAll('•', '*');
    }
    return false;
  }

  if (localPersona != Persona.guardian &&
      matches(snapshot.guardian.phone, allowBulletAsStar: true)) {
    final g = snapshot.guardian;
    return CallPeerTarget(
      peerId: 'guardian',
      peerName: g.name.isNotEmpty ? '보호자 ${g.name}' : '보호자',
      peerPhone: g.phone,
    );
  }

  String? scriptNameForNormalized() {
    for (final script in snapshot.callScripts) {
      if (matches(script.callerPhone) && script.callerName.isNotEmpty) {
        return script.callerName;
      }
    }
    return null;
  }

  final allSms = <SmsMessage>[
    for (final m in snapshot.members) ...m.smsMessages,
    if (snapshot.guardian.banking != null) ...snapshot.guardian.banking!.smsMessages,
  ];
  for (final msg in allSms) {
    if (matches(msg.senderPhone)) {
      final name = msg.senderName.isNotEmpty
          ? msg.senderName
          : (scriptNameForNormalized() ?? '시연 상대');
      return CallPeerTarget(
        peerId: 'counterpart',
        peerName: name,
        peerPhone: msg.senderPhone,
      );
    }
    for (final p in msg.phones) {
      if (matches(p)) {
        final name = msg.senderName.isNotEmpty
            ? msg.senderName
            : (scriptNameForNormalized() ?? '시연 상대');
        return CallPeerTarget(
          peerId: 'counterpart',
          peerName: name,
          peerPhone: p,
        );
      }
    }
  }

  for (final script in snapshot.callScripts) {
    if (matches(script.callerPhone)) {
      return CallPeerTarget(
        peerId: 'counterpart',
        peerName: script.callerName.isNotEmpty ? script.callerName : '시연 상대',
        peerPhone: script.callerPhone,
      );
    }
  }

  return null;
}

enum CallDirection {
  outgoing('발신'),
  incoming('수신'),
  missed('부재중');

  final String label;
  const CallDirection(this.label);
}

class RecentCallEntry {
  final CallSession session;
  final String peerId;
  final String displayTitle;
  final String dialName;
  final String dialPhone;
  final CallDirection direction;

  const RecentCallEntry({
    required this.session,
    required this.peerId,
    required this.displayTitle,
    required this.dialName,
    required this.dialPhone,
    required this.direction,
  });
}

/// 서버 상태의 통화 목록에서 현재 기기 역할이 낀 통화만 최신순으로 정리합니다.
List<RecentCallEntry> recentCallsForPersona(FamilySnapshot snapshot, Persona persona) {
  final myId = persona.name;
  final indexed = <(int, CallSession)>[];
  for (var i = 0; i < snapshot.calls.length; i++) {
    final c = snapshot.calls[i];
    if (c.involves(myId)) indexed.add((i, c));
  }
  indexed.sort((a, b) {
    final byTime = b.$2.createdAt.compareTo(a.$2.createdAt);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });

  return [
    for (final (_, call) in indexed) _describeRecentCall(call, snapshot, myId),
  ];
}

RecentCallEntry _describeRecentCall(CallSession call, FamilySnapshot snapshot, String myId) {
  final otherId = call.callerId == myId ? call.calleeId : call.callerId;
  final CallDirection direction;
  if (call.callerId == myId) {
    direction = CallDirection.outgoing;
  } else if (call.isEnded && call.answeredAt == null) {
    direction = CallDirection.missed;
  } else {
    direction = CallDirection.incoming;
  }

  if (otherId == 'guardian') {
    final g = snapshot.guardian;
    final name = g.name.isNotEmpty
        ? '보호자 ${g.name}'
        : (call.peerName.isNotEmpty ? call.peerName : '보호자');
    final phone = g.phone.isNotEmpty ? g.phone : call.peerPhone;
    return RecentCallEntry(
      session: call,
      peerId: 'guardian',
      displayTitle: name,
      dialName: name,
      dialPhone: phone,
      direction: direction,
    );
  }

  if (otherId == 'senior' || otherId == 'child') {
    final m = snapshot.memberOrNull(otherId);
    final name = m?.label ?? (call.peerName.isNotEmpty ? call.peerName : '가족');
    return RecentCallEntry(
      session: call,
      peerId: otherId,
      displayTitle: name,
      dialName: name,
      dialPhone: '앱 안 통화',
      direction: direction,
    );
  }

  final title = call.peerName.isNotEmpty
      ? call.peerName
      : (call.peerPhone.isNotEmpty ? call.peerPhone : '시연 상대');
  return RecentCallEntry(
    session: call,
    peerId: otherId,
    displayTitle: title,
    dialName: call.peerName.isNotEmpty ? call.peerName : title,
    dialPhone: call.peerPhone,
    direction: direction,
  );
}
