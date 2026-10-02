class_name SettingsUI
extends RefCounted
## The settings panel of the HTML game (JS #homeSettings, syncToggles, setTab, the key binding UI renderBinds): tabs
## Algemeen (sound, mirror, speed effects, gearbox, quality), Toetsen (keys of player 1 and 2, click and press a key),
## Controller (the gamepad layout). The same panel opens in the pause screen (Menu.openPauseSettings).

const ACTION_NAMES := {"up": "Gas", "down": "Remmen / achteruit", "left": "Links sturen", "right": "Rechts sturen", "hand": "Handrem", "reset": "Terug op de baan",
	"cam": "Camera wisselen", "look": "Achterom kijken", "shiftUp": "Opschakelen", "shiftDown": "Terugschakelen"}
const KEYNAME := {"Space": "Spatie", "ShiftLeft": "L-Shift", "ShiftRight": "R-Shift", "ControlLeft": "L-Ctrl", "ControlRight": "R-Ctrl", "AltLeft": "L-Alt", "AltRight": "R-Alt",
	"ArrowUp": "↑", "ArrowDown": "↓", "ArrowLeft": "←", "ArrowRight": "→", "Enter": "Enter", "Tab": "Tab", "PageUp": "Page Up", "PageDown": "Page Down", "Comma": ",",
	"Period": ".", "Slash": "/", "Semicolon": ";", "Quote": "'", "BracketLeft": "[", "BracketRight": "]", "Backslash": "\\", "Minus": "-", "Equal": "="}
const RESERVED := ["Escape", "KeyP", "KeyM", "Enter", "Backspace", "Tab"]
const PAD_ROWS := [["Sturen", "linkerstick of D-pad"], ["Gas", "RT of A"], ["Remmen", "LT of B"], ["Handrem", "X (bij automaat ook RB)"], ["Terug op de baan", "Y"],
	["Camera", "Select"], ["Achterom", "R3"], ["Pauze", "Start"], ["Schakelen (handgeschakeld)", "RB en LB"], ["Klasse wisselen in het menu", "LB en RB"]]

var content: VBoxContainer
var nav: HBoxContainer
var back: UiKit.Btn
var tabRadio: UiKit.Radio
var general: VBoxContainer
var keys: VBoxContainer
var pad: VBoxContainer
var togs := {}                ## pref -> Btn
var gearRadio: UiKit.Radio
var qualRadio: UiKit.Radio
var bindP1: UiKit.Btn
var bindP2: UiKit.Btn
var bindList: VBoxContainer
var bindPlayer := "p1"
var setTab := "general"

static func keyLabel(c: String) -> String:
	if KEYNAME.has(c): return KEYNAME[c]
	if c.begins_with("Key"): return c.substr(3)
	if c.begins_with("Digit"): return c.substr(5)
	if c.begins_with("Numpad"): return "Num " + c.substr(6)
	return c

func _init() -> void:
	content = UiKit.vbox(16)
	content.add_child(UiKit.h2("Instellingen"))
	var s := UiKit.seg([["general", "Algemeen"], ["keys", "Toetsen"], ["pad", "Controller"]], func(v) -> void: showTab(v), true, true)
	tabRadio = s[1]
	content.add_child(s[0])
	# Algemeen
	general = UiKit.vbox(16)
	var rows := []
	for t in [["sound", "Geluid", "Motor, wind en piepjes"], ["mirror", "Achteruitkijkspiegel", "Kleine spiegel bovenin beeld"], ["fx", "Snelheidseffecten", "Vervaging, strepen en trillen"]]:
		var b := UiKit.tog(t[1], t[2])
		var k: String = t[0]
		b.pressed.connect(func() -> void:
			G.prefs[k] = not G.prefs.get(k, false)
			G.savePrefs()
			Menu.applyPrefs()
			syncToggles())
		togs[k] = b
		rows.append(b)
	general.add_child(UiKit.rows_card(rows, UiKit.LINE2))
	var gs := UiKit.seg([["auto", "Automaat"], ["manual", "Handgeschakeld"]], func(v) -> void:
		G.prefs.gearbox = v
		G.savePrefs()
		syncToggles())
	gearRadio = gs[1]
	var qs := UiKit.seg([["low", "Laag"], ["mid", "Middel"], ["high", "Hoog"]], func(v) -> void:
		G.prefs.quality = v
		G.savePrefs()
		Menu.applyPrefs()
		syncToggles())
	qualRadio = qs[1]
	general.add_child(UiKit.rows_card([UiKit.opt(UiKit.optl("Versnellingsbak", "Handgeschakeld: E en Q, of RB en LB"), gs[0]),
		UiKit.opt(UiKit.optl("Kwaliteit", "Laag helpt op tragere pc's"), qs[0])]))
	content.add_child(general)
	# Toetsen
	keys = UiKit.vbox(16)
	var bt := UiKit.FlexRow.new(8, 8)
	bt.grow_first = false
	var grp := UiKit.hbox(6)
	bindP1 = UiKit.chip("Speler 1"); bindP2 = UiKit.chip("Speler 2")
	bindP1.pressed.connect(func() -> void: bindPlayer = "p1"; renderBinds())
	bindP2.pressed.connect(func() -> void: bindPlayer = "p2"; renderBinds())
	grp.add_child(bindP1); grp.add_child(bindP2)
	bt.add_child(grp)
	var reset := UiKit.linkbtn("Standaard herstellen")
	reset.pressed.connect(func() -> void:
		Game.binds[bindPlayer] = Game.DEFAULT_BINDS[bindPlayer].duplicate(true)
		saveBinds()
		renderBinds())
	bt.add_child(reset)
	keys.add_child(bt)
	keys.add_child(UiKit.note("Klik op een toets en druk daarna op de nieuwe toets. Speler 2 gebruikt zijn toetsen alleen in de modus 2 spelers.", true))
	var bl := UiKit.panel(UiKit.flat(UiKit.CARD, 16))
	bindList = UiKit.vbox(0)
	bl.add_child(bindList)
	keys.add_child(bl)
	keys.visible = false
	content.add_child(keys)
	# Controller
	pad = UiKit.vbox(16)
	pad.add_child(_ctrls())
	pad.add_child(UiKit.note("Bij 2 spelers: met één controller rijdt speler 2 op de controller, met twee heeft elke speler er één.", true))
	pad.add_child(UiKit.note("Touchscreen: pijlen om te sturen, Gas en Rem, HR is de handrem en ↺ zet je terug op de baan.", true))
	pad.visible = false
	content.add_child(pad)
	var n := HomeUI.back_nav()
	nav = n[0]
	back = n[1]
	renderBinds()

