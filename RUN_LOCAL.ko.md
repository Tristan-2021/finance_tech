# Windows에서 핑거벨 실행

Flutter 진입점은 `packages/app/lib/main.dart`, `main_sms.dart`, `main_call.dart`이며 백엔드는 `backend/`(FastAPI)입니다. 문자·전화 앱은 핑거벨과 역할·화면 설정(고대비·큰 글씨 등)을 공유하는 셸 상태이며 기능 화면은 아직 기존 핑거벨 안에 있습니다.

## 1. 백엔드 먼저 실행

```powershell
.\run-backend.ps1
```

처음에는 `backend/.venv`를 만들고 패키지를 설치합니다. 서버는 `http://127.0.0.1:8765`에서 열리고 API 문서는 `/docs`입니다. 포트 8000은 이 PC에서 다른 프로그램(Godot MCP 서버)이 쓰고 있어 8765를 기본값으로 씁니다.

- `-Reset`: 시연 데이터를 처음 상태로 되돌리고 시작
- `-Lan`: 같은 Wi-Fi의 휴대폰에서 접속할 수 있게 모든 네트워크 주소에 엶 (방화벽 허용 필요)
- `-Port 9000`: 다른 포트

## 2. 앱 실행

### Android (PowerShell)

```powershell
.\run-android.ps1
```

실행 스크립트는 `flutter pub get`으로 의존성을 맞춘 뒤 `Medium_Phone_API_37.0` 에뮬레이터를 켜고 `adb reverse tcp:8765 tcp:8765`를 설정하며, flavor `fingerbell`·`sms`·`call`의 debug APK를 차례로 빌드(`--no-pub`)하고 `adb install -r`로 설치합니다. 빌드별 시간과 설치 포함 총 시간을 출력하고 핑거벨을 엽니다. 이어서 `flutter attach`로 연결하므로 `r`은 핫 리로드, `R`은 핫 리스타트, `q`는 디버거 종료입니다. `-NoResident`는 설치·실행 뒤 스크립트를 끝냅니다.

```powershell
.\run-android.ps1 -Device emulator-5556 -Emulator '다른_AVD_이름'
.\run-android.ps1 -Device R3CX10T957B -NoResident
```

## 서버 주소 바꾸기

`.env.local.json`에 `FINGERBELL_API_URL`이 있으면 그 값을 씁니다 (형식은 `.env.example`). 없으면 기본 주소 `http://127.0.0.1:8765`를 씁니다. 예전 Supabase 값만 들어 있는 `.env.local.json`은 더 이상 쓰지 않으니 지워도 됩니다.

## IntelliJ IDEA · Cursor / VS Code

IntelliJ의 실행 구성 **FingerBell (Android)** 는 `.run/FingerBell_Android.run.xml`에서 `run-android.ps1 -NoResident`를 실행합니다. `adb reverse`도 이 스크립트가 설정합니다. 실기기는 Script options를 `-Device R3CX10T957B -NoResident`로 바꿉니다. IDE 버튼 실행 자체는 아직 검증하지 않았습니다. Cursor / VS Code의 무시된 로컬 `.vscode` 구성은 변경하지 않았으므로 터미널에서 위 스크립트를 사용합니다. 백엔드는 따로 `run-backend.ps1`로 켜 두세요.

## 참고

- 실행 스크립트는 `FLUTTER_WINDOWS=false`, `FLUTTER_LINUX=false`로 Windows 데스크톱 플러그인 심볼릭 링크 준비를 건너뜁니다.
- C: 드라이브 Pub 캐시와 D: 드라이브 프로젝트 사이의 Kotlin 캐시 오류를 막기 위해 Android `gradle.properties`에 `kotlin.incremental=false`가 있습니다.
- 한글 글꼴(Noto Sans KR, OFL 1.1)은 앱에 들어 있어 오프라인에서도 같은 글꼴로 보입니다.
