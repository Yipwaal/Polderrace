extends RefCounted
## Online without a network: the parts of the net code that can be checked on their own (run by tests/test_net.py, also
## alone: godot --headless --path godot res://tests/runner.tscn -- netunit).
##  - the Windows firewall button: the PowerShell scripts go as -EncodedCommand (Godot does not escape double quotes inside
##    an argument), decode to exactly the script, quote the program path right, and every outcome gives a clear text.

var r: TestReport

func run(_host: Node) -> TestReport:
	r = TestReport.new("online zonder netwerk (firewall-knop, controles)")
	_firewall()
	return r

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
