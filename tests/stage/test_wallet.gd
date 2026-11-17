extends GutTest
# 공허 조각 지갑: 더하기·지불, 모자라면 실패.

func test_starts_empty():
	assert_eq(Wallet.new().shards, 0)

func test_pay_fails_when_short():
	var w := Wallet.new()
	w.add(30)
	assert_false(w.can_pay(50))
	assert_false(w.pay(50))
	assert_eq(w.shards, 30)
	assert_true(w.pay(30))
	assert_eq(w.shards, 0)

func test_add_ignores_negative():
	var w := Wallet.new()
	w.add(-5)
	assert_eq(w.shards, 0)
