# 적 스프라이트 프롬프트 (전투 배경별 3종)

작성 2026-11-25 · 브랜치 `feat/enemy-sprites`
기준: 홍연 전투 그림 `Art/characters/hongyeon/hongyeon_idle.png` (128×128 칸 8개, 약 3등신 픽셀 아트, 진한 외곽선)
세계관 가정: 1920년대풍 도시 "DISTRICT 07" 의 공허 정화 사무소. 공허(Void) = 보라·검정 점액, 보랏빛으로 빛나는 균열, 깨진 거울 조각.
설정이 노션 세계관과 다르면 노션이 우선 — 이름·생김새는 그쪽에 맞춰 고친다.

## 공통 규칙 (게임에서 바로 쓰려면)

- 칸: **128×128 px**, 캐릭터 키 약 100px, **발은 칸 아래쪽 같은 높이** (칸마다 발이 흔들리면 서 있을 때 떠 보임)
- 방향: **왼쪽(아군 쪽)을 본다** — 전투 화면은 적 그림을 뒤집지 않는다
- 배경 투명, 글자 없음
- 강적은 같은 128 칸에 꽉 차게 그리고 게임에서 `battle_scale` 을 12~14 로 올려 키운다 (홍연 = 10)
- 애니메이션 (게임이 지금 쓰는 이름):
  - `idle` 4~8칸 반복 (숨쉬기·흔들림)
  - `hit` 3~4칸 한 번 (움찔·뒤로 젖힘)
  - 공격 1개 4~6칸 한 번 — 아래 각 적의 **공격 동작** 이름을 그대로 쓰면 적 카드 `animation` 칸에 연결하기 쉽다
  - (나중을 위해 있으면 좋음) `death` 쓰러짐

### 공통 프롬프트 (각 적 프롬프트 앞에 붙인다)

```
pixel art game sprite, single character, full body, side view facing left,
128x128 pixel canvas, character about 100 pixels tall, feet touching the bottom edge,
chibi proportions about 3 heads tall, crisp 1px dark outline, limited palette, flat cel shading,
transparent background, no text, no shadow on ground,
dark gothic 1920s occult city RPG, corrupted by the Void: violet-black ooze and glowing purple cracks
```

### 동작 시트 프롬프트 (공통 + 적 설명 + 아래 셋 중 하나를 붙여서, 동작마다 한 번씩 받는다)

```
idle:   sprite sheet, 8 frames in one horizontal row, each frame 128x128, same character in every frame,
        idle breathing loop, subtle body sway, feet stay at the same height in every frame
hit:    sprite sheet, 4 frames in one horizontal row, each frame 128x128, same character in every frame,
        hit reaction: flinches and recoils backwards then returns to the idle pose, feet stay planted
attack: sprite sheet, 6 frames in one horizontal row, each frame 128x128, same character in every frame,
        <아래 표의 공격 동작 영어 문구>, wind-up then strike toward the left then recover, feet stay at the same height
```

### 완성 예시 (결정에 먹힌 광부 — 공격 동작 시트)

```
pixel art game sprite, single character, full body, side view facing left,
128x128 pixel canvas, character about 100 pixels tall, feet touching the bottom edge,
chibi proportions about 3 heads tall, crisp 1px dark outline, limited palette, flat cel shading,
transparent background, no text, no shadow on ground,
dark gothic 1920s occult city RPG, corrupted by the Void: violet-black ooze and glowing purple cracks,
undead miner in worn overalls and a cracked lamp helmet, amethyst crystals growing from shoulders and arm,
hollow glowing violet eyes, holding a pickaxe,
sprite sheet, 6 frames in one horizontal row, each frame 128x128, same character in every frame,
raises the pickaxe overhead and slams it down in front, wind-up then strike toward the left then recover,
feet stay at the same height
```

한 번에 3개 동작이 잘 안 맞으면: 먼저 `idle` 첫 칸 한 장을 뽑아 마음에 드는 모습을 정하고, 그 그림을 참고 이미지로 넣은 채 `hit`·`attack` 시트를 받으면 모습이 덜 달라진다.

---

## 1. 자수정 광산 대장간 — `battle/amethyst_mine_forge.png`

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 수정 진드기 | 등에 자수정 결정이 박힌 딱정벌레만 한 벌레. 다리 6개, 결정 틈으로 보랏빛이 샌다 | `bite` 튀어 올라 물기 |
| 일반 | 결정에 먹힌 광부 | 낡은 작업복·깨진 램프 헬멧, 어깨와 팔에 자수정이 자라 있다. 눈은 텅 빈 보라빛. 곡괭이를 든다 | `swing` 곡괭이 내리찍기 |
| 강적 | 대장간 골렘 | 광석과 결정을 쌓아 만든 땅딸막한 거인. 가슴의 화로 핵이 주황·보라로 끓고, 한 팔은 모루처럼 뭉툭하다 | `slam` 모루 팔로 내려치기 |

