@tool
class_name CardData
extends Resource
## 카드 한 장. 위쪽 필드는 웹 카드 에디터가 담당(가져오기 때 덮어씀),
## costs / conditions / effects 는 Godot 에서 조합(가져오기 때 유지).

@export_group("웹 에디터")
@export var id: String
@export var deck_id: String
@export var name_ko: String
@export var name_en: String
@export_multiline var description_ko: String
@export_multiline var description_en: String
@export var sp: int = 1
@export var cost: int = 0
@export_enum("attack", "skill", "special", "enemy") var category: String = "attack"
@export_enum("melee", "ranged", "ally", "self") var attack_type: String = "melee"
@export var area: Array[Vector2i] = []
@export var keywords: PackedStringArray = []
@export_file("*.png", "*.jpg", "*.webp", "*.gif") var art: String
@export var upgrades: Array[CardData] = []

@export_group("Godot")
@export var costs: Array[CardCost] = []
@export var conditions: Array[CardCondition] = []
@export var effects: Array[CardEffect] = []
