import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:flutter/services.dart';

/// 문자 앱 딥링크 해석 결과. 잘못된 인자는 무시하고 [SmsLinkKind.home]으로 돌려보냅니다.
enum SmsLinkKind { home, conversation }

class SmsLink {
  final SmsLinkKind kind;
  final String? senderPhone;

  const SmsLink.home() : kind = SmsLinkKind.home, senderPhone = null;
  const SmsLink.conversation(String phone) : kind = SmsLinkKind.conversation, senderPhone = phone;
}

/// 전화 앱 딥링크 해석 결과. 잘못된 상대·번호는 무시하고 [CallLinkKind.home]으로 돌려보냅니다.
enum CallLinkKind { home, dial, incoming, counterpart }

class CallLink {
  final CallLinkKind kind;
  final String? peerId;
  final String? phone;
  final String? name;
  final String? callId;

  const CallLink.home()
      : kind = CallLinkKind.home,
        peerId = null,
        phone = null,
        name = null,
        callId = null;

  const CallLink.dial({required String this.peerId, this.phone, this.name})
      : kind = CallLinkKind.dial,
        callId = null;

  const CallLink.incoming({this.callId})
      : kind = CallLinkKind.incoming,
        peerId = null,
        phone = null,
        name = null;

  const CallLink.counterpart()
      : kind = CallLinkKind.counterpart,
        peerId = null,
        phone = null,
        name = null,
        callId = null;
}

/// Android 앱 사이 화면 이동. 서버 상태는 각 앱이 따로 읽고, 발신자는 공유 역할에서 정합니다.
class AppLinks {
  static const channel = MethodChannel('kr.fingersnap.fingerbell/apps');

  static final RegExp _hyphenPhoneRe = RegExp(r'^(?:0\d{1,2}-[•*\d]{3,4}-\d{4}|1[568]\d{2}-\d{4})$');
  static final RegExp _plainPhoneRe = RegExp(r'^0\d{8,10}$');
  static final RegExp _unsafeTextRe = RegExp(r'[\x00-\x1F\x7F<>]');
  static final RegExp _callIdRe = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

  static Future<void> open(Uri uri) =>
      channel.invokeMethod<void>('open', {'uri': uri.toString()});

  static Future<Uri?> initialLink() async {
    try {
      final value = await channel.invokeMethod<String>('initialLink');
      return value == null ? null : Uri.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  /// 대상 앱을 열고, 설치돼 있지 않거나 열지 못하면 [shell.say]로 쉬운 안내를 남깁니다.
  static Future<bool> openWithFallback(ShellCubit shell, Uri uri) async {
    try {
      await open(uri);
      return true;
    } on PlatformException catch (e) {
      shell.say(_missingAppMessage(uri, e));
      return false;
    } on MissingPluginException {
      shell.say(_missingAppMessage(uri));
      return false;
    }
  }

  static Future<bool> openSms(ShellCubit shell, {String? senderPhone}) =>
      openWithFallback(shell, smsUri(senderPhone: senderPhone));

  static Future<bool> openCall(
    ShellCubit shell, {
    required String peer,
    String? phone,
    String? name,
  }) => openWithFallback(shell, callDialUri(peer: peer, phone: phone, name: name));

  static Future<bool> openIncomingCall(ShellCubit shell, {String? callId}) =>
      openWithFallback(shell, callIncomingUri(callId: callId));

  static Future<bool> openCounterpart(ShellCubit shell) =>
      openWithFallback(shell, callCounterpartUri());

  static Uri smsUri({String? senderPhone}) {
    final validPhone = parsePhoneArg(senderPhone);
    if (validPhone == null) {
      return Uri(scheme: 'fingerbell', host: 'sms');
    }
    return Uri(
      scheme: 'fingerbell',
      host: 'sms',
      path: '/conversation',
      queryParameters: {'phone': validPhone},
    );
  }

  static Uri callHomeUri() => Uri(scheme: 'fingerbell', host: 'call');

  static Uri callDialUri({required String peer, String? phone, String? name}) {
    final validPhone = parsePhoneArg(phone);
    final validName = parseNameArg(name);
    return Uri(
      scheme: 'fingerbell',
      host: 'call',
      path: '/dial',
      queryParameters: {
        'peer': peer,
        'phone': ?validPhone,
        'name': ?validName,
      },
    );
  }

  static Uri callIncomingUri({String? callId}) => Uri(
    scheme: 'fingerbell',
    host: 'call',
    path: '/incoming',
    queryParameters: {
      if (isValidCallId(callId)) 'callId': callId!.trim(),
    },
  );

  static Uri callCounterpartUri() =>
      Uri(scheme: 'fingerbell', host: 'call', path: '/counterpart');

  static String? parsePhoneArg(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty || v.length > 24) return null;
    if (_hyphenPhoneRe.hasMatch(v) || _plainPhoneRe.hasMatch(v)) return v;
    return null;
  }

  static String? parseNameArg(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty || v.length > 40 || _unsafeTextRe.hasMatch(v)) return null;
    return v;
  }

