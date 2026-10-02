extends Node
## Autoload "Sfx": the game's sound (JS audio section: initAudio, tone, noise, updateAudio, toggleMute).
## Placeholder until the audio port: every call is accepted and does nothing.

var muted := false

func initAudio() -> void:
	pass

func tone(_freq: float, _dur: float, _type := "sine", _vol := 0.15, _delay := 0.0) -> void:
	pass

func noise(_dur: float, _vol: float, _freq: float) -> void:
	pass

func updateAudio() -> void:
	pass
