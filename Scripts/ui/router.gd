extends Node
## 화면 전환 담당. 자동 로드 "Router" 로 항상 떠 있다.
## 화면 이름 → 씬 경로 표를 한곳에 두고, 어디서든 Router.goto(Router.Screen.OFFICE) 처럼 화면을 바꾼다.
## 씬 파일을 옮기면 이 표(PATHS)만 고치면 된다. (테스트가 표의 모든 경로에 씬이 있는지 확인한다)

## 게임의 화면들
enum Screen { TITLE, OFFICE, STORAGE, ROSTER, CARD_WORKSHOP, VOID_MAP, STAGE_MAP, BATTLE, ROOM }

## 화면 → 씬 경로
const PATHS := {
	Screen.TITLE: "res://Scenes/ui/title_screen/title_screen.tscn",
	Screen.OFFICE: "res://Scenes/ui/office/office.tscn",
	Screen.STORAGE: "res://Scenes/ui/storage/storage.tscn",
	Screen.ROSTER: "res://Scenes/ui/roster/roster.tscn",
	Screen.CARD_WORKSHOP: "res://Scenes/ui/card_workshop/card_workshop.tscn",
	Screen.VOID_MAP: "res://Scenes/ui/void_map/void_map.tscn",
	Screen.STAGE_MAP: "res://Scenes/ui/stage_map/stage_map.tscn",
	Screen.BATTLE: "res://Scenes/ui/battle_screen/battle_screen.tscn",
	Screen.ROOM: "res://Scenes/ui/room_screen/room_screen.tscn",
}


## screen(Router.Screen) 화면으로 바꾼다. 버튼 처리 중에 불러도 되게, 그 프레임이 끝난 뒤에 바뀐다
func goto(screen: int) -> void:
	get_tree().change_scene_to_file.call_deferred(PATHS[screen])
