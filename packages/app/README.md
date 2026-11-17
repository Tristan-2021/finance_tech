# fingerbell_app

핑거벨 Android 앱 묶음(`핑거벨` · `핑거벨 문자` · `핑거벨 전화`)의 Flutter 셸입니다. 세 flavor가 하나의 Android 프로젝트(`packages/app/android`)를 공유하며, 같은 인증서로 서명하고 패키지 이름·설치 이름·런처 아이콘(`core_ui` 브랜드 색 기반 적응형 아이콘)으로 구분합니다.

## 앱 3개 · flavor · 시작 파일

| flavor | 설치 이름 | 패키지 이름 | 시작 파일 | 화면과 역할 |
| :--- | :--- | :--- | :--- | :--- |
| `fingerbell` | `핑거벨` | `kr.fingersnap.fingerbell` | `lib/main.dart` | 가상 은행(송금·결제·조회·적금 해지·대출), 보호자 모드, SOS 동결, 쉬운 화면·설정, 주의 모드 상태 |
| `sms` | `핑거벨 문자` | `kr.fingersnap.fingerbell.sms` | `lib/main_sms.dart` | `SmsApp` (`feature_sms`: iOS 메시지 앱 모양을 흉내 낸 모조 앱 — 최신순 대화 목록 `메시지`·말풍선·위험·주의 알림 띠·링크 차단·본문/상단 전화 클릭 시 전화 앱 연결) |
| `call` | `핑거벨 전화` | `kr.fingersnap.fingerbell.call` | `lib/main_call.dart` | `CallApp` (`feature_call`: iOS 전화 앱 모양을 흉내 낸 모조 앱 — 최근 기록·연락처·키패드 홈, 어두운 발신/수신/통화 중 화면·WebRTC·실시간 경고·시연 상대 화면) |

`packages/app/pubspec.yaml`에는 세 앱 진입점이 함께 들어 있어 `feature_sms`와 `feature_call`이 포함되지만, 핑거벨 앱 코드(`main.dart`, `app.dart`, `shell/`, `views/`)는 두 기능 패키지를 쓰지 않고 `AppLinks`로만 문자·전화 앱을 엽니다.

## 주요 파일

| 경로 | 내용 |
| :--- | :--- |
| `lib/main.dart` | 서버 주소(`FINGERBELL_API_URL`) → `FamilyCubit` · `MethodChannelPrefsStore` 시작 → `FingerBellApp` |
| `lib/main_sms.dart` · `lib/main_call.dart` | 문자·전화 앱 시작 파일 (`runSmsApp()`, `runCallApp()`). `ProviderPrefsStore`로 공유 역할·설정을 읽음 |
| `lib/app_links.dart` | `fingerbell://bank\|sms\|call` 링크 생성·인자 검증(`parseSmsLink`, `parseCallLink`) · 앱 열기 채널(`kr.fingersnap.fingerbell/apps`) 호출 |
| `lib/companion_app.dart` | 문자·전화 앱 공용 셸(`CompanionApp`, `CompanionHeader`, `CompanionOfflineBanner`). 시작·resume 때 공유 설정 재로드 및 서버 상태 새로고침, `FingerBellApp.applyTextScale` 적용 |
| `lib/ios/ios_chrome.dart` | 전화·문자 앱이 공통으로 쓰는 iOS 스타일 색 팔레트(`IosPalette`), 물결 없는 테마(`iosNoSplashTheme`), 오프라인 안내 막대(`IosOfflineNoticeBar`) |
| `lib/sms/sms_app.dart` | `SmsApp` iOS 메시지 앱 모양 모조 문자 앱 (`SmsSheet(asScreen: true)`), 번호/상단 전화·보호자 통화 시 `AppLinks.openCall` 연결, 포그라운드 수신 안내 |
| `lib/call/call_app.dart` · `call_lookup.dart` | `CallApp` iOS 전화 앱 모양 모조 홈(`[최근 기록]`·`[연락처]`·`[키패드]`), 번호→상대 해석, 전체 화면 통화(`CallSheet`) · 시연 상대 화면(`CounterpartSheet`), 포그라운드 수신 전화 화면 열기 |
| `lib/app.dart` | `FingerBellApp`: `FamilyCubit`·`ShellCubit` 제공, 고대비 테마, 글자 배율(어르신 17/16, 큰 글씨 1.12배) |
| `lib/shell/` | 핑거벨 앱 레이아웃, 배너, 토스트, 흔들기 감지, 포그라운드 실시간 이벤트·수신 전화 안내, 시연 시나리오(`바로 시연해 보기`) |
| `lib/views/` | 어르신·아이 일반/쉬운 화면 홈(`easy_home.dart`), 내역/안심, 적금 해지·대출 설명의무 흐름(`banking_sheets.dart`), 설정(`settings_view.dart`, `settings_sheets.dart`) |
| `android/.../SharedPrefsProvider.kt` | `fingerbell` flavor 전용 서명 권한 읽기 전용 `ContentProvider` (`kr.fingersnap.fingerbell.prefs`) |

