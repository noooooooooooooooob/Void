@tool
class_name OfficePanel
extends Control
## 사무소 오른쪽 패널 틀 (Figma v6 01-A "Content Panel"). 씬: `Scenes/ui/office_screen/office_panel.tscn`.
## 머리(No.01 / 07 · 제목 · 영문 · BUREAU / REQUESTS 경로 · ESC 닫기 버튼)와 내용 자리(%Content)를 가진다.
## 사무소 씬에 이 씬을 7번 넣고 인스펙터 칸만 다르게 한다. 내용을 채울 때는 이 씬을 상속한 씬을 만든다.
## 열기/닫기 연출(페이드 + 왼쪽에서 밀려 들어옴)도 여기서 한다. 어떤 패널을 열지는 OfficeScreen 이 정한다.

## 닫기 버튼을 눌렀다 (OfficeScreen 이 받아서 닫는다)
signal close_requested

## 패널 번호 (1 ~ 7). 머리에 "No.01" 로 보인다
@export var number := 1:
	set(v):
		number = v
		_refresh()
## 전체 패널 수. 머리에 "/ 07" 로 보인다
@export var total := 7:
	set(v):
		total = v
		_refresh()
## 한글 제목 ("의뢰 게시판")
@export var title_ko := "패널":
	set(v):
		title_ko = v
		_refresh()
## 영문 제목 ("Requests")
@export var title_en := "Panel":
	set(v):
		title_en = v
		_refresh()
## 오른쪽 위 경로 글 ("BUREAU   /   REQUESTS")
@export var path_label := "BUREAU":
	set(v):
		path_label = v
		_refresh()
## 내용 자리의 "준비 중" 글을 보일지. 내용을 채운 패널(의뢰 게시판)은 끈다
@export var show_placeholder := true:
	set(v):
		show_placeholder = v
		_refresh()
## 열기·닫기에 걸리는 시간 (초)
@export var open_time := 0.18
## 열 때 왼쪽에서 밀려 들어오는 거리 (픽셀)
@export var slide := 16.0

var _home_x := 0.0  # 씬에 놓인 x 자리 (밀려 들어온 뒤 돌아올 자리)
var _tween: Tween
var _closing := false  # 닫히는 연출 중인지


func _ready() -> void:
	_refresh()
	_home_x = position.x
	if Engine.is_editor_hint():
		return
	%CloseButton.pressed.connect(func(): close_requested.emit())


## 지금 열려 있는지 (닫히는 중이면 false)
func is_open() -> bool:
	return visible and not _closing


## 연다. animate = false 면 연출 없이 바로
func open(animate := true) -> void:
	_kill()
	_closing = false
	visible = true
	if not animate:
		modulate.a = 1.0
		position.x = _home_x
		return
	modulate.a = 0.0
	position.x = _home_x - slide
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, open_time)
	_tween.tween_property(self, "position:x", _home_x, open_time)


## 닫는다. animate = false 면 바로 숨김 (다른 패널로 바꿀 때)
func close(animate := true) -> void:
	_kill()
	if not visible:
		return
	if not animate:
		visible = false
		position.x = _home_x
		return
	_closing = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, open_time)
	_tween.tween_callback(func():
		visible = false
		_closing = false
		position.x = _home_x)


## 진행 중인 연출을 멈춘다
func _kill() -> void:
	if _tween:
		_tween.kill()
		_tween = null


## 머리 글을 지금 값으로 맞춘다
func _refresh() -> void:
	if not is_node_ready():
		return
	%Number.text = "No.%02d" % number
	%Total.text = "/ %02d" % total
	%TitleKo.text = title_ko
	%TitleEn.text = title_en
	%PathLabel.text = path_label
	%Content.get_node("Placeholder").visible = show_placeholder