```
수정 진드기: small beetle-like mite, six legs, amethyst crystal shards growing from its shell, violet light leaking from cracks
수정 진드기 공격 동작: leaps forward and bites with its mandibles
결정에 먹힌 광부: undead miner in worn overalls and a cracked lamp helmet, amethyst crystals growing from shoulders and arm, hollow glowing violet eyes, holding a pickaxe
결정에 먹힌 광부 공격 동작: raises the pickaxe overhead and slams it down in front
대장간 골렘: squat stocky golem made of dark ore and amethyst crystals, glowing forge core in its chest burning orange and violet, one arm shaped like a blunt anvil
대장간 골렘 공격 동작: lifts its anvil arm high and smashes it down
```

## 2. 푸른 거울 대성당 — `battle/dream_mirror_cathedral.png`

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 촛불 도깨비불 | 푸른 불꽃이 든 작은 등불이 떠다닌다. 등불 밑에 가느다란 손 두 개 | `flare` 불꽃 쏘기 |
| 일반 | 거울 사제 | 두건 쓴 사제, 얼굴 자리에 금 간 손거울. 거울 속엔 보는 사람이 비친다. 사슬 향로를 든다 | `chant` 향로 휘두르며 주문 |
| 강적 | 비친 기사 | 깨진 푸른 유리로 된 갑옷 기사. 몸 안이 비어 반대편이 비쳐 보이고, 유리 대검을 든다 | `cleave` 대검 가로베기 |

```
촛불 도깨비불: small floating lantern spirit with a blue flame inside, two thin ghostly hands under the lantern
촛불 도깨비불 공격 동작: the flame swells and shoots a blue fireball forward
거울 사제: hooded priest whose face is a cracked hand mirror reflecting the viewer, long dark robe with blue trim, swinging a chained censer
거울 사제 공격 동작: swings the chained censer in an arc while chanting, mirror face flashing
비친 기사: knight in armor made of shattered blue glass, hollow inside so you can see through it, holding a glass greatsword
비친 기사 공격 동작: wide horizontal cleave with the glass greatsword
```

## 3. 공허 거울 벌판 — `battle/void_mirror_expanse.png` (깊은 공허, 후반)

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 공허 사냥개 | 별이 박힌 검은 점액으로 된 네발짐승. 몸에 보라 균열, 얼굴은 입만 있다 | `pounce` 덮치기 |
| 일반 | 잔영 | 사람 모양의 그림자. 주위에 깨진 거울 조각이 천천히 돈다. 조각마다 다른 얼굴이 비친다 | `shard` 거울 조각 날리기 |
| 강적 | 틈새 감시자 | 화려한 거울 틀에 끼인 거대한 눈 하나가 떠 있다. 틀 아래로 보라 촉수가 늘어진다 | `gaze` 눈빛 광선 |

```
공허 사냥개: quadruped hound made of black starry ooze, glowing violet cracks across its body, eyeless face with only a wide mouth
공허 사냥개 공격 동작: crouches low then pounces forward
잔영: humanoid shadow silhouette, shattered mirror shards slowly orbiting around it, each shard reflecting a different face
잔영 공격 동작: flings orbiting mirror shards forward
틈새 감시자: giant floating eye set inside an ornate gilded mirror frame, violet void tendrils hanging below the frame
틈새 감시자 공격 동작: the eye narrows then fires a violet beam forward
```

## 4. 연보라 성 안뜰 — `battle/lilac_castle_courtyard.png`

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 시든 장미 덩굴 | 땅에서 솟은 가시 덩굴 뭉치. 끝에 시든 보라 장미 하나가 입처럼 벌어진다 | `lash` 덩굴 채찍 |
| 일반 | 빈 근위병 | 연보라 강철 갑옷만 남은 근위병. 투구 틈으로 공허 안개가 새고, 미늘창을 든다 | `thrust` 창 찌르기 |
| 강적 | 분수 가고일 | 분수대 석상이던 가고일. 돌 날개, 입과 눈에서 보랏빛 물이 흘러내린다 | `dive` 날아올라 덮치기 |

```
시든 장미 덩굴: cluster of thorny vines rising from the ground, one wilted violet rose at the tip opening like a mouth
시든 장미 덩굴 공격 동작: the vines whip forward like a lash
빈 근위병: empty suit of lilac steel castle guard armor animated by void mist leaking from the helmet slits, holding a halberd
빈 근위병 공격 동작: thrusts the halberd straight forward
분수 가고일: stone gargoyle from a castle fountain, stone wings, violet water dripping from its mouth and eyes
분수 가고일 공격 동작: spreads its stone wings, leaps up and dives forward
```

