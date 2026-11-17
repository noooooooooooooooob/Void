class_name ShopData
extends Resource
## 상점 설정: 가격과 진열 개수. shop/shop_data.tres 하나를 상점 화면이 쓴다 — 숫자는 인스펙터에서 바꾼다.
## 가격은 모두 고정이고 이용할수록 오르지 않는다 (상점 설계 2026-11-17 사용자 결정).
## 처음 값은 Claude 가 정한 임시 값 (사용자 위임, 2026-11-17).

@export_group("가격 (공허 조각)")
## 진열 카드 한 장 구매
@export var card_price: int = 50
## 진열 소비 아이템 하나 구매
@export var item_price: int = 30
## 덱에서 카드 한 장 제거
@export var remove_price: int = 75
## 카드 한 장 강화 (강화 카드 하나로 바꾸기)
@export var upgrade_price: int = 60

@export_group("진열")
## 진열 카드 수 (후보가 적으면 있는 만큼)
@export var card_count: int = 5
## 진열 소비 아이템 수 (후보가 적으면 있는 만큼)
@export var item_count: int = 3
