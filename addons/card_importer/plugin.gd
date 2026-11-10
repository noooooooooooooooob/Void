@tool
extends EditorPlugin
## 카드 가져오기 에디터 플러그인.
## 메뉴: 프로젝트 → 도구 → "카드 가져오기..."
## 흐름: zip 파일 선택 → 미리보기(카드·장비의 추가/갱신/삭제 목록) 확인 → "적용" → 파일 시스템 다시 스캔.
## 메뉴: 프로젝트 → 도구 → "카드 내보내기..." (저장할 zip 선택 → 결과 안내. zip 은 웹 에디터의 "가져오기"로 넣는다)
## 실제 로직은 CardImporter(card_importer.gd)·EquipmentImporter(equipment_importer.gd)·CardExporter(card_exporter.gd)에 있고, 여기는 메뉴와 대화상자만 담당한다.

## 도구 메뉴에 표시할 항목 이름.
const MENU := "카드 가져오기..."
## 내보내기 도구 메뉴에 표시할 항목 이름.
const MENU_EXPORT := "카드 내보내기..."
## 내보내기 창에 미리 채울 zip 파일 이름 (웹 에디터의 내보내기와 같은 이름).
const EXPORT_FILE_NAME := "project-void-cards.zip"
## 미리보기에서 구역(추가/갱신/삭제)마다 이름을 최대 몇 개까지 보여줄지. 넘으면 "외 N장".
const MAX_NAMES := 20

## zip 선택 창 (처음 열 때 만들고 재사용)
var _file_dialog: EditorFileDialog
## 미리보기 + "적용" 확인 창
var _confirm: ConfirmationDialog
## 오류 안내 창 (zip 이 아니거나 형식이 틀릴 때)
var _error: AcceptDialog
## 지금 진행 중인 가져오기. 미리보기에서 적용까지 같은 객체를 쓴다.
var _importer: CardImporter
## 같은 zip 의 장비 가져오기 (_importer 가 읽은 내용을 넘겨받는다)
var _equipment: EquipmentImporter
## 내보낼 zip 저장 위치 선택 창 (처음 열 때 만들고 재사용)
var _export_dialog: EditorFileDialog
## 내보내기 결과 안내 창
var _export_result: AcceptDialog


## 플러그인이 켜질 때: 도구 메뉴에 항목 추가.
func _enter_tree() -> void:
	add_tool_menu_item(MENU, _open)
	add_tool_menu_item(MENU_EXPORT, _open_export)


## 플러그인이 꺼질 때: 메뉴 항목과 만들어 둔 창들을 정리.
func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	remove_tool_menu_item(MENU_EXPORT)
	for d in [_file_dialog, _confirm, _error, _export_dialog, _export_result]:
		if d:
			d.queue_free()


## 내보내기 메뉴를 눌렀을 때: 저장 위치 선택 창을 연다.
## ACCESS_FILESYSTEM 이라 프로젝트 밖(다운로드 폴더 등)에도 저장할 수 있다.
func _open_export() -> void:
	if _export_dialog == null:
		_export_dialog = EditorFileDialog.new()
		_export_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_export_dialog.title = "카드 내보내기 zip 저장"
		_export_dialog.add_filter("*.zip", "카드 내보내기")
		_export_dialog.current_file = EXPORT_FILE_NAME
		_export_dialog.file_selected.connect(_on_export_file_selected)
		EditorInterface.get_base_control().add_child(_export_dialog)
	_export_dialog.popup_file_dialog()


## 저장 위치를 골랐을 때: zip 을 만들고 결과를 알려 준다.
func _on_export_file_selected(path: String) -> void:
	var exporter := CardExporter.new()
	var err := exporter.write_zip(path)
	if _export_result == null:
		_export_result = AcceptDialog.new()
		EditorInterface.get_base_control().add_child(_export_result)
	_export_result.title = "카드 내보내기 실패" if not err.is_empty() else "카드 내보내기"
	_export_result.dialog_text = err if not err.is_empty() else _describe_export(exporter, path)
	# 저장 창이 닫힌 뒤에 띄운다. 저장 창이 열려 있으면 Godot 이 새 창을 거부한다 (exclusive child 오류).
	_export_result.popup_centered.call_deferred()


