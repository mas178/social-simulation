;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ----------------------------------------------------------------TÍTULO
;; ----------------------------------------------------------------"TÍTULO" is an agent-based model designed to
;; study cooperative calls for beached whales.
;; Copyright (C) 2015
;; -----------------------------------------------------------------AUTORES
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


;;;;;;;;;;;;;;
;;; BREEDS ;;;
;;;;;;;;;;;;;;

breed [people person]

;;;;;;;;;;;;;;;;;
;;; VARIABLES ;;;
;;;;;;;;;;;;;;;;;

globals [
  ;; to stress the system

  ;prob-resource                 ;; probability of obtaining a unit of resource
  ;min-energy                    ;; minimun energy a person requires to survive
  energy                         ;; energy of a unit of resource

  ;n-people                      ;; number of people
  generation                     ;; current generation
  n-rounds
  ;rounds-per-generation         ;; number of rounds per generation
  ; avgFitness                     ;; average fitness after the last generation
  ; sdFitness
  ; avgGivenEnergy
  ; sdGivenEnergy
  ; history-size                   ;; number of generations for the stop condition
  ; distribution-given-energy
  ; history-distribution

  ;; Interactive/batch runs
  interactive-run?               ;; update World window ?
]

people-own [
  ; strategy
  given-energy                   ;; percentage of energy the person donates to others
  correlation                    ;; [-1,1] whicht type of person this agent donates to (+1 the most cooperative; 0 equally distributed; -1 the least cooperative)

  get-resource?                  ;; Boolean: 1 implies the agent got resource, 0 the opposite
  energy-consumed                ;; own consumption each tick
  n-get-resource                 ;; # times the agent get resource by its own
  fitness                        ;; # times the agent fulfilled energy requirements (energy-consumed > min-energy)
]

;;;;;;;;;;;;;;;;;;;
;;; MODEL SETUP ;;;
;;;;;;;;;;;;;;;;;;;

to startup [interactive?]
  clear-all
  set-default-shape people "person"
  set interactive-run? interactive?
  reset-ticks
  load-experiment
  create-agents
  set n-rounds 0
  set generation 0
  set energy 1
  ; set avgFitness 0
  ; set sdFitness 0
  ; set avgGivenEnergy 0
  ; set sdGivenEnergy 0
  ; set history-size 100
  ; set distribution-given-energy map [i -> count people with [given-energy <= i] / n-people] n-values 11 [ i -> i / 10]
  ; set history-distribution []
  ; set history-distribution fput distribution-given-energy history-distribution

end

to create-agents
  create-people n-people [
    set given-energy random-float 1
    set correlation -1 + random-float 2 ;; [-1,1]
    set energy-consumed 0
    set n-get-resource 0
    set fitness 0
    set get-resource? false
    set color scale-color orange given-energy 0 1
    set size 1
    setxy random-xcor random-ycor
  ]
end

;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN PROCEDURE ;;;
;;;;;;;;;;;;;;;;;;;;;;

to go
  get-resources
  share
  update-fitness

  ; people select best strategies
  ifelse (n-rounds >= rounds-per-generation)
  [
    ; compute-statistics
    select-strategies
    set n-rounds 0
    set generation generation + 1
  ]
  [ set n-rounds n-rounds + 1]

  tick
end

to go-generation
  repeat rounds-per-generation [go]
  select-strategies
  set n-rounds 0
  set generation generation + 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; OBSERVER'S PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to get-resources
  ask people [
    if random-float 1 < prob-resource [
      set get-resource? true
      ;; initially the agent get the full resource, and later maybe she shares if there is someone to share with
      set energy-consumed energy
      set n-get-resource n-get-resource + 1
    ]
  ]
end


to update-fitness
  ask people [
    if energy-consumed > min-energy [set fitness fitness + 1]

    ;; initialize set energy-consumed to zero
    set energy-consumed 0
  ]
end

