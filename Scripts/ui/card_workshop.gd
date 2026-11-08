class_name CardWorkshop
extends Control
## 카드 공방 화면. card_workshop.tscn 의 스크립트.
## 공용 카드(덱이 없는 카드, cards/data/common/)를 보여준다. 카드 갤러리(card_gallery.tscn)를 씬에 넣고 덱을 "공용"으로 고정했다.
## 지금은 보기만 한다 (카드 강화·제작은 나중에).

@onready var _gallery: CardGallery = %Gallery
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(Router.goto.bind(Router.Screen.OFFICE))
	# 공용 카드만: 덱 고정 + 덱 선택 탭 숨김
	_gallery.deck = CardGallery.COMMON_LABEL
	_gallery.deck_tabs.visible = false
	_back.grab_focus()


## ESC: 사무소로
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.goto(Router.Screen.OFFICE)
