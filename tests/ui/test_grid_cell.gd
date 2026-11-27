extends GutTest
# 격자 칸 그림 (2026-11-27): 칸은 Art/ui/grid_cell.png(흰 테두리, 안 투명)로 그린다.

const CELL := "res://Scenes/ui/battle_screen/grid_cell.tscn"

func test_cell_scene_uses_grid_cell_art():
	var c = load(CELL).instantiate()
	autofree(c)
	assert_not_null(c.cell_texture)
	assert_true(c.cell_texture.resource_path.ends_with("Art/ui/grid_cell.png"))

# 그림을 사각형 네 꼭짓점에 펴서 그린다: 왼쪽 위부터 시계 방향 = uv (0,0) (1,0) (1,1) (0,1)
func test_quad_uvs_follow_corner_order():
	assert_eq(GridCell.quad_uvs(), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))

func test_board_cells_inherit_texture():
	var b = load("res://Scenes/ui/battle_screen/battle_board.tscn").instantiate()
	add_child_autofree(b)
	assert_eq(b.get_node("Cell_2_2").cell_texture, load("res://Art/ui/grid_cell.png"))
