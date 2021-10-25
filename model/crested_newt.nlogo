extensions
[
  shell
  gis
]

globals
[
  pond-radius
  no-of-ponds
  path
  first-scenario

  ; output numbers
  newts-corridor-scenario
  newts-buffer-scenario
  occupied-ponds-corridor-scenario
  occupied-ponds-buffer-scenario
  newts-pond1-corridor-scenario
  netws-pond1-buffer-scenario
]

patches-own
[
  pond-id
  is-center-of-pond  ; 0 or 1
]

breed [newts newt]

newts-own
[
  actual-pond-id
  should-migrate
  age
]


;-------------------------------------------------------------------------------
;- setup
;-------------------------------------------------------------------------------
to setup
  ca
  reset-ticks

  ; ------ id of this run and path for landscape files
  ; get random id for each simulation
  ; this is only important for parallel runs
  let scenario-no random 1000000000000000
  ; or get process ids from pythons
  ;let scenario-no (shell:exec "python3" "-c" "import os; print(str(os.getpid()))")
  set path (word "gis_output/" scenario-no "/")
  set first-scenario True


  ; ------ landscape
  set no-of-ponds 7
  set pond-radius 15
  print(shell:exec "python3" "create_landscape.py" (word scenario-no) (word no-of-ponds) (word pond-radius))
  load-general-landscape
  if current-scenario = "buffers" [load-buffers]
  if current-scenario = "corridors" [load-corridors]
  ask patches with [is-center-of-pond = 1] [set plabel pond-id]

  ; ------ population initialization
  start-population
end


;-------------------------------------------------------------------------------
;- go
;-------------------------------------------------------------------------------
to go
  migrate
  reproduce
  mortality
  ageing

  plot-timeseries
  plot-migration

  tick

  if ticks = max-timesteps or not any? newts
  [
    set-output-numbers

    ;------------ continue with other scenario
    ifelse both-scenarios and first-scenario
    [
      set first-scenario False

      ifelse current-scenario = "corridors"
      [
        clear-all-plots
        ask newts [die]
        set current-scenario "buffers"
        load-buffers
        start-population
        reset-ticks

      ]

      ; current-scenario = "buffers"
      [
        clear-all-plots
        ask newts [die]
        set current-scenario "corridors"
        load-corridors
        start-population
        reset-ticks
      ]
    ]

    ;------------ else stop simulation
    [
      print(shell:exec "rm" "-r" path)
      stop
    ]
  ]
end


;-------------------------------------------------------------------------------
;- initialization
;-------------------------------------------------------------------------------
to load-general-landscape
  gis:set-world-envelope (list min-pxcor max-pxcor min-pycor max-pycor)

  let is-center-of-pond-raster gis:load-dataset (word path "center.asc")
  gis:apply-raster is-center-of-pond-raster is-center-of-pond

  let pond-id-raster gis:load-dataset (word path "id.asc")
  gis:apply-raster pond-id-raster pond-id
end

to load-corridors
  let created-landscape gis:load-dataset (word path "corridors.asc")
  gis:apply-raster created-landscape pcolor
end

to load-buffers
    let created-landscape gis:load-dataset (word path "buffers.asc")
    gis:apply-raster created-landscape pcolor
end

to start-population
  create-newts number-of-startind
  [
    set color red
    set shape "fish"
    set size 10
    set age random 16
    set should-migrate false

    ; --- choose random pond patch
    let random-pond-patch 0
    ifelse one-pond-without-starting-newts
    [
      set random-pond-patch one-of patches with [pcolor = blue and pond-id != 1]
    ]
    [
      set random-pond-patch one-of patches with [pcolor = blue]
    ]

    setxy [pxcor] of random-pond-patch [pycor] of random-pond-patch
    set actual-pond-id [pond-id] of patch-here
  ]
end



;-------------------------------------------------------------------------------
;- migration
;-------------------------------------------------------------------------------
to migrate
  set-migrants
  move-to-adjacent-forest
  stochastic-movement
end

to set-migrants
  ask newts [set should-migrate false]
  let pond-iterator 0

  while [pond-iterator < no-of-ponds] [

    let no-individuals count newts with [actual-pond-id = pond-iterator]

    ; ------- juvenile migration
    ; if more than 5 individuals are present,
    ; then density dependent juvenile migration
    if no-individuals > 5
    [
      let prob 1 / ( 1 + e ^ (-0.1 * (no-individuals - capacity / 2)) )

      ask newts with [actual-pond-id = pond-iterator and age < 3]
      [
        if random-float 1 <= prob [set should-migrate true]
      ]
    ]

    ; ------- adult migration
    ; if more than 5 individuals are present,
    ; then migration with probability of 1 %
    if no-individuals > 5
    [
      ask newts with [age >= 3]
      [
        if random-float 1 <= 0.01 [set should-migrate true]
      ]
    ]
    set pond-iterator pond-iterator + 1
  ]