## 5. 산중 신사 테라스 — `battle/mountain_shrine_terrace.png`

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 종이 등롱 요괴 | 찢어진 종이 등롱에 눈 하나와 긴 혀. 깡충깡충 뛴다 | `lick` 혀 휘두르기 |
| 일반 | 원령 무녀 | 붉은 띠의 하얀 무녀복, 찢어진 부적이 몸에 붙어 있다. 눈에서 보라 눈물이 흐르고 방울 지팡이를 든다 | `curse` 부적 날리기 |
| 강적 | 금 간 수호 석상 | 신사 입구의 돌 사자개 석상. 몸에 보라 균열이 퍼지고 이끼와 붉은 끈이 감겨 있다 | `charge` 들이받기 |

```
종이 등롱 요괴: torn paper lantern creature with a single eye and a long tongue, hopping
종이 등롱 요괴 공격 동작: hops forward and lashes its long tongue
원령 무녀: ghostly shrine maiden in white robes with a red sash, torn paper talismans stuck to her body, violet tears, holding a staff with small bells
원령 무녀 공격 동작: shakes the bell staff and throws paper talismans forward
금 간 수호 석상: stone guardian lion-dog statue from a shrine gate, violet cracks spreading over its body, moss and red cord wrapped around it
금 간 수호 석상 공격 동작: lowers its head and charges forward
```

## 6. 네온 비 거리 — `battle/neon_rain_cyberpunk_street.png`

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 간판 미믹 | 부서진 네온 간판이 전선 다리로 걷는다. 글자 대신 깜빡이는 눈 | `zap` 전기 튀기기 |
| 일반 | 네온 깡패 | 비옷 입은 거리 깡패. 목과 팔에 분홍·청록 문신이 빛나고 쇠파이프를 든다 | `bash` 파이프 휘두르기 |
| 강적 | 우산 자객 | 긴 코트에 가면, 우산 속에 칼날을 숨겼다. 우산 안쪽이 분홍빛으로 빛난다 | `slash` 우산 칼 베기 |

```
간판 미믹: broken neon sign creature walking on dangling electric cable legs, flickering glowing eyes instead of letters
간판 미믹 공격 동작: sparks crackle and it fires an electric zap forward
네온 깡패: street thug in a wet raincoat, glowing pink and cyan tattoos on neck and arms, holding a steel pipe
네온 깡패 공격 동작: swings the steel pipe in a wide overhead arc
우산 자객: masked assassin in a long coat, blade hidden in an umbrella, pink glow inside the umbrella canopy
우산 자객 공격 동작: draws the blade from the umbrella and slashes forward
```

## 7. 황혼 공업 거리 — `battle/twilight_industrial_rift.png`

| 등급 | 이름 | 생김새 | 공격 동작 |
|---|---|---|---|
| 잡졸 | 매연 덩어리 | 그을음 구름 뭉치에 불씨 같은 눈 두 개. 몸에서 검댕이 떨어진다 | `puff` 매연 뿜기 |
| 일반 | 공장 망령 | 1920년대 공장 노동자, 방독면 틈으로 공허가 샌다. 멜빵바지, 커다란 렌치를 든다 | `whack` 렌치 내리치기 |
| 강적 | 증기 거한 | 등에 보일러를 지고 리벳 박힌 쇠팔을 단 거한. 가슴의 균열에서 보랏빛 증기가 뿜어진다 | `punch` 쇠팔 주먹 |

```
매연 덩어리: small blob of sooty smog with two ember-like glowing eyes, soot flakes falling from it
매연 덩어리 공격 동작: puffs up and blows a cloud of black smog forward
공장 망령: 1920s factory worker in overalls wearing a gas mask with void leaking from it, holding a large wrench
공장 망령 공격 동작: raises the wrench and whacks it down
증기 거한: hulking brute carrying a boiler on its back, riveted iron arm, violet steam bursting from a crack in its chest
증기 거한 공격 동작: pulls back the riveted iron arm and punches forward, steam venting
```

---

## 그림이 오면 (다음 단계)

1. 그림을 `Art/enemies/<영문 이름>/` 에 넣는다 (예: `Art/enemies/crystal_miner/crystal_miner_idle.png`)
2. 적마다 그림 묶음(SpriteFrames, `entities/units/<이름>_frames.tres`) 에 `idle`·`hit`·공격 동작을 넣는다
3. 적 유닛 데이터(`entities/units/`)의 `battle_frames`·`battle_scale`·`battle_pixel_art` 를 채우고, 적 카드의 `animation` 을 공격 동작 이름으로
