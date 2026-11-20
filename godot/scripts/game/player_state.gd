class_name PlayerState
extends RefCounted
## JS `player`: the car you drive (and in split screen, player 2's own copy). Everything a player's car carries from
## step to step lives here, so split screen swaps it in one go (Game.swapCtx swaps the whole object).

var pos := Vector3.ZERO
var heading := 0.0
var speed := 0.0             ## along the nose (m/s)
var steer := 0.0
var idx := 0
var lat := 0.0
var s := 0.0
var y := 0.0
var lap := 0
var slide := Vector2.ZERO    ## x, z: the rest of the velocity (across the nose): tyre slip plus shoves
var hand := false
var damage := 0.0
var brk := 0.0
var look := false
var gear := 1
var shiftT := 0.0
var gasIn := 0.0
var spin := 0.0              ## yaw rate from a hit (rad/s, positive = to the left), fades by itself

# ---- handling (Game.driveStep)
var yr := 0.0                ## yaw rate from the tyres (rad/s, positive = turning right)
var push := Vector2.ZERO     ## the part of `slide` that is a shove from outside (a hit, a wall, a gust): fades by itself
var slideOut := Vector2.ZERO ## `slide` as the last step left it: what was added since then is a shove
var wt := 0.0                ## share of the weight moved to the rear wheels (accelerating +, braking -)
var load := 1.0              ## how hard the road pushes back (crest < 1 < dip)
var slipF := 0.0             ## how far the front / rear tyres are over their limit (1 = at the limit)
var slipR := 0.0
var beta := 0.0              ## slip angle: the direction of travel to the right of the nose (rad)
var delta := 0.0             ## front wheel angle (rad, right is positive)
var ax := 0.0                ## acceleration along the nose and to the right (m/s2), for the body's lean
var ay := 0.0
var rumble := 0.0            ## rough ground under the wheels (0 smooth tarmac .. 1.5 gravel)
var offroad := 0.0           ## share of the car off the tarmac (0..1)
var spinV := 0.0             ## driven wheels spinning faster than the road (launch), m/s

# ---- the body on its springs (Game.syncCar; visual only)
var roll := 0.0
var rollV := 0.0
var pitch := 0.0
var pitchV := 0.0
var heave := 0.0
var heaveV := 0.0
var camD := 0.0              ## the chase camera drops back when you accelerate and closes in when you brake
var wallYaw := 0.0           ## a wall hit turns the car at once; the body follows in a blink instead of a jump (rad)
var camBack := false         ## the chase camera looks backwards: only while you reverse on purpose (not after a bounce)
var camSide := 0.0           ## the chase camera looks a little into the corner (m to the right of the car's nose)

## a car at rest: no slide, no lean (reset to the track, start of a race)
func settle() -> void:
	speed = 0; steer = 0; gear = 1; shiftT = 0; spin = 0
	slide = Vector2.ZERO; push = Vector2.ZERO; slideOut = Vector2.ZERO
	yr = 0; wt = 0; load = 1; slipF = 0; slipR = 0; beta = 0; delta = 0; ax = 0; ay = 0; rumble = 0; offroad = 0; spinV = 0
	roll = 0; rollV = 0; pitch = 0; pitchV = 0; heave = 0; heaveV = 0; camD = 0; camSide = 0; wallYaw = 0; camBack = false