end

to move-to-adjacent-forest
  ; move to forest patch around pond
  ask newts with [should-migrate]
  [
    ; select one forest patch around the pond
    let my-pond-id actual-pond-id
    let center-patch one-of patches with [is-center-of-pond = 1 and pond-id = my-pond-id]
    let forest-patch-around 0

    ask center-patch
    [
      set forest-patch-around one-of patches in-radius (pond-radius + 1) with [pcolor = brown]
    ]

    move-to forest-patch-around
    set heading towards  center-patch - 180
  ]
end

to stochastic-movement
  ; random walk
  ask newts with [should-migrate]
  [
    let migration-energy movement-energy

    ; ----walking loop
    ; as long as energy is sufficient or until found a pond
    while [(migration-energy > 0) and (pcolor != blue)]
    [
      let energy-loss walk
      set migration-energy migration-energy - energy-loss

    ] ; end of random walk


    ifelse migration-energy <= 0
    [
      die
    ]

    ; found a pond
    [
      let new-pond-id [pond-id] of patch-here
      set actual-pond-id new-pond-id

    ]  ; end of found a pond
  ] ; end of ask newts
end

to-report walk
      set-heading

      ; move
      forward 1

      ; cost for moving over crop field
      if pcolor = green
      [
        report cropland-movement-cost
      ]

      ; cost for moving over forest
      if pcolor = brown
      [
        report woodland-movement-cost
      ]

      ; no cost if newt reaches pond
      if pcolor = blue
      [
        report 0
      ]

end

to set-heading
  let pond-patches patches in-cone distance-for-viewing-ponds-and-woodland angle-for-viewing-ponds-and-woodland with [pcolor = blue and distance myself > 0]
  let is-pond-in-front any? pond-patches

  ifelse is-pond-in-front
  [
    set heading towards one-of pond-patches
  ]

  [ ; start no pond in front

    let woodland-patches patches in-cone distance-for-viewing-ponds-and-woodland angle-for-viewing-ponds-and-woodland with [pcolor = brown and distance myself > 0]
    let is-woodland-in-front any? woodland-patches

    ifelse is-woodland-in-front
    [
      set-heading-woodland woodland-patches

    ] ; end of woodland in front

    [
      ; no woodland or pond in front
      ; direction only influenced by last direction
      set heading random-normal heading 10

    ] ; end of no woodland or pond in front

  ] ; end of no pond in front
end

to set-heading-woodland [woodland-patches]
      let woodland-heading 0

      ifelse movement-in-forest = "one forest patch"
      [
        ;print (word "choose randomly one forest patch")
        set woodland-heading towards one-of woodland-patches with [distance myself > 0]
      ] ; end of choosing heading towards one forest patch

      [
        ;print (word "mean of forest patches")
        let x-coords []
        let y-coords []

        ask woodland-patches with [distance myself > 0]
        [
          set x-coords lput pxcor x-coords
          set y-coords lput pycor y-coords
        ]

        let headings []
        let patch-iterator 0
        while [patch-iterator < count woodland-patches with [distance myself > 0]]
        [
          set headings lput towards one-of woodland-patches with [pxcor = item patch-iterator x-coords and pycor = item patch-iterator y-coords] headings
          set patch-iterator patch-iterator + 1
        ]

        set woodland-heading mean headings

      ] ; end of choosing mean forest heading

      ; random heading
      let random-heading random-normal heading 10

      let diff subtract-headings woodland-heading random-heading
      set heading  random-heading + diff *  (1 - 0.05) ; random-influence-in-forest 0.05
end


;-------------------------------------------------------------------------------
;- reproduction
;-------------------------------------------------------------------------------
to reproduce
  ask newts
  [
    ; reproduction is only possible at an age of 3 or greate
    ; and if the codnitions are right
    if (age >= 3)
    [
      ; mean 5 fertile juveniles
      let juveniles random-poisson mean-number-of-female-offspring


      hatch-newts juveniles [
        ; juveniles start with an age of 0
        set age 0

        ; put the newt on a ranom patch in the pond
        ;let my-id actual-pond-id
        ;let selected-patch one-of patches with [pond-id = my-id]
        ;setxy [pxcor] of selected-patch [pycor] of selected-patch
      ]
    ]
  ]