## the gamepad table (.ctrls): two columns sized by their text like an auto table layout
func _ctrls() -> VBoxContainer:
	var v := UiKit.vbox(0)
	var f := UiKit.font(700)
	var w1 := 0.0
	var w2 := 0.0
	for r in PAD_ROWS:
		w1 = maxf(w1, f.get_string_size(r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16)
		w2 = maxf(w2, f.get_string_size(r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16)
	var row := func(a: Control, b: Control, pad_y: float) -> HBoxContainer:
		var h := UiKit.hbox(0)
		for c in [a, b]:
			var m := UiKit.margin(c, Vector4(8, pad_y, 8, pad_y))
			m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(m)
		h.get_child(0).size_flags_stretch_ratio = w1
		h.get_child(1).size_flags_stretch_ratio = w2
		return h
	v.add_child(row.call(UiKit.eyebrow("Actie"), UiKit.eyebrow("Controller"), 6))
	v.add_child(UiKit.hline(UiKit.LINE3))
	for k in PAD_ROWS.size():
		var r: Array = PAD_ROWS[k]
		v.add_child(row.call(UiKit.lbl(r[0], 700, 14, UiKit.SIGN_INK, true), UiKit.lbl(r[1], 700, 14, UiKit.SIGN_INK, true), 8))
		if k < PAD_ROWS.size() - 1: v.add_child(UiKit.hline(UiKit.LINE4))
	return v

func showTab(v: String) -> void:
	setTab = v
	general.visible = v == "general"
	keys.visible = v == "keys"
	pad.visible = v == "pad"
	tabRadio.sync(v)

func syncToggles() -> void:
	qualRadio.sync(G.prefs.get("quality", "high"))
	gearRadio.sync(G.prefs.get("gearbox", "auto"))
	tabRadio.sync(setTab)
	for k in togs:
		togs[k].checked = bool(G.prefs.get(k, false))

static func saveBinds() -> void:
	G.store_set("polderrace3d-binds", JSON.stringify(Game.binds))

## the key list of the chosen player; a click waits for the next key (Escape cancels, reserved keys are refused)
func renderBinds() -> void:
	bindP1.checked = bindPlayer == "p1"
	bindP2.checked = bindPlayer == "p2"
	UiKit.clear(bindList)
	var acts: Array = Game.ACTIONS
	for k in acts.size():
		var a: String = acts[k]
		if k > 0: bindList.add_child(UiKit.hline(UiKit.LINE2))
		var r := UiKit.hbox(10)
		var l := UiKit.lbl(ACTION_NAMES[a], 700, 15, UiKit.SIGN_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(l)
		var pad4 := Vector4(12, 9, 12, 9)
		var b := UiKit.Btn.new(UiKit.flat(Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.3), 999, pad4), UiKit.flat(Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.45), 999, pad4), UiKit.flat(UiKit.DETOUR, 999, pad4))
		b.custom_minimum_size.x = 150
		var codes: Array = Game.binds[bindPlayer].get(a, [])
		var bl := UiKit.lbl(" / ".join(codes.map(func(c): return keyLabel(c))) if not codes.is_empty() else "–", 800, 13, UiKit.SIGN_INK, false, 0, false, 1.0)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(bl)
		b.tint(bl, UiKit.SIGN_INK, UiKit.INK)
		b.pressed.connect(func() -> void:
			b.checked = true
			bl.text = "Druk op een toets…"
			Menu.bindCapture = func(code: String) -> void:
				Menu.bindCapture = Callable()
				if code == "Escape":
					renderBinds()
					return
				if RESERVED.has(code):
					Hud.showToast(keyLabel(code) + " is gereserveerd")
					renderBinds()
					return
				for x in Game.ACTIONS:
					Game.binds[bindPlayer][x] = Game.binds[bindPlayer].get(x, []).filter(func(c): return c != code)
				Game.binds[bindPlayer][a] = [code]
				saveBinds()
				renderBinds())
		r.add_child(b)
		bindList.add_child(UiKit.margin(r, Vector4(18, 7, 8, 7)))
