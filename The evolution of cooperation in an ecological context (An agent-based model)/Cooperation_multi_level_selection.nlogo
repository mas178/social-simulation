globals [
  ; UIで設定される牛に関するGlobal変数
  ; initial-cows: 牛の数 (default: 40)
  ; cooperative-probability: 協力的な牛の割合 (default: 0.5)
  ; metabolism: 牛が1Stepで失うエネルギー (default: 2)
  ; reproduction-threshold: 繁殖力の閾値 (default: 100)

  ; UIで設定される草に関するGlobal変数
  ; minimal-number-of-grass: 草の最小数 (default: 500)
  ; patch-width: 草地の幅 (default: 3)
  ; gap-width: 空白地帯の幅 (default: 2)
  ; max-grass-height: 草の成長の上限 (default: 10)

  ; patch-width と gap-width の和
  patch-gap-width

  ; 1辺当りの草の数
  grass-count

  ; 1辺当りのパッチサイズ
  world-size

  ; 1辺当りのグループ数
  group-count
]

turtles-own [ energy ]
patches-own [ grass ]

breed [cooperative-cows cooperative-cow]
breed [greedy-cows greedy-cow]

to setup
  clear-all
  setup-grasses
  setup-cows
  reset-ticks
end

to setup-grasses
  print("### setup-grasses ###")
  set grass-count ceiling sqrt minimal-number-of-grass
  set group-count ceiling (grass-count / patch-width)
  set patch-gap-width patch-width + gap-width
  set world-size group-count * patch-gap-width

  print(word "grass-count=" grass-count ", group-count=" group-count ", world-size=" world-size)

  resize-world 0 (world-size - 1) 0 (world-size - 1)

  ask patches [
    ifelse gap-width = 0 [
      set grass random-float max-grass-height
      color-grass
    ] [
      if (pxcor mod patch-gap-width >= 1) and (pxcor mod patch-gap-width <= patch-width) and (pycor mod patch-gap-width >= 1) and (pycor mod patch-gap-width <= patch-width) [
        set grass random-float max-grass-height
        color-grass
      ]
    ]
  ]
end

to setup-cows
  print("### setup-cows ###")
  set-default-shape turtles "cow"   ;; applies to both breeds

  ; 草が生えているパッチをランダムにinitial-cows個選択する
  let init-patches n-of initial-cows patches with [ grass > 0 ]

  ; 選択したパッチに牛を配置する
  ask init-patches [
    sprout 1 [
      ; 牛にはゼロからreproduction-thresholdまでの一様な乱数として選ばれたエネルギーレベルが与えられる
      set energy random-float reproduction-threshold

      ; 一旦全ての牛を非協力的な牛として定義する
      set breed greedy-cows
      set color sky - 2
    ]
  ]

  ; cooperative-probabilityで与えられた比率の牛を協力的な牛にする
  ask n-of (initial-cows * cooperative-probability) turtles [
    set breed cooperative-cows
    set color red - 1.5
  ]
end

to go
  ask turtles [
    if mode = "Alarm calling" [
      attacked
    ]

    move
    eat
    reproduce
    if energy < 0 [ die ]
    reset-perspective
  ]

  ask patches [
    ifelse gap-width = 0 [
      grow-grass
      color-grass
    ] [
      if (pxcor mod patch-gap-width >= 1) and (pxcor mod patch-gap-width <= patch-width) and (pycor mod patch-gap-width >= 1) and (pycor mod patch-gap-width <= patch-width) [
        grow-grass
        color-grass
      ]
    ]
  ]

  tick
end

;--------------
; Cow
;--------------
to move
  move-to patch-here  ;; パッチの中心へ移動

  ; 自分の周りの空白パッチのリスト
  let empty-patches (filter [p -> not any? turtles-on p] (sort neighbors))

  ; 自分の周りの空白パッチのリストの中で、grassが最大のパッチ
  let empty-and-abundant-patch max-one-of (patch-set empty-patches) [grass]

  ; empty-and-abundant-patchが存在し、metabolism以上のエネルギーを持っていればそこに移動する
  ifelse (empty-and-abundant-patch != nobody) and ([grass] of empty-and-abundant-patch >= metabolism) [
    move-to empty-and-abundant-patch
  ][
    ; ランダムに選ばれた隣接セルの中で誰もいないセルに移動する
    if (not empty? empty-patches) [
      move-to one-of empty-patches
    ]
  ]

  ; 移動の有無に関わらずエネルギーを消費する
  set energy energy - metabolism
end

to eat
  ifelse (mode = "Feeding restraint") and (breed = cooperative-cows) [
    set energy energy + grass * 0.5
    set grass grass * 0.5
  ] [
    set energy energy + grass * 0.99
    set grass grass * 0.01
  ]
end

