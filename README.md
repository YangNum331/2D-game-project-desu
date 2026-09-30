# 작은 마을 · 데이터로 편집하는 Godot 4.x 데모

Godot 4.7.2에서 검증한 RPG Maker 스타일 탑다운 데모입니다.
`project.godot`를 열고 F5로 실행하면 시작 마을이 열립니다.

**콘텐츠를 수정하려면 먼저 [data/README_KR.md](data/README_KR.md)를 읽으세요.**
NPC 이름·위치·초상화·대사·맵 이동 목적지는 CFG/TXT만 수정하면 됩니다.

- WASD / 방향키: 같은 속도의 8방향 이동.
- E / Space: 바라보는 NPC와 대화, 다음 문장, 마지막 문장에서 닫기.
- 8: 플레이어·NPC 로컬 좌표와 최근 콘텐츠 오류 표시.
- 9: 현재 맵 NPC·대사·초상화·이동 연결 새로고침. 개발 실행 전용.
  두 기능은 글자 키 위쪽의 일반 숫자키를 사용합니다.
- 시작 맵 위 검은 통로 → 두 번째 맵 → 오른쪽 위 건물 → 건물 내부.
- 실내 아래 출입구 → 건물 문 앞, 두 번째 맵 아래 통로 → 시작 맵.

## 구조

| 파일 | 역할 |
|---|---|
| `scenes/demo_map.tscn` | 실행 진입점 MapManager, 플레이어 생성, 고정 UI |
| `scripts/map_manager.gd` | 맵 교체, SpawnPoint 조회, 상호작용, 8/9 |
| `scripts/content_loader.gd` | CFG/TXT/초상화 읽기, 데이터 검사와 fallback |
| `maps/*.tscn` | 세 맵, 에디터에서 배치한 SpawnPoints와 Transitions |
| `scripts/game_map.gd` | 작은 타일맵 그리기, 벽 충돌, 데이터 기반 NPC 생성 |
| `scenes/player.tscn`, `scripts/player.gd` | 기존 이동·충돌·바라보기·카메라 |
| `scenes/npc.tscn`, `scripts/npc.gd` | 공통 NPC와 대화 데이터 전달, 디버그 좌표 |
| `scenes/dialogue_box.tscn`, `scripts/dialogue_box.gd` | 화면 하단 초상화·이름·문장·진행 표시 |
| `scenes/transition_area.tscn`, `scripts/transition_area.gd` | 재사용 이동 영역, 영역 크기·ID 설정 |
| `scripts/spawn_point.gd` | 에디터용 출현 ID·방향을 갖는 Marker2D |
| `data/maps/*.cfg` | NPC 이름·로컬 위치·파일 경로·이동 목적지 |
| `data/dialogue/*.txt` | 한 줄당 한 페이지, 빈 줄과 # 주석 무시 |
| `assets/portraits/*.svg` | 직접 만든 세 가지 임시 초상화 |
| `tests/demo_test.gd`, `tests/content_test.gd` | 실제 입력·물리·대화·맵 왕복·데이터 수정 검증 |

기존 `scripts/demo_map.gd`의 역할은 `game_map.gd`와 `map_manager.gd`로 나눴습니다.
시작 설정의 경로는 진입 씬 MapManager Inspector의 Initial Config에 지정합니다.
NPC 정보와 맵 목적지는 스크립트에 들어 있지 않습니다.

## 검증 실행

```powershell
& 'Godot 실행파일 경로' --headless --path . --fixed-fps 60 --script res://tests/demo_test.gd
& 'Godot 실행파일 경로' --headless --path . --fixed-fps 60 --script res://tests/content_test.gd
```

`--headless`를 빼면 실제 그래픽 화면에서도 검증하고 `.godot`에 미리보기 PNG를 저장합니다.
Godot 4.7.2에서 기존 기능 33개와 콘텐츠/맵 이동 58개, 총 91개 검사를
headless 및 Compatibility 그래픽 실행으로 통과했습니다.
콘텐츠 검사는 CFG/TXT를 일시적으로 수정하고 끝나기 전에 원래 내용으로 복구합니다.
검사 중에는 같은 파일을 편집하지 말고, 검사 프로세스를 중간에 강제 종료하지 마세요.

기존 데모 때 발생한 Godot 메모리 오류의 정확한 원인은 미확인입니다.
Compatibility(OpenGL)로 실행하는 후속 검증에서는 재현되지 않았습니다.
제한된 실행 환경에서 Windows 인증서 저장소 접근 로그가 발생하지만 로컬 플레이에는 영향이 없습니다.

## 현재 범위

세 종류의 작은 placeholder 지형과 재사용 NPC/이동 영역만 구현했습니다.
씬 배치 변경은 재실행해야 하며, 9는 콘텐츠 파일만 다시 읽습니다.
한글은 시스템 폰트를 사용합니다. 배포 파일 생성과 다른 PC 실행은 아직 검증하지 않았습니다.
내보낼 때 CFG/TXT 파일 포함 필터와 한글 폰트는 `data/README_KR.md`를 참고하세요.
