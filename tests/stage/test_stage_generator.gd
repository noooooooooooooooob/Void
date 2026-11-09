extends GutTest

func _gen(seed_value: int) -> Array[StageNode]:
	return StageGenerator.new(seed_value).generate()

func test_shape():
	var nodes := _gen(1)
	assert_eq(nodes.size(), 12)
	assert_eq(nodes[0].kind, StageNode.Kind.START)
	assert_eq(nodes[-2].kind, StageNode.Kind.SHOP)
	assert_eq(nodes[-1].kind, StageNode.Kind.BOSS)

func test_same_seed_same_map():
	var a := _gen(7)
	var b := _gen(7)
	for i in a.size():
		assert_eq(a[i].kind, b[i].kind)
		assert_eq(a[i].next.size(), b[i].next.size())

func test_rules_hold_for_200_maps():
	for s in range(1, 201):
		var nodes := _gen(s)
		var mid := nodes.slice(1, 10)
		var shop := nodes[-2]
		# 전투 6 / 이벤트 3, 한 행에 이벤트 최대 2
		assert_eq(mid.filter(func(n): return n.kind == StageNode.Kind.BATTLE).size(), 6, "seed %d" % s)
		for r in 3:
			var events := mid.filter(func(n): return n.row == r and n.kind == StageNode.Kind.EVENT).size()
			assert_lte(events, 2, "seed %d row %d" % [s, r])
		# 첫 열은 모두 전투
		for n in mid:
			if n.column == 1:
				assert_eq(n.kind, StageNode.Kind.BATTLE, "seed %d first column" % s)
		# 시작은 3갈래
		assert_eq(nodes[0].next.size(), 3, "seed %d" % s)
		for n in mid:
			# 들어오는 길이 있음
			assert_gt(nodes.filter(func(p): return n in p.next).size(), 0, "seed %d" % s)
			if n.column < 3:
				# 1~2갈래, 바로 옆 행까지만
				assert_between(n.next.size(), 1, 2, "seed %d" % s)
				for m in n.next:
					assert_lte(absi(m.row - n.row), 1, "seed %d" % s)
			else:
				# 마지막 열은 상점으로
				assert_eq(n.next.size(), 1, "seed %d" % s)
				assert_eq(n.next[0], shop, "seed %d" % s)
		# 엇갈리는 길 없음
		for a in mid:
			for b in mid:
				if a.column == b.column and a.row < b.row:
					for x in a.next:
						for y in b.next:
							assert_false(x.row > y.row, "seed %d crossing" % s)
