class_name Mover
extends RefCounted
## A car on the track that is not the player: a bot (is_bot) or a traffic vehicle. The fields are the JS object's
## fields (bots.push({...}) / traffic.push({...})) plus the ones the physics adds on the fly (spin, yawOff, contactT...).

var m: Dictionary            ## the car model (CarKit.buildCar / Vehicles.*): g, wheels, len, wid, rc, off, beam
var is_bot := false          ## JS: c.lineLat !== undefined
var s := 0.0                 ## distance along the track
var lat := 0.0
var speed := 0.0
var cur := 0.0
var latV := 0.0
var mass := 1.0
var lp := 0.0                ## lateral push velocity
var yawK := 0.0
var vx := 0.0
var vz := 0.0
var spin := 0.0
var yawOff := 0.0
var spun := false
var spunT := 0.0
var contactT := 0.0
var contactSide := 0.0
var hitByPlayer := 0.0
var dv := 0.0                ## traffic: extra speed from a push
var pushDv := 0.0            ## bots: extra speed from a push from behind

# traffic
var lane := 0
var target := 0
var tractor := false

# bots
var name := ""
var type := ""
var color := ""
var rival := false
var out := false
var outAt := 0.0
var elimPos := 0
var lineLat := 0.0
var vmax := 0.0
var acc := 0.0
var aLat := 0.0
var brk := 0.0
var lap := 0
var finished := false
var finishTime := 0.0
var bestLap := 0.0
var lapStart := 0.0
var passT := 0.0
var passLat := 0.0
var gridLat = null
var mistT = null
var slowT := 0.0
var slideT := 0.0
var noAvoid := false
