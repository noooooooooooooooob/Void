class_name RequestData
extends Resource
## 의뢰 한 건 (사무소 의뢰 게시판에 붙는 카드 하나). `.tres` 는 `requests/` 폴더에 둔다.
## 의뢰 게시판(RequestsBoard)이 이 폴더를 읽어 카드 목록과 오른쪽 자세히 보기를 만든다.
## 설계 docs/superpowers/specs/2026-11-24-request-board-design.md
##
## 지금은 어떤 의뢰를 골라도 같은 1층 의뢰(랜덤 지도)가 시작된다. 고른 의뢰는 StageRun.current_request 에 남는다.
## 등급·지역·보상·목표는 글일 뿐이다 (자금·명성·목표 진행 시스템이 아직 없음).

## 의뢰 종류. 필터 칩·카드 칩·장 줄이 이것을 본다
enum Kind {
	MAIN,    ## 본 이야기 (장 번호가 있음)
	REPEAT,  ## 반복 의뢰
}
## 게시판 필터 칩 (전체 / 본 이야기 / 반복 의뢰)
enum Filter { ALL, MAIN, REPEAT }

## 의뢰 번호. 카드 오른쪽 위에 보인다 ("REQ-0312"). 같은 번호는 정렬 마지막 기준
@export var code := "REQ-0000"
## 의뢰 제목 ("하수도에서 올라온 검은 것"). 본 이야기면 카드에서 앞에 "3장 · " 이 자동으로 붙는다
@export var title := "의뢰"
## 본 이야기 / 반복 의뢰
@export var kind := Kind.REPEAT
## 본 이야기의 장 번호 (1~). 반복 의뢰는 쓰지 않는다
@export_range(0, 99) var chapter := 0
## 긴급 의뢰. 카드 칩이 "긴급"(빨강)이 되고 자세히 보기에 도장이 찍힌다. 목록 맨 앞으로 간다
@export var urgent := false

@export_group("의뢰인")
## 의뢰인 이름 (카드 "의뢰인 · 하수도 감독관", 초상 밑)
@export var client_ko := "의뢰인"
## 의뢰인 영문 이름 (초상 밑 작은 글, "Sewer Overseer")
@export var client_en := "Client"
## 의뢰인 초상 그림. 비어 있으면 "의뢰인 초상" 글이 보인다
@export var portrait: Texture2D
## 의뢰인이 하는 말 (자세히 보기의 인용, 따옴표까지 넣어서)
@export_multiline var quote := ""

@export_group("정보")
## 권장 등급 글 ("3급 이상"). 사원 등급 시스템이 생기기 전까지 글일 뿐
@export var rank := ""
## 지역 글 ("남부 · 하수도")
@export var region := ""
## 적 정보 글 ("괴한 ×1 · 잡졸 ×2")
@export var enemies := ""
## 목표 목록 (위에서부터). 지금은 체크 없이 글만 보인다
@export var objectives := PackedStringArray()
## 보상 글 ("자금 500 · 카드 팩 ×1"). 카드 아래와 보상 칸 밑에 보인다
@export var reward_text := ""
## 난이도 (1~3). 카드 오른쪽 아래 ◆ 3개 중 이만큼 밝게
@export_range(1, 3) var difficulty := 1:
	set(v):
		difficulty = clampi(v, 1, 3)

@export_group("잠금")
## 잠긴 의뢰 (스토리 진행 전). 목록 맨 뒤에 흐리게 보이고 고를 수 없다
@export var locked := false
## 잠긴 카드에 보이는 해금 조건 글 ("3장 완료 후 해금")
@export var unlock_hint := ""


## 카드 제목: 본 이야기는 "3장 · 제목", 반복 의뢰는 제목 그대로
func card_title() -> String:
	if kind == Kind.MAIN and chapter > 0:
		return "%d장 · %s" % [chapter, title]
	return title


## 자세히 보기 맨 위 줄 ("CHAPTER 03  —  MAIN STORY" / "REPEATABLE  —  SIDE REQUEST")
func chapter_line() -> String:
	if kind == Kind.MAIN:
		return "CHAPTER %02d  —  MAIN STORY" % chapter
	return "REPEATABLE  —  SIDE REQUEST"


## 카드의 의뢰인 줄 ("의뢰인 · 하수도 감독관")
func client_line() -> String:
	return "의뢰인 · " + client_ko


## 게시판에서 고를 수 있는지 (잠기지 않았으면)
func is_selectable() -> bool:
	return not locked


## 필터 칩에 걸리는지
func matches(filter: Filter) -> bool:
	match filter:
		Filter.MAIN:
			return kind == Kind.MAIN
		Filter.REPEAT:
			return kind == Kind.REPEAT
	return true


## 게시판 순서로 정렬한 새 배열 (원본은 그대로).
## 규칙(Figma 01-A 순서): 잠기지 않은 것 먼저 → 긴급 먼저 → 본 이야기 먼저(장 순서) → 번호 순
static func sort_for_board(list: Array[RequestData]) -> Array[RequestData]:
	var out := list.duplicate()
	out.sort_custom(_board_less)
	return out


## list 중 filter 에 걸리는 것만 (순서 유지)
static func filtered(list: Array[RequestData], filter: Filter) -> Array[RequestData]:
	var out: Array[RequestData] = []
	for r in list:
		if r.matches(filter):
			out.append(r)
	return out


## dir 폴더의 의뢰 전부를 게시판 순서로. 폴더가 없으면 빈 배열 (하위 폴더는 보지 않는다)
static func load_all(dir: String) -> Array[RequestData]:
	var out: Array[RequestData] = []
	for path in ResDir.tres_paths(dir):
		var r := load(path) as RequestData
		if r:
			out.append(r)
	return sort_for_board(out)


## sort_for_board 의 비교: a 가 b 보다 앞이면 true
static func _board_less(a: RequestData, b: RequestData) -> bool:
	if a.locked != b.locked:
		return not a.locked
	if a.urgent != b.urgent:
		return a.urgent
	if a.kind != b.kind:
		return a.kind == Kind.MAIN
	if a.kind == Kind.MAIN and a.chapter != b.chapter:
		return a.chapter < b.chapter
	return a.code < b.code