to reproduce
  if energy > reproduction-threshold [
    ; print("### reproduce ###")
    ; show (word "parent (" xcor ", " ycor ", " energy ")")

    ; 子の初期エネルギー値
    ; let init-energy random-float reproduction-threshold
    let init-energy 50

    ; 出産
    hatch 1 [
      ; 子の初期エネルギーを設定する
      set energy init-energy

      ; 子の位置を設定する
      let empty-patches (filter [p -> not any? turtles-on p] (sort neighbors))
      ifelse empty? empty-patches [
        die
      ][
        move-to one-of empty-patches
      ]
      ; show (word "child (" xcor ", " ycor ", " energy ")")
    ]

    ; 親のエネルギーを子の初期エネルギー分減らす
    set energy energy - init-energy
    ; show (word "parent (" xcor ", " ycor ", " energy ")")
  ]
end

to attacked
  if random-float 1 < 0.02 [
    ; ターゲットの半径5以内の協力的な牛を協力者(アラームコーラー)とする
    let cooperators filter [ t -> (distance t <= 5) and (self != t) and ([breed] of t = cooperative-cows) ] (sort turtles)

    let target-and-cooperators (fput self cooperators)

    ; 殺される可能性
    let prob-killed 1 / length target-and-cooperators

    ; ターゲットと協力者の中からランダムに選ばれた1頭がprob-killedの確率で殺される
    ask one-of target-and-cooperators [ if random-float 1 < prob-killed [die]]
  ]
end

to-report end-cond
  report (count cooperative-cows = 0) or (count greedy-cows = 0)
end

;--------------
; Grass
;--------------
to grow-grass
  ifelse mode = "Feeding restraint" [
    set grass (grass + 0.2 * grass * (max-grass-height - grass) / max-grass-height)
  ] [
    set grass min list (grass + 1) max-grass-height
  ]
end

to color-grass
  set pcolor scale-color (green - 1) grass 0 (2 * max-grass-height)
end
@#$#@#$#@
GRAPHICS-WINDOW
370
33
918
582
-1
-1
15.0
1
10
1
1
1
0
1
1
1
0
35
0
35
1
1
1
ticks
3000.0

BUTTON
218
42
273
75
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
38
41
93
74
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
206
181
239
cooperative-probability
cooperative-probability
0
1.0
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
15
171
181
204
initial-cows
initial-cows
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
188
274
345
307
max-grass-height
max-grass-height
1
40
10.0
1
1
NIL
HORIZONTAL

SLIDER
15
273
181
306
reproduction-threshold
reproduction-threshold
0.0
200.0
100.0
1.0
1
NIL
HORIZONTAL

SLIDER
15
239
181
272
metabolism
metabolism
0.0
99.0
2.0
1.0
1
NIL
HORIZONTAL

PLOT
23
327
336
507
Cows over time
Time
Cows
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"greedy" 1.0 0 -14985354 true "" "plot count greedy-cows"
"cooperative" 1.0 0 -6675684 true "" "plot count cooperative-cows"

MONITOR
24
518
169
575
# greedy cows
count greedy-cows
1
1
14

MONITOR
190
518
334
575
# cooperative cows
count cooperative-cows
1
1
14

SLIDER
188
172
346
205
minimal-number-of-grass
minimal-number-of-grass
0
1000
500.0
1
1
NIL
HORIZONTAL

SLIDER
188
206
344
239
patch-width
patch-width
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
188
240
343
273
gap-width
gap-width
0
10
2.0
1
1
NIL
HORIZONTAL

TEXTBOX
192
151
342
169
Grass:
11
0.0
1

CHOOSER
14
100
168
145
mode
mode
"-" "Feeding restraint" "Alarm calling"
2

TEXTBOX
19
153
169
171
Cow:
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

## HOW IT WORKS

## HOW TO USE IT

## THINGS TO NOTICE

## THINGS TO TRY

## EXTENDING THE MODEL

## NETLOGO FEATURES

## RELATED MODELS

## CREDITS AND REFERENCES

## HOW TO CITE

## COPYRIGHT AND LICENSE
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100000"/>
    <exitCondition>end-cond</exitCondition>
    <metric>count cooperative-cows</metric>
    <metric>count greedy-cows</metric>
    <steppedValueSet variable="stride-length" first="0.02" step="0.01" last="0.06"/>
    <steppedValueSet variable="metabolism" first="4" step="1" last="6"/>
    <steppedValueSet variable="reproduction-cost" first="70" step="5" last="90"/>
    <steppedValueSet variable="reproduction-threshold" first="90" step="10" last="110"/>
    <enumeratedValueSet variable="initial-cows">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cooperative-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-growth-chance">
      <value value="77"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-growth-chance">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-energy">
      <value value="51"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-grass-height">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-high-threshold">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="default parameters" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1500"/>
    <metric>count cooperative-cows</metric>
    <metric>count greedy-cows</metric>
    <enumeratedValueSet variable="low-high-threshold">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduction-threshold">
      <value value="102"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-cows">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cooperative-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-grass-height">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-growth-chance">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="high-growth-chance">
      <value value="77"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-energy">
      <value value="51"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="metabolism">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stride-length">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproduction-cost">
      <value value="54"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
