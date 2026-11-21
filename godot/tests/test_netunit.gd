extends RefCounted
## Online without a network: the parts of the net code that can be checked on their own (run by tests/test_net.py, also
## alone: godot --headless --path godot res://tests/runner.tscn -- netunit).
##  - the Windows firewall button: the PowerShell scripts go as -EncodedCommand (Godot does not escape double quotes inside
##    an argument), decode to exactly the script, quote the program path right, and every outcome gives a clear text.

var r: TestReport

func run(_host: Node) -> TestReport:
	r = TestReport.new("online zonder netwerk (firewall-knop, controles)")
	_firewall()
	var up := [Net.upnpMsg("84.12.3.4"), Net.upnpMsg(""), Net.upnpMsg("100.72.1.9"), Net.upnpMsg("192.168.2.1")]
	r.check(up[0].contains("84.12.3.4") and up[1].contains("wat is mijn IP") and not up[1].contains("  ") and up[2].contains("waarschijnlijk niet") and up[3].contains("waarschijnlijk niet"),
		"UPnP: internet-adres, geen adres bekend, of een router achter een andere router / CGNAT", str(up))
	_looks()
	_build(_host)
	return r

## the biggest look a player can have (every item, its longest value, mixed colours, full texts, the whole body kit) goes
## over the wire whole: under NetRoom.LOOK_MAX and nothing cut off by clean_look's limit on the number of keys
var looks := {}

func _looks() -> void:
	var worst := 0
	var lost := []
	looks = {}
	for car in Cars.CARS:
		var u := {}
		for it in CarLook.ITEMS:
			var k: String = it.k
			match it.type:
				"color": u[k] = "#a1b2c3" if it.get("mix", false) else str(it.opts[-1][0])
				"num": u[k] = 88
				"text": u[k] = "W".repeat(int(it.max))
				_:
					var best := ""
					for o in it.opts:
						if CarLook.optFits(car, k, o[0]) and str(o[0]).length() >= best.length() and o[0] != it.def: best = str(o[0])
					u[k] = best if best != "" else it.def
		var L := CarLook.compact(CarLook.clean(u, car))
		L["paint"] = "#a1b2c3"
		var sent := NetRoom.clean_look(L)
		looks[car] = sent
		worst = maxi(worst, JSON.stringify(sent).length())
		if sent.size() != L.size(): lost.append("%s: %d van %d" % [car, sent.size(), L.size()])
	r.check(lost.is_empty(), "een volledig aangepaste auto gaat helemaal over de lijn (geen onderdelen afgekapt)", str(lost))
	r.check(worst > 0 and worst < NetRoom.LOOK_MAX, "en blijft onder de grens van %d tekens" % NetRoom.LOOK_MAX, "grootste: %d" % worst)

## building the car of a player who comes in (also during a race: every racer's game builds it then)
func _build(host: Node) -> void:
	var times := {}
	var slow := 0.0
	for pass_ in 2:     # (the first pass fills the caches of shared materials and meshes)
		for car in looks:
			var t0 := Time.get_ticks_usec()
			var m := CarKit.buildCar(car, Color("#a1b2c3"))
			CarKit.styleCar(m, Net.safeLook(looks[car], car))
			host.add_child(m.g)
			if Canvas2D.pending_count() > 0: Canvas2D.flush(host)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if pass_ == 1 and car == "gt":
				var plain := CarKit.buildCar(car, Color("#a1b2c3"))
				CarKit.styleCar(plain, {})
				var n0: int = plain.g.find_children("*", "MeshInstance3D", true, false).size()
				var n1: int = m.g.find_children("*", "MeshInstance3D", true, false).size()
				r.check(n1 > n0, "de gemeten auto heeft echt alles erop (meer onderdelen dan af fabriek)", "%d tegen %d" % [n1, n0])
				plain.g.free()
			m.g.queue_free()
			if pass_ == 1:
				times[car] = snappedf(ms, 0.1)
				slow = maxf(slow, ms)
	print("     bouwtijd auto met alles erop (ms): ", times)
	r.check(slow < 60.0, "een volledig aangepaste auto van een andere speler bouwen duurt kort (geen hapering in de race)", "traagste %.1f ms" % slow)

## UTF-16LE bytes back to text (as PowerShell reads -EncodedCommand)
static func _utf16(b: PackedByteArray) -> String:
	var s := ""
	var i := 0
	while i + 1 < b.size():
		var c := b[i] | (b[i + 1] << 8)
		i += 2
		if c >= 0xD800 and c < 0xDC00 and i + 1 < b.size():
			var lo := b[i] | (b[i + 1] << 8)
			i += 2
			c = 0x10000 + ((c - 0xD800) << 10) + (lo - 0xDC00)
		s += String.chr(c)
	return s

func _firewall() -> void:
	var exe := "'C:\\Program Files (x86)\\Kees' spelletjes\\Polderrace 3D\\Polderrace.exe'".replace("Kees'", "Kees''")
	var open := Net.fwOpenScript(exe)
	var check := Net.fwCheckScript(exe)
	for sc in [open, check, "Ünïcødé 🚗 \"x\" 'y' $z & %"]:
		var a := Net.psArgs(sc)
		var i := a.find("-EncodedCommand")
		var back := _utf16(Marshalls.base64_to_raw(a[i + 1])) if i >= 0 and i + 1 < a.size() else ""
		r.check(back == sc, "PowerShell-script komt ongeschonden aan (-EncodedCommand)", sc.substr(0, 40))
		# nothing on the command line that Godot would have to quote (no spaces or quotes in any argument)
		var plain := true
		for x in a:
			if x.contains(" ") or x.contains("\"") or x.contains("'"): plain = false
		r.check(plain, "geen spaties of aanhalingstekens op de opdrachtregel", str(a).substr(0, 80))
	r.check(open.begins_with("$e = " + exe + "\n") and open.contains("program=\"' + $e + '\"") and open.count("program=") == 2
		and open.contains("-Verb RunAs") and open.contains("-Wait -PassThru") and open.contains("catch { 'denied' }") and open.contains("'exit:' + $p.ExitCode"),
		"openzetten: netsh als beheerder, pad tussen dubbele aanhalingstekens, uitkomst terug", open)
	r.check(not open.contains("%") and not check.contains("%"), "geen %-tekens in de scripts (cmd zou ze uitvouwen)")
	r.check(check.contains("-Program " + exe + " ") and check.contains("'none'") and check.contains("'block'") and check.contains("'ok'"), "controle: zoekt de regels van dit programma", check)
	# what the player reads afterwards
	var denied := Net.fwResult(1, "denied")
	var ok := Net.fwResult(0, "exit:0\r\n".strip_edges())
	var fail := Net.fwResult(0, "exit:1")
	var none := Net.fwResult(-1, "")
	r.check(denied.contains("niet veranderd") and denied.contains("toestemming") and denied.contains("Een app toestaan"), "geen toestemming: duidelijke melding met wat je zelf kunt doen", denied)
	r.check(ok.contains("opengezet"), "gelukt: melding", ok)
	r.check(fail.contains("fout 1") and fail.contains("Een app toestaan"), "netsh faalt: melding met de fout", fail)
	r.check(none.contains("PowerShell") and none.contains("Een app toestaan"), "geen PowerShell: melding", none)
