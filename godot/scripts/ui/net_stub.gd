class_name NetStub
## Placeholder hook for the online screen (its own port, G6). The Online card on "Spelen" calls Game.netOpen() when
## game.gd has it (Menu.netOpen); until the online port adds it, this empty stub runs instead.
## The online port can plug its panel into the home board with Menu.registerPanel("net", content, nav) and open it
## with Menu.homePanel("net"); Menu.menuFlow = "net" + Menu.showMenu(0) picks a car and calls Game.netCarDone().

static func netOpen() -> void:
	pass
