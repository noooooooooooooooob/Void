extends GutTest

func test_constants():
	assert_eq(BattleTypes.GRID_ROWS, 3)
	assert_eq(BattleTypes.GRID_COLS, 4)
	assert_eq(BattleTypes.CHAIN_LIMIT, 10)
	assert_eq(BattleTypes.DEFAULT_DRAW, 5)
