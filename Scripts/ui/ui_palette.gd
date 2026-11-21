class_name UiPalette
extends RefCounted
## v6 연보라 팔레트 (Figma `Project Void UI Wireframes` › v6 › 00-B 규칙 노트).
## 테마(`Scenes/ui/void_theme.tres`)와 같은 값. 스크립트에서 상태에 따라 색을 바꿀 때(선택·비활성 등) 여기 값을 쓴다.
## 값을 바꾸면 테마 쪽도 같이 바꾼다.

## 화면 바탕, 밝은 버튼 위 글자
const INK := Color("1a1626")
## 패널 바탕
const PANEL := Color("29243b")
## 칩·작은 판
const PLATE := Color("3d3554")
## 강조 글자, 선택 막대, 선택된 메뉴 글자
const ACCENT := Color("ccb8ff")
## 테두리·구분선 (보통 투명도를 낮춰 씀)
const LINE := Color("b3a1e0")
## 주 버튼 그라데이션 위쪽·아래쪽
const BUTTON_TOP := Color("e0d1ff")
const BUTTON_BOTTOM := Color("ad94f0")
## 본문 글자
const TEXT := Color("f2edfc")
## 보조 글자 (영문 부제, 상태 글)
const SUB := Color("ada3cc")
## 번호·작은 라벨
const DIM := Color("786e94")
## 스킬·완료
const TEAL := Color("66d1c7")
## 긴급·공격, 새 소식 배지
const ROSE := Color("f0738c")
## 자금·기사, 할 수 있는 일 배지
const AMBER := Color("f5cc80")