## 내보내기 결과를 안내 창에 보여줄 글로 바꾼다. 파일이 없어 빠진 그림이 있으면 목록을 덧붙인다.
func _describe_export(exporter: CardExporter, path: String) -> String:
	var lines := PackedStringArray()
	lines.append("저장했어요: %s" % path)
	lines.append("웹 카드 에디터의 '가져오기' 버튼으로 이 zip 을 넣으세요.")
	if not exporter.missing_art.is_empty():
		lines.append("")
		lines.append("⚠ 파일이 없어 빠진 그림 %d개: %s" % [exporter.missing_art.size(), _names(exporter.missing_art)])
	return "\n".join(lines)


## 메뉴를 눌렀을 때: zip 선택 창을 연다.
## ACCESS_FILESYSTEM 이라 프로젝트 밖(다운로드 폴더 등)의 zip 도 고를 수 있다.
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


## zip 을 골랐을 때: 읽어 보고, 문제가 없으면 미리보기 창을 띄운다.
func _on_file_selected(path: String) -> void:
	_importer = CardImporter.new()
	var err := _importer.read_zip(path)
	if not err.is_empty():
		_show_error(err)
		return
	_equipment = EquipmentImporter.new()
	_equipment.load_export(_importer.get_data(), _importer.get_art())
	if _confirm == null:
		_confirm = ConfirmationDialog.new()
		_confirm.title = "카드 가져오기"
		_confirm.ok_button_text = "적용"
		_confirm.confirmed.connect(_on_confirmed)
		EditorInterface.get_base_control().add_child(_confirm)
	_confirm.dialog_text = _describe(_importer.preview()) + "\n\n" + _describe_equipment(_equipment.preview())
	_confirm.popup_centered()


## "적용"을 눌렀을 때: 파일을 쓰고, 에디터가 새 파일을 인식하도록 다시 스캔한다.
func _on_confirmed() -> void:
	_importer.apply()
	_equipment.apply()
	EditorInterface.get_resource_filesystem().scan()
	print("[Card Importer] 가져오기 완료")


## 미리보기 결과(CardImporter.preview())를 확인 창에 보여줄 글로 바꾼다.
## 삭제될 카드 중 Godot 에서 효과를 붙인 카드는 ⚠ 로 표시하고 경고 문구를 덧붙인다.
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


## 장비 미리보기 결과(EquipmentImporter.preview())를 확인 창 글로 바꾼다.
## ⚠ = Godot 에서 붙인 상태도 함께 지워지는 장비. 착용 중인 장비는 지우지 않고 남긴다는 줄을 따로 보여준다.
func _describe_equipment(p: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("[장비]")
	lines.append("추가 %d개: %s" % [p.added.size(), _names(p.added)])
	lines.append("갱신 %d개: %s" % [p.updated.size(), _names(p.updated)])
	var removed := PackedStringArray()
	var warn := false
	for r in p.removed:
		removed.append(("⚠ " if r.has_statuses else "") + r.name)
		warn = warn or r.has_statuses
	lines.append("삭제 %d개: %s" % [removed.size(), _names(removed)])
	if not p.kept.is_empty():
		var kept := PackedStringArray()
		for k in p.kept:
			kept.append("%s(%s)" % [k.name, ", ".join(k.units)])
		lines.append("착용 중이라 남김 %d개: %s" % [kept.size(), _names(kept)])
	if warn:
		lines.append("⚠ 표시된 장비는 Godot에서 붙인 상태도 함께 삭제됩니다.")
	return "\n".join(lines)


## 이름 목록을 "a, b, c 외 N장" 형태로. 비어 있으면 "-".
func _names(names: PackedStringArray) -> String:
	if names.is_empty():
		return "-"
	var shown := names.slice(0, MAX_NAMES)
	var text := ", ".join(shown)
	if names.size() > MAX_NAMES:
		text += " 외 %d장" % (names.size() - MAX_NAMES)
	return text


## 오류 안내 창을 띄운다.
func _show_error(msg: String) -> void:
	if _error == null:
		_error = AcceptDialog.new()
		_error.title = "카드 가져오기 실패"
		EditorInterface.get_base_control().add_child(_error)
	_error.dialog_text = msg
	_error.popup_centered()