end


;-------------------------------------------------------------------------------
;- mortality
;-------------------------------------------------------------------------------
to mortality
  remove-too-old-individuals
  remove-excess-newts
  random-mortality
end

to remove-too-old-individuals
  ask newts
  [
    if age > 16 [die]
  ]

end

to remove-excess-newts
  let pond-iterator 0

  while [pond-iterator < no-of-ponds]
  [
    let number-of-newts count newts with [actual-pond-id = pond-iterator]
    let excess (number-of-newts - capacity)
    ;print(word pond-iterator ": " number-of-newts ", excess: " excess)

    ; let excess die
    if excess > 0
    [
      ask n-of excess newts with [actual-pond-id = pond-iterator] [die]
    ]

    set pond-iterator pond-iterator + 1
  ]
end

to random-mortality
  ask newts
  [
    ifelse age < 3
    [
      ; mortality for juveniles
      let mortality-prob-juveniles (random-float mean-juvenile-mortality-prob * 0.8)  +   mean-juvenile-mortality-prob * 0.6

      ; decrease mortality in the buffer scenario
      if current-scenario = "buffers"
      [
        set mortality-prob-juveniles mortality-prob-juveniles - mortality-prob-juveniles * mortality-decrease-with-buffer
      ]

      if random-float 1 <= mortality-prob-juveniles [die]

    ]

    [
      ; mortality for adults
      let mortality-prob-adults (random-float mean-adult-mortality-prob * 0.7)  + mean-adult-mortality-prob * 0.65

      ; decrease mortality in the buffer scenario
       if current-scenario = "buffers"
      [
        set mortality-prob-adults mortality-prob-adults - mortality-prob-adults * mortality-decrease-with-buffer
      ]


      if random-float 1 <= mortality-prob-adults  [die]
    ]
  ]
end

;-------------------------------------------------------------------------------
;- ageing
;-------------------------------------------------------------------------------
to ageing
  ask newts [set age age + 1]
end


;-------------------------------------------------------------------------------
;- preparing model output
;-------------------------------------------------------------------------------
to set-output-numbers
  ifelse current-scenario = "corridors"
  [
    set newts-corridor-scenario count newts
    set occupied-ponds-corridor-scenario occupied-ponds
    set newts-pond1-corridor-scenario count newts with [pond-id = 1]
  ]
  ; current-scenario = "buffers"
  [
    set newts-buffer-scenario count newts
    set occupied-ponds-buffer-scenario occupied-ponds
    set netws-pond1-buffer-scenario count newts with [pond-id = 1]
  ]
end

to-report occupied-ponds
  let pond-iterator 0
  let no-occupied-ponds 0
  while [pond-iterator < no-of-ponds] [
    if (any? newts with [actual-pond-id = pond-iterator])
    [set no-occupied-ponds no-occupied-ponds + 1]
    set pond-iterator pond-iterator + 1
  ]

  report no-occupied-ponds
end


;-------------------------------------------------------------------------------
;- model output reporter
;-------------------------------------------------------------------------------
to-report newts-buffer
  report newts-buffer-scenario
end

to-report newts-corridor
  report newts-corridor-scenario
end

to-report newts-corridor-pond1
  report newts-pond1-corridor-scenario
end

to-report newts-buffer-pond1
  report netws-pond1-buffer-scenario
end

to-report occupied-ponds-corridor
  report occupied-ponds-corridor-scenario
end

to-report occupied-ponds-buffer
  report occupied-ponds-buffer-scenario
end

;-------------------------------------------------------------------------------
;- plotting and reporter on the interface
;-------------------------------------------------------------------------------
to-report no-of-migrants
  report count newts with [should-migrate]
end

to plot-migration
  set-current-plot "Migration"
  plot no-of-migrants
end

to plot-timeseries
  set-current-plot "Timeseries"
  set-current-plot-pen "all-ponds"
  plot count newts

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-0"
  plot count newts with [actual-pond-id = 0]

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-1"
  plot count newts with [actual-pond-id = 1]

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-2"
  plot count newts with [actual-pond-id = 2]

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-3"
  plot count newts with [actual-pond-id = 3]

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-4"
  plot count newts with [actual-pond-id = 4]

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-5"
  plot count newts with [actual-pond-id = 5]

  set-current-plot "Timeseries"
  set-current-plot-pen "pond-6"
  plot count newts with [actual-pond-id = 6]