  static bool isValidCallId(String? raw) {
    final v = raw?.trim() ?? '';
    return v.isNotEmpty && _callIdRe.hasMatch(v);
  }

  /// 잘못된 퍼센트 인코딩(%FF 등)이 담긴 쿼리를 읽다 예외가 나지 않도록 방어합니다.
  static Map<String, String>? _safeQueryParameters(Uri uri) {
    try {
      return uri.queryParameters;
    } on FormatException {
      return null;
    }
  }

  static SmsLink? parseSmsLink(Uri? uri) {
    if (uri == null || uri.scheme != 'fingerbell' || uri.host != 'sms') return null;
    final query = _safeQueryParameters(uri);
    if (query == null) return const SmsLink.home();
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/' || path == '/conversations') return const SmsLink.home();
    if (path == '/conversation') {
      final phone = parsePhoneArg(query['phone']);
      return phone == null ? const SmsLink.home() : SmsLink.conversation(phone);
    }
    return const SmsLink.home();
  }

  static CallLink? parseCallLink(
    Uri? uri, {
    required Persona localPersona,
    FamilySnapshot? snapshot,
  }) {
    if (uri == null || uri.scheme != 'fingerbell' || uri.host != 'call') return null;
    final query = _safeQueryParameters(uri);
    if (query == null) return const CallLink.home();
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/' || path == '/home') return const CallLink.home();
    if (path == '/counterpart') return const CallLink.counterpart();
    if (path == '/incoming') {
      if (query.containsKey('callId')) {
        final rawCallId = query['callId'];
        if (!isValidCallId(rawCallId)) return const CallLink.home();
        return CallLink.incoming(callId: rawCallId!.trim());
      }
      return const CallLink.incoming();
    }
    if (path == '/dial') {
      final peer = query['peer']?.trim() ?? '';
      if (!_isCallablePeer(peer, localPersona: localPersona, snapshot: snapshot)) {
        return const CallLink.home();
      }
      String? parsedPhone;
      if (query.containsKey('phone')) {
        parsedPhone = parsePhoneArg(query['phone']);
        if (parsedPhone == null) return const CallLink.home();
      }
      if (peer == 'counterpart' && parsedPhone == null) {
        return const CallLink.home();
      }
      String? parsedName;
      if (query.containsKey('name')) {
        parsedName = parseNameArg(query['name']);
        if (parsedName == null) return const CallLink.home();
      }
      return CallLink.dial(peerId: peer, phone: parsedPhone, name: parsedName);
    }
    return const CallLink.home();
  }

  static bool _isCallablePeer(
    String peer, {
    required Persona localPersona,
    FamilySnapshot? snapshot,
  }) {
    if (peer.isEmpty || peer == localPersona.name) return false;
    if (peer == 'counterpart') return true;
    if (localPersona == Persona.guardian) {
      if (snapshot != null) {
        return snapshot.memberOrNull(peer) != null;
      }
      return peer == 'senior' || peer == 'child';
    }
    return peer == 'guardian';
  }

  static String _missingAppMessage(Uri uri, [PlatformException? error]) {
    final appName = switch (uri.host) {
      'sms' => '핑거벨 문자',
      'call' => '핑거벨 전화',
      'bank' => '핑거벨',
      _ => '대상',
    };
    if (error != null && error.code != 'app_missing' && (error.message?.isNotEmpty ?? false)) {
      return error.message!;
    }
    return '$appName 앱이 설치되어 있지 않아 열 수 없어요';
  }
}
