class_name Wallet
extends RefCounted
## 공허 조각 지갑. 의뢰 안에서만 쓰는 재화를 담는다 (StageRun.wallet — 의뢰가 끝나면 새 지갑으로 0).
## 전투 승리 보상(BattleData.shard_reward)으로 채우고, 상점(Shop)이 거래할 때 지불한다.
## 순수 로직 — 화면은 shards 를 읽어 보여 주기만 한다.

## 가진 공허 조각 수 (0 이상)
var shards: int = 0


## 조각을 n 개 더한다. 0 이하는 무시한다.
func add(n: int) -> void:
	if n > 0:
		shards += n


## n 개를 낼 수 있는지
func can_pay(n: int) -> bool:
	return shards >= n


## n 개를 낸다. 모자라면 아무것도 바꾸지 않고 false.
func pay(n: int) -> bool:
	if not can_pay(n):
		return false
	shards -= n
	return true