to select-strategies
  ask people[
    let competitors n-of round ( strategy-tournament-size * n-people) people

    ;; if there is a tie, "max-one-of" chooses randomly
    let the-one max-one-of competitors [fitness]

    if [fitness] of the-one > fitness [
      ;; copy strategy
      set given-energy [given-energy] of the-one
      set correlation [correlation] of the-one]

    ;; mutation
    if random-float 1.0 < prob-mutation [
      set given-energy random-float 1
      set correlation -1 + random-float 2
    ]
  ]

  ;; update people colour just for fun
  ask people [
    ;; initialize fitness
    set fitness 0
    ;; update colour just for fun
    set color scale-color orange given-energy 0 1
    ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PEOPLE'S PROCEDURES ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to share
  ;; the maximum number of receivers is the maximum number of people without resource
  let n-sharing min list round (sharing-tournament-size * n-people) (count people with [get-resource? = false])

  ask people with [get-resource? = true]
    [
      ifelse any? people with [get-resource? = false] [
        let receivers n-of (min list (n-sharing) (count people with [get-resource? = false])) people with [get-resource? = false]
        let my-receiver one-of receivers ;; correlation 0
        ifelse (correlation > 0)
        ;; correlation > 0
        [ if random-float 1 < correlation [set my-receiver max-one-of receivers [given-energy]]]
        ;; correlation < 0
        [ if random-float 1 < -1 * correlation [set my-receiver min-one-of receivers [given-energy]]]
        if my-receiver != nobody
        [  let donated-energy (given-energy * energy)
          set energy-consumed energy-consumed - donated-energy ;; antes hay que añadir energy siempre que se obtenga recurso (M) Ok, estaba :)
          ask my-receiver [
            set energy-consumed energy-consumed + donated-energy
            if (energy-consumed > min-energy) [set get-resource? true]
          ]
        ]
      ]
      [ stop ]
    ]
  ;; initialization for next tick
  ask people [
    set get-resource? false
  ]
end

to-report max-items [the-list]
  report max map [ ?1 -> count-items ?1 the-list ] remove-duplicates the-list
end

to-report count-items [i the-list]
  report length filter [ ?1 -> ?1 = i ] the-list
end


; to compute-statistics
  ; set avgFitness mean [fitness] of people
  ; set sdFitness standard-deviation [fitness] of people
  ; set avgGivenEnergy mean [given-energy] of people
  ; set sdGivenEnergy standard-deviation [given-energy] of people
  ; set distribution-given-energy map [x -> count people with [given-energy <= x] / n-people] n-values 11 [y ->  y / 10]
  ; set history-distribution fput distribution-given-energy history-distribution
  ; if length history-distribution > history-size [ set history-distribution but-last history-distribution ] ;; 100 last generation values
; end

to-report stop-cond
  report ticks > 5000
end

; called from behavior space
;to-report variation
;  let last100_pe_stdv []
;  foreach n-values 11 [?]
;  [  let i ?
;    set last100_pe_stdv fput ( standard-deviation map [item i (item ? history-distribution)] n-values history-size [?] ) last100_pe_stdv
;  ]
;  report last100_pe_stdv
;end
; to-report variation
;   let last100_pe_stdv []
;   foreach n-values 11 [i -> i]
;   [
;     x -> set last100_pe_stdv fput ( standard-deviation map [y -> item x (item y history-distribution)] n-values history-size [i -> i] ) last100_pe_stdv
;   ]
;   report last100_pe_stdv
; end

to load-experiment
  ;let FilePath "C:/Users/user/Dropbox/UBU/SimulPast/Paper-densidad recursos poblacion/modelo/NewModel/LHS experiments/input_files/"
  ;let filename word FilePath word "experiment" word exp-number ".csv"
  let filename (word "./input_files/experiment" exp-number ".csv")
  file-open filename
  while [not file-at-end?]
  [
    let name file-read-line
    set n-people file-read
    set prob-resource file-read
    set min-energy file-read
    set sharing-tournament-size file-read
    set strategy-tournament-size file-read
    set prob-mutation file-read
    set rounds-per-generation file-read
    let dontwantit file-read-line
  ]
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
319
10
756
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
16
10
90
43
setup
startup true
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
93
10
202
43
go one generation
go-generation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
204
10
299
43
go
go-generation
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
23
125
281
143
-- Stressing parameters --
15
0.0
1

SLIDER
17
147
307
180
prob-resource
prob-resource
0
1
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
17
181
308
214
min-energy
min-energy
0
1
0.8
0.01
1
NIL
HORIZONTAL

SLIDER
16
76
306
109
n-people
n-people
0
1000
300.0
1
1
NIL
HORIZONTAL

TEXTBOX
21
223
171
242
-- Sharing strategy --
15
0.0
1

SLIDER
18
242
309
275
sharing-tournament-size
sharing-tournament-size
0
1
0.01
0.1
1
NIL
HORIZONTAL

TEXTBOX
19
299
248
317
-- Evolutionary dynamics --
15
0.0
1

SLIDER
17
318
308
351
strategy-tournament-size
strategy-tournament-size
0
1
0.01
0.1
1
NIL
HORIZONTAL

TEXTBOX
21
55
171
74
-- Population --
15
0.0
1

SLIDER
17
353
308
386
prob-mutation
prob-mutation
0
1
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
17
387
308
420
rounds-per-generation
rounds-per-generation
0
100
10.0
1
1
NIL
HORIZONTAL

