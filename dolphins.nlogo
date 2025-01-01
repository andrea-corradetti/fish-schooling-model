extensions [ dbscan table ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GLOBALS AND BREEDS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [fishes fish]
breed [dolphins dolphin]
breed [circles circle]
breed [fish-markers fish-marker]

directed-link-breed [chase-links chase-link]
undirected-link-breed [comm-links comm-link]

circles-own [
  owner
]

turtles-own [
  vision-range  ;; Distance at which agents detect others
]

fishes-own [
  schoolmates         ;; agentset of nearby fishes
  nearest-neighbor
  current-direction
  time-since-reproduction
  time-alive
  default-shape
]

dolphins-own [
  fish-eaten
  chasing-target
  communication-range
  fishes-in-range
]

fish-markers-own [
  owner
  fish-id          ;; The ID of the fish being tracked
  last-updated     ;; Tick when the position was last updated
]

globals [
  default-fish-speed
  default-dolphin-speed
  default-fish-count
  default-dolphin-count
  default-vision-range
  old-cluster-labeling
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SETUP AND DEFAULTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  set old-cluster-labeling false


  create-fishes initial-fish [
    set color blue
    set shape "fish"
    set default-shape "fish"
    set size 1
    set vision-range fish-vision-range
    set time-since-reproduction 0
    setxy random-xcor random-ycor
  ]

  create-dolphins initial-dolphins [
    if enable-debug [show word "Created with color " get-color-for who]
    set color get-color-for who
    set shape "shark"
    set size 1.5
    set vision-range dolphin-vision-range
    set fish-eaten 0
    set communication-range dolphin-communication-range
    setxy random-xcor random-ycor
  ]

  reset-ticks
end

;; Button procedure
to reset-defaults
  set fish-speed 1
  set dolphin-speed 1.5
  set initial-fish 50
  set initial-dolphins 5
  set fish-vision-range 5
  set dolphin-vision-range 5
  if enable-reproduction [set enable-reproduction false]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MAIN LOOP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; Button procedure
to go
  if not any? fishes [ stop ]  ;; End simulation if no fishes remain

  ask fishes [
    perform-fish-behaviors
    set time-alive time-alive + 1
    ifelse cluster-labeling
    [ label-clusters ]
    [ if labeling-was-turned-off [ delete-labels ] ]
  ]

  ask dolphins [
    perform-dolphin-behaviors
  ]

  set old-cluster-labeling not not cluster-labeling
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MOVEMENT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-randomly [turn-angle speed]
  ;; Perform random movement within a specified turn angle
  let random-turn (random-float turn-angle - turn-angle / 2)
  rt random-turn
  fd speed
end

to flee [predator speed]
  ;; Flee from a predator
  face predator
  rt 180
  fd speed
end

to move-towards [target speed]
  face target
  let distance-to-target distance target
  let adjusted-speed min (list speed distance-to-target)  ;; clamp to avoid overshooting
  fd adjusted-speed
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FISH BEHAVIORS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to perform-fish-behaviors
  set time-since-reproduction time-since-reproduction + 1
  if enable-reproduction and time-since-reproduction > reproduction-interval [
    reproduce
    set time-since-reproduction 0  ;; Reset timer
  ]

  if version >= 1 [
    school
  ]

  ifelse any? dolphins in-radius vision-range [
    let predator min-one-of dolphins in-radius vision-range [distance myself]
    ;show-vision-circle
    flee predator fish-speed
  ] [
    move-randomly-fish
    ;hide-vision-circle
  ]
end

to show-vision-circle
  if not any? circles with [(who = [who] of myself)] [
    hatch-circles 1 [
      set owner [who] of myself
      set color green + 2               ;; Lighter green for transparency
      set size vision-range * 2         ;; Size scaled to match vision range
      set shape "circle outline"
      set hidden? false
    ]
  ]
  ask circles with [(who = [who] of myself)] [
    setxy [xcor] of myself [xcor] of myself      ;; follow with bind xy
  ]
end

to hide-vision-circle
  ask circles with [owner = [who] of myself] [
    set hidden? true
  ]
end



to reproduce
  hatch 1 [
    set size 1
    set time-since-reproduction 0
    setxy xcor + random-float 1 - 0.5 ycor + random-float 1 - 0.5  ;; Nearby position
  ]
end

to move-randomly-fish
  move-randomly 180 fish-speed
end


;;; SCHOOLING (reproduced from flocking model included with NetLogo)

to school
  find-schoolmates
  if any? schoolmates [
    find-nearest-neighbor
    ifelse distance nearest-neighbor < minimum-separation [
      separate
    ] [
      align
      cohere
    ]
  ]
end

to find-schoolmates
  set schoolmates other fishes in-radius vision-range
end

to find-nearest-neighbor
  set nearest-neighbor min-one-of schoolmates [distance myself]
end

to separate
    turn-away ([heading] of nearest-neighbor) max-separate-turn
end

;;; ALIGN

to align
  turn-towards average-schoolmate-heading max-align-turn
end

to-report average-schoolmate-heading
  ;; We can't just average the heading variables here.
  ;; For example, the average of 1 and 359 should be 0,
  ;; not 180.  So we have to use trigonometry.
  let x-component sum [dx] of schoolmates
  let y-component sum [dy] of schoolmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;; COHERE

to cohere
  turn-towards average-heading-towards-schoolmates max-cohere-turn
end

to-report average-heading-towards-schoolmates
  ;; "towards myself" gives us the heading from the other turtle
  ;; to me, but we want the heading from me to the other turtle,
  ;; so we add 180
  let x-component mean [sin (towards myself + 180)] of schoolmates
  let y-component mean [cos (towards myself + 180)] of schoolmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

;;; HELPER PROCEDURES

to turn-towards [new-heading max-turn]
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]
  turn-at-most (subtract-headings heading new-heading) max-turn
end

;; turn right by "turn" degrees (or left if "turn" is negative),
;; but never turn more than "max-turn" degrees
to turn-at-most [turn max-turn]
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DOLPHIN BEHAVIORS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to perform-dolphin-behaviors
  set fishes-in-range fishes in-radius vision-range
  if model-version = "hunting" [
    communicate fishes-in-range
    if visible-comm-links [
      draw-comm-links
    ]
  ]

  let target min-one-of fishes-in-range [distance myself]

  if target != chasing-target [
    ask chase-links with [end1 = myself] [ die ] ;; Delete link because outdated
    set chasing-target target
  ]

  if target != nobody [
    create-chase-link-to target ;; Draw link from dolphin to target
    move-towards target dolphin-speed
    if distance target < 1 [ consume-fish target ]
    stop
  ]

  let markers-in-memory fish-markers with [owner = myself]
  if any? markers-in-memory [
    let closest-fish min-one-of markers-in-memory [distance myself]
    set chasing-target closest-fish
    create-chase-link-to closest-fish
    move-towards closest-fish dolphin-speed
    stop
  ]

  move-randomly 180 dolphin-speed
end


to consume-fish [prey]
  if enable-debug [ show word "Ate fish " prey ]
  ask prey [ die ]
  ask chase-links with [end1 = myself] [ die ]  ;; Remove the link to the eaten fish
  set chasing-target nobody
  set fish-eaten fish-eaten + 1
end

;; Communication for hunting

to draw-comm-links
  ask my-comm-links [die] ;; TODO change this for performance
  create-comm-links-with other dolphins in-radius communication-range
end

to communicate [fishes-to-remember]
  if enable-debug [ show (word "--- begin communicate ---") ]
  foreach [self] of invalid-markers-of self [ m ->
    broadcast-delete m
    delete-marker m
  ]

  foreach [self] of fishes-to-remember [ f ->
    add-or-update-known-fish f
    broadcast f
  ]

  let markers-in-memory fish-markers with [owner = myself]
  if enable-debug [
    show word "markers: " [self] of markers-in-memory
    show (word "--- end communicate ---")
  ]
end

to-report invalid-markers-of [dolphin-agent]
  let stale-markers no-turtles
  let markers-in-memory fish-markers with [owner = dolphin-agent]
  ask markers-in-memory in-radius vision-range [
    let actual-fish one-of ([fishes-in-range] of dolphin-agent) with [who = [fish-id] of myself]
    if actual-fish = nobody or distance actual-fish > 1 [
      set stale-markers (turtle-set stale-markers self)
    ]
  ]
  report stale-markers
end

to delete-marker [marker]
  ask marker [ die ]
end

to broadcast-delete [marker]
  if enable-debug [ show (word "broadcast-delete: " marker) ]
  ask dolphins in-radius communication-range [
    let markers-in-memory fish-markers with [owner = myself] who-are-not marker
    let stale-markers markers-in-memory with [is-same-marker self marker]
    ask stale-markers [ die ]
  ]
end


to-report is-same-marker [a b]
  report [fish-id] of a = [fish-id] of b
  and [xcor] of a = [xcor] of b
  and [ycor] of a = [ycor] of b
  and [last-updated] of a = [last-updated] of b
end

to broadcast [fish-agent]
  if enable-debug [ show (word "broadcast-add:" fish-agent) ]
  ask other dolphins in-radius communication-range [
    add-or-update-known-fish fish-agent
  ]
end

to add-or-update-known-fish [fish-agent]
  let markers-in-memory fish-markers with [owner = myself]
  let marker one-of markers-in-memory with [fish-id = [who] of fish-agent]

  ifelse marker != nobody [
    ask marker [
      if enable-debug [ print (word myself ": updated - " self " from " fish-agent) ]
      set xcor [xcor] of fish-agent
      set ycor [ycor] of fish-agent
      set last-updated ticks
    ]
  ] [
    hatch-fish-markers 1 [
      set owner myself
      set fish-id [who] of fish-agent
      set xcor [xcor] of fish-agent
      set ycor [ycor] of fish-agent
      set last-updated ticks
      set hidden? true
      if enable-debug [ print (word myself ": created - " self " from " fish-agent) ]
      ;set color gray   ;; Optional: visual feedback
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REPORTING METRICS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report total-fish-eaten
  report sum [fish-eaten] of dolphins
end

to-report average-fish-eaten
  if count dolphins = 0 [ report 0 ]
  report mean [fish-eaten] of dolphins
end

to-report max-fish-lifespan
  report max [time-alive] of fishes
end

to-report clusters
  let cluster-min-size 3
  ifelse count fishes > cluster-min-size
  [ report dbscan:cluster-by-location fishes cluster-min-size (vision-range / 2) ]
  [ report [] ]

end

to label-clusters
  (foreach clusters range length clusters [ [c i] ->
    foreach c [ t -> ask t [ set label i ]
    ]
  ])
end

to delete-labels
  ask fishes [set label ""]
end

to-report labeling-was-turned-off
  report (not cluster-labeling) and old-cluster-labeling
end

to-report version
  report (ifelse-value
    model-version = "base" [ 0 ]
    model-version = "schooling" [ 1 ]
    model-version = "hunting" [ 2 ]
  )
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PLOTTING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report get-color-for [id]
  let dolphins-list sort [who] of dolphins
  let i position id dolphins-list
  let c approximate-hsb (i * 360 / initial-dolphins) 75 85  ;; Unique hue for each dolphin
  ifelse c = false
  [ report red ] ;; fallback value
  [ report c ]
 end

to update-dolphin-fish-plot
  set-current-plot "Dolphins and Fish Eaten"
  clear-plot

  let dolphins-list sort dolphins
  let n length dolphins-list
  set-plot-x-range 0 n

  let step 0.05  ;; Tweak for smooth bar stacking

  ;; Iterate over each dolphin and plot their fish-eaten count
  (foreach dolphins-list range n [ [d i] ->
    let y [fish-eaten] of d
    let c hsb (i * 360 / n) 50 75  ;; Assign unique color for each dolphin
    create-temporary-plot-pen (word "dolphin-" [who] of d)
    set-plot-pen-mode 1  ;; Bar mode
    set-plot-pen-color c

    ;; Draw the bar incrementally
    foreach (range 0 y step) [ _y ->
      plotxy i _y
    ]

    ;; Add a black marker at the top of the bar
    set-plot-pen-color black
    plotxy i y
    set-plot-pen-color c  ;; Reset pen color for the legend
  ])
end

@#$#@#$#@
GRAPHICS-WINDOW
464
16
901
454
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
60.0

SLIDER
220
33
392
66
initial-dolphins
initial-dolphins
0
20
6.0
1
1
NIL
HORIZONTAL

SLIDER
35
32
207
65
initial-fish
initial-fish
0
100
57.0
1
1
NIL
HORIZONTAL

SLIDER
31
79
205
112
fish-vision-range
fish-vision-range
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
219
79
421
112
dolphin-vision-range
dolphin-vision-range
0
100
10.0
1
1
NIL
HORIZONTAL

BUTTON
2
341
75
374
NIL
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

BUTTON
2
296
65
329
NIL
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

SLIDER
31
128
203
161
fish-speed
fish-speed
0.1
5
1.0
0.5
1
NIL
HORIZONTAL

SLIDER
219
128
391
161
dolphin-speed
dolphin-speed
0.1
5
1.5
0.5
1
NIL
HORIZONTAL

PLOT
1191
78
1454
257
Population and Fish Eaten
Time
Count
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Fish Population" 1.0 0 -13345367 true "" "plot count fishes"
"Total Fish Eaten" 1.0 0 -10899396 true "" "plot total-fish-eaten"

SLIDER
186
276
432
309
reproduction-interval
reproduction-interval
10
120
10.0
1
1
ticks
HORIZONTAL

SWITCH
246
228
422
261
enable-reproduction
enable-reproduction
1
1
-1000

BUTTON
2
389
135
422
NIL
reset-defaults
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
916
138
1082
183
model-version
model-version
"base" "schooling" "hunting"
2

SLIDER
919
212
1127
245
minimum-separation
minimum-separation
0.1
10
3.0
0.1
1
NIL
HORIZONTAL

SLIDER
26
223
223
256
max-turn-angle
max-turn-angle
45
360
175.0
1
1
deg
HORIZONTAL

SLIDER
919
256
1142
289
max-separate-turn
max-separate-turn
1
360
268.0
1
1
deg
HORIZONTAL

SLIDER
919
301
1109
334
max-align-turn
max-align-turn
1
360
145.0
1
1
deg
HORIZONTAL

SLIDER
919
346
1127
379
max-cohere-turn
max-cohere-turn
1
360
270.0
1
1
deg
HORIZONTAL

SLIDER
166
400
437
433
dolphin-communication-range
dolphin-communication-range
1
100
99.0
1
1
NIL
HORIZONTAL

SWITCH
916
73
1101
106
visible-comm-links
visible-comm-links
0
1
-1000

SWITCH
924
26
1081
59
enable-debug
enable-debug
1
1
-1000

SWITCH
925
402
1092
435
cluster-labeling
cluster-labeling
0
1
-1000

INPUTBOX
4
450
321
510
turtle-ids-to-draw-circles
list 1 2 3
1
0
String (reporter)

PLOT
1479
108
1679
258
Dolphins and Fish Eaten
Dolphins
Fish Eateb
0.0
10.0
0.0
10.0
true
true
"" "update-dolphin-fish-plot"
PENS

SWITCH
1505
270
1663
303
color-dolphins
color-dolphins
0
1
-1000

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

circle outline
false
15
Circle -1 false true 0 0 300

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

shark
false
0
Polygon -7500403 true true 283 153 288 149 271 146 301 145 300 138 247 119 190 107 104 117 54 133 39 134 10 99 9 112 19 142 9 175 10 185 40 158 69 154 64 164 80 161 86 156 132 160 209 164
Polygon -7500403 true true 199 161 152 166 137 164 169 154
Polygon -7500403 true true 188 108 172 83 160 74 156 76 159 97 153 112
Circle -16777216 true false 256 129 12
Line -16777216 false 222 134 222 150
Line -16777216 false 217 134 217 150
Line -16777216 false 212 134 212 150
Polygon -7500403 true true 78 125 62 118 63 130
Polygon -7500403 true true 121 157 105 161 101 156 106 152

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
