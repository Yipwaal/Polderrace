class_name PlayerState
extends RefCounted
## JS `player`: the car you drive (and in split screen, player 2's own copy).

var pos := Vector3.ZERO
var heading := 0.0
var speed := 0.0
var steer := 0.0
var idx := 0
var lat := 0.0
var s := 0.0
var y := 0.0
var lap := 0
var slide := Vector2.ZERO    ## x, z
var hand := false
var damage := 0.0
var brk := 0.0
var look := false
var gear := 1
var shiftT := 0.0
var gasIn := 0.0
var spin := 0.0