PLOT
759
10
960
130
Given energy of people
NIL
NIL
0.0
10.0
0.0
300.0
true
false
"" ""
PENS
"default" 1.0 1 -8053223 true "" "histogram sort [10 * precision given-energy 1] of people"

MONITOR
760
131
859
176
generation
generation
0
1
11

INPUTBOX
760
177
833
237
exp-number
9.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

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
  <experiment name="4 escenarios 30 rep" repetitions="30" runMetricsEveryStep="false">
    <setup>startup true</setup>
    <go>go</go>
    <timeLimit steps="50000"/>
    <exitCondition>stop-cond</exitCondition>
    <metric>ticks</metric>
    <metric>[given-energy] of people</metric>
    <metric>[correlation] of people</metric>
    <metric>distribution-given-energy</metric>
    <metric>max variation</metric>
    <metric>variation</metric>
    <metric>avgFitness</metric>
    <metric>sdFitness</metric>
    <metric>avgGivenEnergy</metric>
    <metric>sdGivenEnergy</metric>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.2"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-energy">
      <value value="0.2"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="4 escenarios 30 rep NoSTOP" repetitions="30" runMetricsEveryStep="false">
    <setup>startup true</setup>
    <go>go</go>
    <timeLimit steps="35000"/>
    <metric>distribution-given-energy</metric>
    <metric>max variation</metric>
    <metric>variation</metric>
    <metric>avgFitness</metric>
    <metric>sdFitness</metric>
    <metric>avgGivenEnergy</metric>
    <metric>sdGivenEnergy</metric>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.2"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-energy">
      <value value="0.2"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="1 escenarios 10 rep" repetitions="1" runMetricsEveryStep="false">
    <setup>startup true</setup>
    <go>go</go>
    <timeLimit steps="50000"/>
    <exitCondition>stop-cond</exitCondition>
    <metric>ticks</metric>
    <metric>[given-energy] of people</metric>
    <metric>[correlation] of people</metric>
    <metric>distribution-given-energy</metric>
    <metric>max variation</metric>
    <metric>variation</metric>
    <metric>avgFitness</metric>
    <metric>sdFitness</metric>
    <metric>avgGivenEnergy</metric>
    <metric>sdGivenEnergy</metric>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-energy">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient" repetitions="5" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go</go>
    <timeLimit steps="50000"/>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <metric>standard-deviation [given-energy] of people</metric>
    <metric>standard-deviation [correlation] of people</metric>
    <steppedValueSet variable="prob-resource" first="0.2" step="0.1" last="0.8"/>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="tss1" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>repeat 500 [go]</go>
    <timeLimit steps="100"/>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <metric>standard-deviation [given-energy] of people</metric>
    <metric>standard-deviation [correlation] of people</metric>
    <metric>mean [fitness] of people</metric>
    <metric>standard-deviation [fitness] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.7"/>
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.3" step="0.1" last="0.7"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="tss2" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>repeat 500 [go]</go>
    <timeLimit steps="100"/>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <metric>standard-deviation [given-energy] of people</metric>
    <metric>standard-deviation [correlation] of people</metric>
    <metric>mean [fitness] of people</metric>
    <metric>standard-deviation [fitness] of people</metric>
    <steppedValueSet variable="prob-resource" first="0.3" step="0.1" last="0.7"/>
    <enumeratedValueSet variable="min-energy">
      <value value="0.7"/>
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-02-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-03-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-04-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.4"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-05-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-06-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.6"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-07-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.7"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Gradient-08-30" repetitions="30" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <exitCondition>ticks = 50000</exitCondition>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <enumeratedValueSet variable="prob-resource">
      <value value="0.8"/>
    </enumeratedValueSet>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="LHS" repetitions="1" runMetricsEveryStep="true">
    <setup>startup true</setup>
    <go>go-generation</go>
    <timeLimit steps="5000"/>
    <metric>ticks</metric>
    <metric>mean [given-energy] of people</metric>
    <metric>mean [correlation] of people</metric>
    <steppedValueSet variable="exp-number" first="1" step="1" last="25"/>
  </experiment>
  <experiment name="論文の再現" repetitions="30" runMetricsEveryStep="false">
    <setup>startup true</setup>
    <go>go</go>
    <timeLimit steps="50000"/>
    <exitCondition>stop-cond</exitCondition>
    <metric>ticks</metric>
    <metric>[given-energy] of people</metric>
    <metric>[correlation] of people</metric>
    <enumeratedValueSet variable="prob-mutation">
      <value value="0.01"/>
    </enumeratedValueSet>
    <steppedValueSet variable="prob-resource" first="0.2" step="0.1" last="0.8"/>
    <steppedValueSet variable="min-energy" first="0.2" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="n-people">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sharing-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="strategy-tournament-size">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rounds-per-generation">
      <value value="10"/>
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
