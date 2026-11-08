# 사무소 화면과 공허 지도 구현 계획

설계: [docs/superpowers/specs/2026-11-08-office-hub-and-void-map-design.md](../specs/2026-11-08-office-hub-and-void-map-design.md)
브랜치: `feat/office-hub` (`feat/stage` 에서 갈라짐)

## 정한 것 (설계 검토 때, 2026-11-08)
- 공허 장소 = `ProjectVoid_Assets/backgrounds/` 의 배경 7장 전부 (Art/Terrian 의 2장 포함)
- 사원 명부 = `test_hongyeon`(홍연 (시험)) 하나. 진짜 `hongyeon.tres` 의 덱 카드는 아직 효과가 비어 있어 전투가 안 되므로, 카드 효과가 채워지면 바꾼다
- 공허 지도 그림 = `world_map_golden_01` (임시)

## 작업 순서
1. 그림 가져오기: `Art/Terrian/` 2장 → `Art/backgrounds/`(영어 이름), 나머지 배경 5장 + 지도 1장 복사
2. 테스트 먼저 (`tests/stage/test_void_sites.gd`, `tests/stage/test_stage_run.gd`, `tests/ui/test_router.gd`, `tests/ui/test_office_screens.gd`)
3. 스크립트: `VoidSiteData`, `RosterData`, `Router`(자동 로드), `StageRun` 변경, 화면 스크립트(office, storage, roster, card_workshop, void_map, void_marker), 시작 화면 개발용 패널, 전투 화면 배경
4. 씬·데이터: Godot 헤드리스 스크립트로 저장 (손으로 쓰지 않음). 배경 씬 7개, `voids/*.tres` 7개, `entities/roster.tres`, 화면 씬, 자동 로드 등록
5. 전체 테스트 + 실제 씬 전환으로 한 바퀴 확인
6. `docs/progress.md`, CLAUDE.md 폴더 구조 갱신 → 커밋·푸시
