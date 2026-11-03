@tool
extends EditorPlugin
## 프로젝트 → 도구 → "카드 가져오기..." : zip 선택 → 미리보기 → 적용.

const MENU := "카드 가져오기..."
const MAX_NAMES := 20

var _file_dialog: EditorFileDialog
var _confirm: ConfirmationDialog
var _error: AcceptDialog
var _importer: CardImporter


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	for d in [_file_dialog, _confirm, _error]:
		if d:
			d.queue_free()


func _open() -> void:
	if _file_dialog == null:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_file_dialog.title = "카드 에디터 내보내기 zip 선택"
		_file_dialog.add_filter("*.zip", "카드 에디터 내보내기")
		_file_dialog.file_selected.connect(_on_file_selected)
		EditorInterface.get_base_control().add_child(_file_dialog)
	_file_dialog.popup_file_dialog()


func _on_file_selected(path: String) -> void:
	_importer = CardImporter.new()
	var err := _importer.read_zip(path)
	if not err.is_empty():
		_show_error(err)
		return
	if _confirm == null:
		_confirm = ConfirmationDialog.new()
		_confirm.title = "카드 가져오기"
		_confirm.ok_button_text = "적용"
		_confirm.confirmed.connect(_on_confirmed)
		EditorInterface.get_base_control().add_child(_confirm)
	_confirm.dialog_text = _describe(_importer.preview())
	_confirm.popup_centered()


func _on_confirmed() -> void:
	_importer.apply()
	EditorInterface.get_resource_filesystem().scan()
	print("[Card Importer] 가져오기 완료")


func _describe(p: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("추가 %d장: %s" % [p.added.size(), _names(p.added)])
	lines.append("갱신 %d장: %s" % [p.updated.size(), _names(p.updated)])
	var removed := PackedStringArray()
	var warn := false
	for r in p.removed:
		removed.append(("⚠ " if r.has_effects else "") + r.name)
		warn = warn or r.has_effects
	lines.append("삭제 %d장: %s" % [removed.size(), _names(removed)])
	if warn:
		lines.append("")
		lines.append("⚠ 표시된 카드는 Godot에서 붙인 효과도 함께 삭제됩니다.")
	lines.append("")
	lines.append("효과·비용·조건은 유지되고, 웹 에디터의 내용만 덮어씁니다.")
	return "\n".join(lines)


func _names(names: PackedStringArray) -> String:
	if names.is_empty():
		return "-"
	var shown := names.slice(0, MAX_NAMES)
	var text := ", ".join(shown)
	if names.size() > MAX_NAMES:
		text += " 외 %d장" % (names.size() - MAX_NAMES)
	return text


func _show_error(msg: String) -> void:
	if _error == null:
		_error = AcceptDialog.new()
		_error.title = "카드 가져오기 실패"
		EditorInterface.get_base_control().add_child(_error)
	_error.dialog_text = msg
	_error.popup_centered()