## 앱 사이 연결 · 설정 공유 · 수신 범위

- **앱 사이 연결**: `MainActivity`가 `kr.fingersnap.fingerbell/apps` 채널의 `open`으로 대상 패키지(`kr.fingersnap.fingerbell`, `.sms`, `.call`)의 `MainActivity`를 `Intent.ACTION_VIEW`로 직접 엽니다(`AndroidManifest.xml`의 `<queries>`로 Android 11+ 패키지 가시성 확보).
  - 문자 링크: `fingerbell://sms`, `fingerbell://sms/conversation?phone=...`
  - 전화 링크: `fingerbell://call`, `fingerbell://call/dial?peer=...&phone=...&name=...`, `fingerbell://call/incoming?callId=...`, `fingerbell://call/counterpart`
- **역할·기기 설정 공유**: `SharedPrefsProvider`가 `kr.fingersnap.fingerbell.permission.READ_PREFS`(`signature`) 권한으로 핑거벨의 `persona`와 5개 설정(`largeText`, `highContrast`, `voice`, `sound`, `haptics`)을 읽기 전용으로 내줍니다. 문자·전화 앱은 시작과 `resume`에서 읽으며, 핑거벨 앱이 없거나 읽기에 실패하면 기본값으로 동작합니다.
- **수신 범위**: 문자 알림과 걸려 오는 전화는 **세 앱 중 하나가 화면에 떠 있을 때만** 받습니다. 앱이 닫혀 있거나 화면이 꺼져 있으면 받지 못하고, 다시 열면 서버 상태(`GET /api/v1/state`)로 따라잡습니다.

## 실행 · IDE 실행 구성

저장소 루트에서 실행합니다(자세한 내용은 [루트 README](../../README.md) · [RUN_LOCAL.ko.md](../../RUN_LOCAL.ko.md)).

```powershell
.\run-android.ps1 -NoResident
```

- `-Device`를 주지 않으면 연결(인증)된 기기 1대를 자동 선택하고, 없으면 `Medium_Phone_API_37.0`(`emulator-5554`) 에뮬레이터를 띄우며, 2대 이상 연결돼 있으면 기기 id 목록을 보여 주고 `-Device`를 고르도록 끝냅니다.
- 세 flavor를 차례로 빌드(`--no-pub`)·설치(`adb install -r`)하고 `adb reverse tcp:8765 tcp:8765`를 설정한 뒤 핑거벨을 엽니다.
- IntelliJ 실행 구성 **FingerBell (Android)**(`.run/FingerBell_Android.run.xml`)도 `run-android.ps1 -NoResident`를 실행합니다.

## 문제 해결

- **대상 앱이 설치되지 않았을 때**: 핑거벨에서 `[문자]`·`[전화]`·`[보호자에게 전화]`·시연 버튼을 눌렀을 때 `"핑거벨 문자 앱이 설치되어 있지 않아 열 수 없어요"` 또는 `"핑거벨 전화 앱이 설치되어 있지 않아 열 수 없어요"` 안내가 뜨면 세 앱 중 일부만 설치된 상태입니다. 루트에서 `.\run-android.ps1 -NoResident`를 실행해 세 앱을 함께 다시 설치하세요.
- **`adb reverse` 연결 오류**: `run-android.ps1`이 `adb reverse tcp:8765 tcp:8765`를 자동으로 설정하지만, 기기 재연결·재부팅 뒤에는 풀릴 수 있습니다. `adb -s <기기ID> reverse tcp:8765 tcp:8765`를 다시 실행하거나 `.\run-android.ps1`을 다시 실행하세요. 여러 기기를 Wi-Fi로 연결해 시연할 때는 `.\run-backend.ps1 -Lan`과 `--dart-define=FINGERBELL_API_URL=http://<PC_IP>:8765`(또는 `.env.local.json`)를 씁니다.

```powershell
flutter test
```
