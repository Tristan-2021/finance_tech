# fingerbell_app

핑거벨 Android Flutter 앱 셸. 기능 패키지(`feature_*`)를 화면에 연결하고 모바일 레이아웃(위쪽 브랜드·사용자 전환·알림, 본문 1단, 하단 메뉴, 바텀 시트)으로 그립니다.

| 경로 | 내용 |
| :--- | :--- |
| `lib/main.dart` | 서버 주소(`FINGERBELL_API_URL`) → 저장소 → `FamilyCubit` 시작 |
| `lib/main_sms.dart` · `lib/main_call.dart` | 별도 문자·전화 앱 시작 파일. `ProviderPrefsStore`로 역할·설정을 읽은 뒤 `CompanionApp` 실행 |
| `lib/app_links.dart` · `lib/companion_app.dart` | 패키지를 지정한 Android `ACTION_VIEW` + MethodChannel 수신, 시작·resume 때 공유 역할·고대비·글자 배율(`FingerBellApp.textFactor`) 반영 |
| `lib/app.dart` | `FamilyCubit`·`ShellCubit` 제공, 테마(고대비), 글자 배율(어르신 17/16, 큰 글씨 1.12배) |
| `lib/shell/` | 모바일 레이아웃, 배너, 토스트, 흔들기 감지 연결, 실시간 이벤트 반응(위험 문자·통화·보류·재확인 대기·연결 포함), 시연 시나리오(`사칭 문자 받기`, `정상 문자 받기`, `시연 상대 화면 열기`, `흔들어서 SOS 동결`, `낯선 계좌로 50만원 송금`, `등교 모드에서 게임 결제`) |
| `lib/views/` | 어르신·아이 일반/쉬운 화면 홈(`easy_home.dart`, 홈 상단 토글·첫 실행 질문·문자/전화 바로가기·사기 신고·도움), 내역/안심, 적금 만기 전 해지·대출 설명의무 흐름, 설정(`바로 시연해 보기` 7종 + `처음 상태로 되돌리기`, `settings_sheets.dart` 사용 방법 3장·불편한 점 보내기·경고음/진동 설정) |

실행 방법은 저장소 루트의 [README](../../README.md)를 보세요.

루트에서 `./run-android.ps1 -Device R3CX10T957B -NoResident`를 실행하면 flavor 세 개를 빌드·설치합니다. 패키지는 `kr.fingersnap.fingerbell`, `.sms`, `.call`, 설치 이름은 핑거벨·핑거벨 문자·핑거벨 전화입니다. 새 pub 패키지는 추가하지 않았습니다.

딥링크 주소는 `fingerbell://sms/conversation?peer=senior`, `fingerbell://call/dial?peer=guardian` 형태입니다. `peer`는 현재 화면 표시만 하며 통화를 시작하지 않습니다. 핑거벨의 `SharedPrefsProvider`(`kr.fingersnap.fingerbell.prefs`)는 서명 권한으로 보호되어 역할과 5개 기기 설정을 읽기 전용으로 내주며, 핑거벨이 없거나 읽기에 실패하면 문자·전화 앱은 기본값으로 동작합니다. 기능 이동과 백그라운드 수신은 다음 단계입니다.

```powershell
flutter test
```