end
@#$#@#$#@
GRAPHICS-WINDOW
587
55
1109
578
-1
-1
1.287
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
399
0
399
0
0
1
ticks
30.0

BUTTON
398
42
471
75
NIL
setup\n
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
400
84
463
117
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
1

SLIDER
25
155
217
188
number-of-startind
number-of-startind
1
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
17
271
263
304
capacity
capacity
5
100
30.0
1
1
NIL
HORIZONTAL

PLOT
1262
66
1660
303
Timeseries
time
population size of newts
0.0
100.0
0.0
100.0
false
true
"" ""
PENS
"all-ponds" 1.0 0 -16777216 true "" ""
"pond-0" 1.0 0 -15575016 true "" ""
"pond-1" 1.0 0 -955883 true "" ""
"pond-2" 1.0 0 -7500403 true "" ""
"pond-3" 1.0 0 -2674135 true "" ""
"pond-4" 1.0 0 -6459832 true "" ""
"pond-5" 1.0 0 -1184463 true "" ""
"pond-6" 1.0 0 -10899396 true "" ""

TEXTBOX
21
228
171
262
reproduction & mortality
14
0.0
0

TEXTBOX
28
17
178
35
initialization
14
0.0
1

MONITOR
1674
68
1843
113
Number of occupied ponds
occupied-ponds
0
1
11

SLIDER
16
321
265
354
mortality-decrease-with-buffer
mortality-decrease-with-buffer
0
0.3
0.1
0.01
1
NIL
HORIZONTAL

PLOT
1263
317
1659
556
Migration
time
Number of migrants
0.0
100.0
0.0
400.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
16
372
268
405
mean-adult-mortality-prob
mean-adult-mortality-prob
0
1
0.18
0.01
1
NIL
HORIZONTAL

SLIDER
15
415
270
448
mean-juvenile-mortality-prob
mean-juvenile-mortality-prob
0
1
0.45
0.01
1
NIL
HORIZONTAL

SLIDER
15
461
268
494
mean-number-of-female-offspring
mean-number-of-female-offspring
0
15
2.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
23
512
173
530
migration\n
12
0.0
1

SLIDER
20
580
327
613
woodland-movement-cost
woodland-movement-cost
0
20
1.0
1
1
per patch
HORIZONTAL

SLIDER
20
624
321
657
cropland-movement-cost
cropland-movement-cost
0
20
5.0
1
1
per patch
HORIZONTAL

SLIDER
19
535
278
568
movement-energy
movement-energy
0
1000
748.0
1
1
per year
HORIZONTAL

CHOOSER
18
671
218
716
movement-in-forest
movement-in-forest
"one forest patch" "mean forest patches"
1

SLIDER
19
731
373
764
distance-for-viewing-ponds-and-woodland
distance-for-viewing-ponds-and-woodland
1
5
2.0
1
1
patches
HORIZONTAL

SLIDER
20
773
417
806
angle-for-viewing-ponds-and-woodland
angle-for-viewing-ponds-and-woodland
1
360
140.0
1
1
degrees
HORIZONTAL

CHOOSER
25
90
169
135
current-scenario
current-scenario
"corridors" "buffers"
1

SWITCH
26
43
191
76
both-scenarios
both-scenarios
0
1
-1000

INPUTBOX
225
44
345
104
max-timesteps
5.0
1
0
Number

SWITCH
239
157
501
190
one-pond-without-starting-newts
one-pond-without-starting-newts
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
  <experiment name="experiment" repetitions="12" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>newts-buffer</metric>
    <metric>newts-corridor</metric>
    <metric>newts-corridor-pond1</metric>
    <metric>newts-buffer-pond1</metric>
    <metric>occupied-ponds-corridor</metric>
    <metric>occupied-ponds-buffer</metric>
    <enumeratedValueSet variable="capacity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-juvenile-mortality-prob">
      <value value="0.45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-startind">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement-in-forest">
      <value value="&quot;mean forest patches&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-timesteps">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="current-scenario">
      <value value="&quot;corridors&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-for-viewing-ponds-and-woodland">
      <value value="140"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cropland-movement-cost">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="woodland-movement-cost">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mortality-decrease-with-buffer">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-for-viewing-ponds-and-woodland">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="movement-energy">
      <value value="748"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="one-pond-without-starting-newts">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="both-scenarios">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-number-of-female-offspring">
      <value value="2.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-adult-mortality-prob">
      <value value="0.18"/>
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
