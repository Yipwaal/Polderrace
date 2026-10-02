class_name UiKit
## The look of the HTML game's menus, built in code: the CSS design tokens of :root (ANWB-blue sign panels with a white
## line just inside the edge, yellow "detour" buttons, Nunito), and the widgets the menus are made of (.board, .cta,
## .ghost, .seg, .stepper, .opts/.opt, .togs/.tog, .card, .cupcard, .ccard, .chips, .story, .stats, ...).
## Sizes are CSS pixels: the window is not stretched, so 1 px here is 1 px in the browser. Labels get the CSS line-height
## of their rule (lh) through the font's top/bottom spacing, so boxes come out as high as in the browser.

# ------------------------------------------------------------------ design tokens (CSS :root)
const SIGN := Color("#1d4f9e")
const SIGN_INK := Color("#f7f7f2")
const DETOUR := Color("#f2c200")
const DETOUR_HI := Color("#ffd83d")
const INK := Color("#161a22")
const ALERT := Color("#c8302a")
const PAGE := Color("#3c5a80")
const SUB := Color("#d6e0f3")
const LAB := Color("#bcd0f0")
const WELL := Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.28)
const WELL_HI := Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.42)
const CARD := Color(1, 1, 1, 0.08)
const CARD_HI := Color(1, 1, 1, 0.14)
const LITE := Color(1, 1, 1, 0.12)
const LITE_HI := Color(1, 1, 1, 0.2)
const LINE := Color(247 / 255.0, 247 / 255.0, 242 / 255.0, 0.12)
const LINE2 := Color(247 / 255.0, 247 / 255.0, 242 / 255.0, 0.1)
const LINE3 := Color(247 / 255.0, 247 / 255.0, 242 / 255.0, 0.14)
const LINE4 := Color(247 / 255.0, 247 / 255.0, 242 / 255.0, 0.08)
const SHADE := Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.35)

# ------------------------------------------------------------------ fonts
static var _fonts := {}
static var _base: FontFile
const NATURAL_LH := 1.364      ## the browser's line box for Nunito (hhea ascent + descent) in em: CSS line-height normal

## Nunito at a weight (variable font), optionally slanted like a browser's synthetic italic, with letter spacing in px;
## size + lh (CSS line-height, 0 = normal): the line box is trimmed or padded at top and bottom to lh * size, like the
## browser's half-leading (Godot's own box is a pixel or two higher: it rounds ascent and descent up)
static func font(weight: int, italic := false, spacing := 0, size := 0, lh := 0.0) -> Font:
	if _base == null: _base = load("res://assets/fonts/Nunito-Variable.ttf")
	var top := 0
	var bot := 0
	if size > 0:
		var d := int(round((lh if lh > 0.0 else NATURAL_LH) * size - _base.get_height(size)))
		top = int(floor(d / 2.0))
		bot = d - top
	var key := "%d/%s/%d/%d/%d" % [weight, italic, spacing, top, bot]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = _base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		if italic:
			# FreeType matrix: x' = x + 0.2 y (the browser's synthetic oblique)
			v.variation_transform = Transform2D(Vector2(1, 0.2), Vector2(0, 1), Vector2.ZERO)
		if spacing != 0:
			v.spacing_glyph = spacing
		v.spacing_top = top
		v.spacing_bottom = bot
		_fonts[key] = v
	return _fonts[key]

## a label: text, weight, size (px), colour; wrap = break lines to the width it gets; lh = CSS line-height (0 = normal)
static func lbl(text: String, weight: int, size: int, col: Color, wrap := false, spacing := 0, italic := false, lh := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight, italic, spacing, size, lh))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("fs", [weight, italic, spacing, size, lh])
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 1
	return l

## change a label's weight (keeping size, spacing and line height)
static func reweight(l: Label, weight: int) -> void:
	var fs: Array = l.get_meta("fs", [weight, false, 0, l.get_theme_font_size("font_size"), 0.0])
	l.add_theme_font_override("font", font(weight, fs[1], fs[2], fs[3], fs[4]))

## .eyebrow / .lbl: 800 11px/1.2, letter-spacing .12em, upper case, light blue
static func eyebrow(text: String, col := LAB) -> Label:
	return lbl(text.to_upper(), 800, 11, col, false, 1, false, 1.2)

## .board h2: 900 36px/1, letter-spacing -.02em
static func h2(text: String) -> Label:
	return lbl(text, 900, 36, SIGN_INK, false, -1, false, 1.0)

## .note: 600 15px/1.55 (small: 13px), soft blue-white, wraps
static func note(text: String, small := false) -> Label:
	return lbl(text, 600, 13 if small else 15, SUB, true, 0, false, 1.55)

# ------------------------------------------------------------------ style boxes
static func flat(bg: Color, radius := 16, pad := Vector4.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	return s

static func pad_box(pad: Vector4) -> StyleBoxEmpty:
	var s := StyleBoxEmpty.new()
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	return s

## the blue road sign: blue, rounded, a 2 px white line 3-5 px inside the edge (CSS box-shadow inset 3px sign, inset 5px
## sign-ink) and a soft drop shadow (0 24px 48px -14px)
class SignStyle extends StyleBox:
	var bg := Color("#1d4f9e")
	var radius := 24
	var shadow := true
	var ring := true
	var _a: StyleBoxFlat
	var _b: StyleBoxFlat
	var _s: StyleBoxFlat
	func _init(r := 24, pad := Vector4(32, 30, 32, 30), with_ring := true) -> void:
		radius = r
		ring = with_ring
		content_margin_left = pad.x; content_margin_top = pad.y; content_margin_right = pad.z; content_margin_bottom = pad.w
		_a = StyleBoxFlat.new()
		_a.set_corner_radius_all(r); _a.corner_detail = 16; _a.anti_aliasing = true
		_b = StyleBoxFlat.new()
		_b.draw_center = false; _b.border_color = Color("#f7f7f2"); _b.set_border_width_all(2)
		_b.set_corner_radius_all(maxi(0, r - 3)); _b.corner_detail = 16; _b.anti_aliasing = true
		_s = StyleBoxFlat.new()
		_s.bg_color = Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.0); _s.set_corner_radius_all(r); _s.corner_detail = 12
		_s.shadow_color = Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.4); _s.shadow_size = 30; _s.shadow_offset = Vector2(0, 0)
	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if shadow:
			_s.draw(to_canvas_item, Rect2(rect.position + Vector2(14, 24 + 14), rect.size - Vector2(28, 28)))
		_a.bg_color = bg
		_a.draw(to_canvas_item, rect)
		if ring:
			_b.draw(to_canvas_item, rect.grow(-3))

static func board(pad := Vector4(32, 30, 32, 30), with_ring := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", SignStyle.new(24, pad, with_ring))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

# ------------------------------------------------------------------ the button (any clickable box with content)
## A clickable panel: sizes to its content (a PanelContainer), has normal/hover/checked/disabled looks, a focus ring like
## the browser's :focus-visible outline (3 px white, 3 px out), and `pressed`. Radio items (role=radio in the HTML) belong
## to a Radio group: arrows inside the group pick the next item, and only the checked one takes keyboard focus.
class Btn extends PanelContainer:
	signal pressed
	var sb_normal: StyleBox
	var sb_hover: StyleBox
	var sb_on: StyleBox
	var sb_on_hover: StyleBox
	var disabled := false: set = set_disabled
	var checked := false: set = set_checked
	var hovered := false
	var dis_alpha := 1.0
	## focus ring: offset from the edge (negative = inside), width, corner radius of the box itself
	var ring_off := 3.0
	var ring_w := 3.0
	var radius := 999.0
	var ring_col := Color.WHITE
	var ring_col_on := Color.WHITE
	var radio = null
	var value = null
	var watchers: Array = []
	var _ring := StyleBoxFlat.new()

	func _init(normal: StyleBox = null, hover: StyleBox = null, on: StyleBox = null) -> void:
		sb_normal = normal if normal != null else StyleBoxEmpty.new()
		sb_hover = hover if hover != null else sb_normal
		sb_on = on if on != null else sb_normal
		sb_on_hover = sb_on
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_ring.draw_center = false
		_ring.anti_aliasing = true
		_ring.corner_detail = 12
		restyle()

	func set_disabled(v: bool) -> void:
		disabled = v
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
		_focus_mode()
		restyle()

	func set_checked(v: bool) -> void:
		checked = v
		_focus_mode()
		restyle()

	## like a browser button: a disabled one takes no focus; in a radio group only the checked one takes keyboard focus
	func _focus_mode() -> void:
		if disabled: focus_mode = Control.FOCUS_NONE
		elif radio != null: focus_mode = Control.FOCUS_ALL if checked else Control.FOCUS_CLICK
		else: focus_mode = Control.FOCUS_ALL

	## cb(checked: bool, hovered: bool) runs whenever the look changes (recolour the texts inside)
	func watch(cb: Callable) -> void:
		watchers.append(cb)
		cb.call(checked, hovered)

	## a label inside that changes colour (and weight) when checked
	func tint(l: Label, off: Color, on: Color, w_off := 0, w_on := 0) -> Label:
		watch(func(c: bool, _h: bool) -> void:
			l.add_theme_color_override("font_color", on if c else off)
			if w_off > 0: UiKit.reweight(l, w_on if c else w_off))
		return l

	func restyle() -> void:
		var sb: StyleBox = sb_normal
		if checked:
			sb = sb_on_hover if hovered and not disabled else sb_on
		elif hovered and not disabled:
			sb = sb_hover
		add_theme_stylebox_override("panel", sb)
		modulate.a = dis_alpha if disabled else 1.0
		for cb in watchers:
			cb.call(checked, hovered)
		queue_redraw()

	func press() -> void:
		if not disabled:
			pressed.emit()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				accept_event()
				press()

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_MOUSE_ENTER:
				hovered = true; restyle()
			NOTIFICATION_MOUSE_EXIT:
				hovered = false; restyle()
			NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
				queue_redraw()

	func _draw() -> void:
		if not has_focus(true):
			return
		var g := ring_off + ring_w
		_ring.border_color = ring_col_on if checked else ring_col
		_ring.set_border_width_all(int(ring_w))
		_ring.set_corner_radius_all(int(maxf(0.0, minf(radius, minf(size.x, size.y) / 2) + g)))
		_ring.draw(get_canvas_item(), Rect2(Vector2.ZERO, size).grow(g))

## a radio group (role=radiogroup): onPick(value) runs on a click or an arrow key; sync(value) checks the chosen one
class Radio extends RefCounted:
	var items: Array = []
	var on_pick: Callable
	func _init(cb: Callable = Callable()) -> void:
		on_pick = cb
	func add(b, v) -> void:
		b.radio = self
		b.value = v
		items.append(b)
		b.pressed.connect(func() -> void:
			if on_pick.is_valid(): on_pick.call(v))
	func sync(v) -> void:
		for b in items:
			b.checked = b.value == v
	func opts() -> Array:
		return items.filter(func(b): return is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled)
	func find(v):
		for b in items:
			if b.value == v: return b
		return null
	func checked_item():
		for b in items:
			if b.checked: return b
		return null
	## arrow keys inside the group (JS radio keydown): pick the next or previous item and focus it
	func arrow(cur, d: int) -> void:
		var o := opts()
		var i := o.find(cur)
		if i < 0: return
		var nb = o[(i + d + o.size()) % o.size()]
		if on_pick.is_valid(): on_pick.call(nb.value)
		if is_instance_valid(nb) and nb.is_visible_in_tree():
			UiKit.focus(nb, true)

## focus a control the way JS .focus() does after a key (ring shown), or quietly after a mouse click.
## scroll = false is JS focus({preventScroll:true}), what the menus use when a panel opens: the scroll containers around
## it do not follow (they would also measure a layout that is not sorted yet); keyboard steps pass scroll = true
static var pointer := false
static func focus(c: Control, scroll := false) -> void:
	if c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE:
		var held: Array[ScrollContainer] = []
		if not scroll:
			var p := c.get_parent()
			while p != null:
				if p is ScrollContainer and p.follow_focus:
					p.follow_focus = false
					held.append(p)
				p = p.get_parent()
		c.grab_focus(pointer)
		for s in held: s.follow_focus = true

# ------------------------------------------------------------------ layout containers
## a row that wraps like CSS flex-wrap with justify-content:space-between: the first child (a label) takes the free
## space; when the others do not fit beside it they move to the next line
class FlexRow extends Container:
	var gap := 12.0
	var vgap := 10.0
	var grow_first := true
	var min_first := 80.0
	var align_center := true
	## items as wide as their content (CSS flex-basis auto: a long title takes its own line), not their minimum
	var auto_basis := false
	func _init(g := 12.0, vg := 10.0) -> void:
		gap = g
		vgap = vg
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _kids() -> Array:
		return get_children().filter(func(c): return c is Control and c.visible and not c.top_level)
	func _mw(c: Control, first: bool) -> float:
		var mw: float = c.get_combined_minimum_size().x
		if auto_basis: mw = minf(maxf(mw, UiKit.pref_w(c)), maxf(size.x, mw))
		if first and grow_first: mw = maxf(mw, min_first)
		return mw
	func _layout(w: float) -> Array:
		var lines := []
		var cur := []
		var x := 0.0
		var ks := _kids()
		for k in ks.size():
			var c: Control = ks[k]
			var mw := _mw(c, k == 0)
			if not cur.is_empty() and x + gap + mw > w + 0.5:
				lines.append(cur); cur = []; x = 0.0
			x += (gap if not cur.is_empty() else 0.0) + mw
			cur.append(c)
		if not cur.is_empty(): lines.append(cur)
		return lines
	func _get_minimum_size() -> Vector2:
		var w := size.x if size.x > 0 else 100000.0
		var h := 0.0
		var mw := 0.0
		var lines := _layout(w)
		for ln in lines:
			var lh := 0.0
			for c in ln:
				var ms: Vector2 = c.get_combined_minimum_size()
				lh = maxf(lh, ms.y)
				mw = maxf(mw, ms.x)
			h += lh
		h += vgap * maxf(0, lines.size() - 1)
		return Vector2(mw, h)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var y := 0.0
			var lines := _layout(size.x)
			for ln in lines:
				var lh := 0.0
				var tw := 0.0
				var ws := []
				for k in ln.size():
					var c: Control = ln[k]
					var w: float = c.get_combined_minimum_size().x
					if auto_basis: w = minf(maxf(w, UiKit.pref_w(c)), maxf(size.x, w))
					ws.append(w)
					tw += w
				tw += gap * (ln.size() - 1)
				var free := maxf(0.0, size.x - tw)
				var x := 0.0
				for k in ln.size():
					var c: Control = ln[k]
					var w: float = ws[k]
					if k == 0 and grow_first and ln.size() > 1: w += free
					elif ln.size() == 1 and (c.size_flags_horizontal & Control.SIZE_EXPAND): w = size.x
					if k == ln.size() - 1 and k > 0 and not grow_first: x = size.x - w
					var mh: float = c.get_combined_minimum_size().y
					lh = maxf(lh, mh)
					fit_child_in_rect(c, Rect2(x, y, w, mh))
					x += w + gap
				if align_center:
					for c in ln:
						var mh2: float = c.get_combined_minimum_size().y
						c.position.y = y + (lh - mh2) / 2.0
				y += lh + vgap
		elif what == NOTIFICATION_RESIZED:
			update_minimum_size()

## the width a control would like (CSS max-content): wrapped labels on one line, boxes the sum or the widest of their items
static func pref_w(c: Control) -> float:
	var mw: float = c.get_combined_minimum_size().x
	if c is Label:
		var l: Label = c
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF: return mw
		var f := l.get_theme_font("font")
		var s := l.get_theme_font_size("font_size")
		var w := 0.0
		for line in l.text.split("\n"):
			w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
		return maxf(mw, ceilf(w) + 1)
	if c is BoxContainer:
		var vert := c is VBoxContainer
		var sep: int = c.get_theme_constant("separation")
		var w := 0.0
		var n := 0
		for k in c.get_children():
			if k is Control and k.visible and not k.top_level:
				var pw := pref_w(k)
				w = maxf(w, pw) if vert else w + pw
				n += 1
		if not vert: w += sep * maxi(0, n - 1)
		return maxf(mw, w)
	if c is MarginContainer or c is PanelContainer:
		var pad := 0.0
		if c is MarginContainer:
			pad = c.get_theme_constant("margin_left") + c.get_theme_constant("margin_right")
		else:
			var sb: StyleBox = c.get_theme_stylebox("panel")
			if sb != null: pad = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
		var w := 0.0
		for k in c.get_children():
			if k is Control and k.visible: w = maxf(w, pref_w(k))
		return maxf(mw, w + pad)
	return mw

## a grid of equal columns (CSS grid-template-columns: repeat(n, minmax(0, 1fr))); a row is as high as its tallest item.
## min_col > 0: as many columns of at least that width as fit, but no more than there are items (repeat(auto-fit, minmax()))
class EqGrid extends Container:
	var cols := 2
	var hgap := 8.0
	var vgap := 8.0
	var min_col := 0.0
	func _init(n := 2, hg := 8.0, vg := 8.0) -> void:
		cols = n; hgap = hg; vgap = vg
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _kids() -> Array:
		return get_children().filter(func(c): return c is Control and c.visible and not c.top_level)
	func _ncols(w: float, n: int) -> int:
		if min_col <= 0.0: return cols
		return clampi(int(floor((w + hgap) / (min_col + hgap))), 1, maxi(1, n))
	func _rows(w: float) -> Array:
		var ks := _kids()
		var nc := _ncols(w, ks.size())
		var out := []
		var r := 0
		while r * nc < ks.size():
			out.append(ks.slice(r * nc, mini(ks.size(), r * nc + nc)))
			r += 1
		return [out, nc]
	func _get_minimum_size() -> Vector2:
		var w := size.x if size.x > 0 else 1000.0
		var rr := _rows(w)
		var h := 0.0
		var mw := 0.0
		for row in rr[0]:
			var rh := 0.0
			for c in row:
				var ms: Vector2 = c.get_combined_minimum_size()
				rh = maxf(rh, ms.y); mw = maxf(mw, ms.x)
			h += rh
		h += vgap * maxf(0, rr[0].size() - 1)
		return Vector2(mw * (1 if min_col > 0 else rr[1]) + (0.0 if min_col > 0 else hgap * (rr[1] - 1)), h)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var rr := _rows(size.x)
			var nc: int = rr[1]
			var cw := (size.x - hgap * (nc - 1)) / nc
			var y := 0.0
			for row in rr[0]:
				var rh := 0.0
				for c in row: rh = maxf(rh, c.get_combined_minimum_size().y)
				for k in row.size():
					fit_child_in_rect(row[k], Rect2(k * (cw + hgap), y, cw, rh))
				y += rh + vgap
		elif what == NOTIFICATION_RESIZED:
			update_minimum_size()

static func vbox(gap := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func hbox(gap := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func panel(sb: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func spacer(h := 0.0, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func expander() -> Control:
	var c := spacer()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## a 1 px line (the borders between rows of .opts, .togs, .upgs, ...)
static func hline(col := LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func margin(c: Control, pad: Vector4) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(pad.x)); m.add_theme_constant_override("margin_top", int(pad.y))
	m.add_theme_constant_override("margin_right", int(pad.z)); m.add_theme_constant_override("margin_bottom", int(pad.w))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

## the content of a panel that scrolls (CSS: the panel scrolls inside the board with margin-right:-10px;padding-right:10px,
## so the scroll area reaches 10 px into the board's padding and the thin bar sits there). Add outer(scroll) to the tree.
static func scroller(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	s.scroll_deadzone = 8
	var bar := s.get_v_scroll_bar()
	var grab := flat(Color(SIGN_INK, 0.28), 999)
	var grab_hi := flat(Color(SIGN_INK, 0.45), 999)
	var track := StyleBoxEmpty.new()
	bar.custom_minimum_size.x = 6
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hi)
	var m := margin(content, Vector4(0, 0, 10, 0))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(m)
	# the content ends 10 px from the scroll area's right edge, with or without the bar: whether the ScrollContainer
	# took the bar's width off the content depends on when the bar appeared, so look at what it did
	# (after the layout has settled: once per frame at most; the content keeps the same width either way)
	var fit := func() -> void:
		if not is_instance_valid(m) or not is_instance_valid(s): return
		m.remove_meta("fit_q")
		# at most the 10 px: in a window too narrow for the content, m is wider than the scroll area, and a margin that
		# grew with it would widen m again, re-queue this, and loop until the message queue overflows (a crash)
		var want := clampi(10 - int(round(s.size.x - m.size.x)), 0, 10)
		if m.get_theme_constant("margin_right") != want: m.add_theme_constant_override("margin_right", want)
	var queue := func() -> void:
		if not is_instance_valid(m) or m.has_meta("fit_q"): return
		m.set_meta("fit_q", true)
		fit.call_deferred()
	m.resized.connect(queue)
	s.resized.connect(queue)
	bar.visibility_changed.connect(queue)
	var o := margin(s, Vector4(0, 0, -10, 0))
	o.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.set_meta("outer", o)
	return s

static func outer(s: ScrollContainer) -> Control:
	return s.get_meta("outer")

# ------------------------------------------------------------------ overlay screens
## an overlay screen (CSS .overlay / .overlay.menu): the board left beside the 3D view or centred, with the page padding
## of the CSS media queries; full = the board fills the window's height (home panels, race setup) and scrolls inside,
## otherwise it is as high as its content, centred vertically, and the overlay scrolls when it does not fit
class Holder extends Container:
	var board: Control
	var left := true
	var full := false
	var max_w := 540.0
	func _init(b: Control) -> void:
		board = b
		add_child(b)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.minimum_size_changed.connect(update_minimum_size)
	func _pad(w: float) -> Vector2:
		if not left: return Vector2(20, 20)
		if w <= 760: return Vector2(16, 16)
		if w <= 960: return Vector2(28, 32)
		return Vector2(64, 40)
	func _vp() -> Vector2:
		return get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	func _get_minimum_size() -> Vector2:
		if full or board == null or not board.visible: return Vector2.ZERO
		var p := _pad(_vp().x)
		return Vector2(0, board.get_combined_minimum_size().y + p.y * 2)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN and board != null:
			var p := _pad(size.x)
			var w := minf(max_w, size.x - p.x * 2)
			var x := p.x if left and size.x > 760 else (size.x - w) / 2.0
			if full:
				var y0 := 20.0 if size.x > 760 else p.y
				fit_child_in_rect(board, Rect2(x, y0, w, size.y - y0 * 2))
			else:
				var h: float = board.get_combined_minimum_size().y
				fit_child_in_rect(board, Rect2(x, maxf(p.y, (size.y - h) / 2.0), w, h))

## the screen behind a board: "menu" = dark gradient to the right (beside the panel), "main" = gradient to the bottom,
## "blur" = the scene blurred and tinted (CSS backdrop-filter: blur(18px) on rgba(22,26,34,.22))
class Backdrop extends Control:
	var mode := "menu"
	func _init(m := "menu") -> void:
		mode = m
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if m == "blur":
			for k in 2:
				var bb := BackBufferCopy.new()
				bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
				add_child(bb)
				var r := ColorRect.new()
				r.set_anchors_preset(Control.PRESET_FULL_RECT)
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var sm := ShaderMaterial.new()
				sm.shader = UiKit.blur_shader()
				sm.set_shader_parameter("dir", Vector2(1, 0) if k == 0 else Vector2(0, 1))
				sm.set_shader_parameter("tint", Color(22 / 255.0, 26 / 255.0, 34 / 255.0, 0.0 if k == 0 else 0.22))
				r.material = sm
				add_child(r)
	func set_mode(m: String) -> void:
		mode = m
		for c in get_children(): c.visible = m == "blur"
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if mode == "menu":
			if size.x <= 760:
				draw_rect(r, Color(15 / 255.0, 28 / 255.0, 50 / 255.0, 0.35))
				return
			var g := Gradient.new()
			g.set_color(0, Color(15 / 255.0, 28 / 255.0, 50 / 255.0, 0.55))
			g.set_color(1, Color(15 / 255.0, 28 / 255.0, 50 / 255.0, 0.0))
			g.set_offset(1, 0.6)
			_grad(g, r, false)
		elif mode == "main":
			var g := Gradient.new()
			g.set_color(0, Color(15 / 255.0, 28 / 255.0, 50 / 255.0, 0.15))
			g.set_color(1, Color(15 / 255.0, 28 / 255.0, 50 / 255.0, 0.6))
			_grad(g, r, true)
	var _tex := {}
	## a smooth gradient as a small texture stretched over the screen (made right away, so the first frame has it)
	func _grad(g: Gradient, r: Rect2, vertical: bool) -> void:
		if not _tex.has(mode):
			var img := Image.create(1 if vertical else 256, 256 if vertical else 1, false, Image.FORMAT_RGBA8)
			for k in 256:
				var c := g.sample(k / 255.0)
				if vertical: img.set_pixel(0, k, c)
				else: img.set_pixel(k, 0, c)
			_tex[mode] = ImageTexture.create_from_image(img)
		draw_texture_rect(_tex[mode], r, false)

static var _blur: Shader
static func blur_shader() -> Shader:
	if _blur == null:
		_blur = Shader.new()
		_blur.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 dir = vec2(1.0, 0.0);
uniform vec4 tint = vec4(0.0);
void fragment() {
	// gaussian, sigma 18 px (CSS blur(18px)), 25 taps 3 px apart
	vec3 c = vec3(0.0);
	float n = 0.0;
	for (int i = -12; i <= 12; i++) {
		float x = float(i) * 3.0;
		float w = exp(-x * x / (2.0 * 18.0 * 18.0));
		c += texture(screen_tex, SCREEN_UV + dir * x * SCREEN_PIXEL_SIZE).rgb * w;
		n += w;
	}
	c /= n;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
"""
	return _blur

# ------------------------------------------------------------------ buttons
static func _shadowed(s: StyleBoxFlat) -> StyleBoxFlat:
	s.shadow_color = Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.3)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 8)
	return s

## .cta: the yellow detour pill (900 18px/1, 15px 30px)
static func cta(text: String, pad := Vector4(30, 15, 30, 15), size := 18) -> Btn:
	var n := _shadowed(flat(DETOUR, 999, pad))
	var h := _shadowed(flat(DETOUR_HI, 999, pad))
	var b := Btn.new(n, h)
	b.dis_alpha = 0.5
	var l := lbl(text, 900, size, INK, false, 0, false, 1.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.set_meta("label", l)
	return b

## .ghost (dark well, 800 16px/1, 14px 24px) or .ghost.lite (lighter)
static func ghost(text: String, lite := false, pad := Vector4(24, 14, 24, 14), size := 16) -> Btn:
	var n := flat(LITE if lite else WELL, 999, pad)
	var h := flat(LITE_HI if lite else WELL_HI, 999, pad)
	var b := Btn.new(n, h)
	var l := lbl(text, 800, size, SIGN_INK, false, 0, false, 1.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	b.set_meta("label", l)
	return b

static func btn_text(b: Btn, t: String) -> void:
	var l: Label = b.get_meta("label")
	l.text = t

## .linkbtn: plain text button (800 14px)
static func linkbtn(text: String) -> Btn:
	var b := Btn.new(pad_box(Vector4(0, 6, 0, 6)))
	b.radius = 6
	var l := lbl(text, 800, 14, SIGN_INK)
	b.add_child(l)
	b.watch(func(_c: bool, h: bool) -> void: l.add_theme_color_override("font_color", DETOUR_HI if h else SIGN_INK))
	return b

## .chip (800 13px/1, 9px 12px); pressed/checked = yellow
static func chip(text: String) -> Btn:
	var pad := Vector4(12, 9, 12, 9)
	var b := Btn.new(flat(LITE, 999, pad), flat(LITE_HI, 999, pad), flat(DETOUR, 999, pad))
	var l := lbl(text, 800, 13, SIGN_INK, false, 0, false, 1.0)
	b.add_child(l)
	b.tint(l, SIGN_INK, INK, 800, 900)
	return b

## .seg: a pill-shaped radio group; items [[value, text], ...]. full = items share the width; alt = checked is white;
## big = the mode/class segs (15px, 12px 4px); pad = the item padding (CSS .seg button: 9px 12px)
static func seg(items: Array, on_pick: Callable, full := false, alt := false, big := false, pad := Vector4(12, 9, 12, 9)) -> Array:
	var box := panel(flat(WELL, 999, Vector4(5, 5, 5, 5)))
	# full/big: every item equally wide (CSS flex:1); otherwise as wide as its text
	var row: Container = EqGrid.new(items.size(), 2, 0) if (full or big) else hbox(2)
	box.add_child(row)
	var rg := Radio.new(on_pick)
	if big: pad = Vector4(4, 12, 4, 12)
	elif full: pad = Vector4(0, 10, 0, 10)
	for it in items:
		var b := Btn.new(pad_box(pad), pad_box(pad), flat(SIGN_INK if alt else DETOUR, 999, pad))
		b.ring_off = -3.0
		b.ring_col_on = INK
		b.dis_alpha = 0.4
		var l := lbl(str(it[1]), 800, 15 if big else 14, SIGN_INK, false, 0, false, 1.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(l)
		b.tint(l, SIGN_INK, SIGN if alt else INK, 800, 900)
		b.set_meta("label", l)
		if full or big:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		rg.add(b, it[0])
	if full or big:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return [box, rg]

## .stepper: − value + (buttons 34 px round)
static func stepper(on_step: Callable) -> Dictionary:
	var box := panel(flat(WELL, 999, Vector4(5, 5, 5, 5)))
	var row := hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var mk := func(t: String, d: int) -> Btn:
		var b := Btn.new(flat(LITE, 999), flat(LITE_HI, 999))
		b.custom_minimum_size = Vector2(34, 34)
		b.ring_off = -3.0
		b.dis_alpha = 0.45
		var l := lbl(t, 900, 18, SIGN_INK, false, 0, false, 1.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		b.pressed.connect(func() -> void: on_step.call(d))
		return b
	var minus: Btn = mk.call("−", -1)
	var out := lbl("0", 900, 20, SIGN_INK)
	out.custom_minimum_size.x = 30
	out.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus: Btn = mk.call("+", 1)
	row.add_child(minus); row.add_child(out); row.add_child(plus)
	return {"box": box, "minus": minus, "plus": plus, "out": out}

## disabled stepper buttons lose their background too (CSS .stepper button:disabled)
static func stepper_sync(st: Dictionary, v: int, lo: int, hi: int) -> void:
	st.out.text = str(v)
	for pair in [[st.minus, v <= lo], [st.plus, v >= hi]]:
		var b: Btn = pair[0]
		var dis: bool = pair[1]
		b.sb_normal = StyleBoxEmpty.new() if dis else flat(LITE, 999)
		b.disabled = dis

# ------------------------------------------------------------------ cards and rows
## .opts / .togs / .upgs: a card holding rows separated by thin lines
static func rows_card(rows: Array, line := LINE) -> PanelContainer:
	var p := panel(flat(CARD, 16))
	var v := vbox(0)
	p.add_child(v)
	for k in rows.size():
		if k > 0 and line.a > 0: v.add_child(hline(line))
		v.add_child(rows[k])
	return p

## the label column of an .opt row: .optl (800 16px/1.2) with an optional .optsub (600 12px/1.3)
static func optl(text: String, sub := "", size := 16) -> VBoxContainer:
	var v := vbox(2)
	v.add_child(lbl(text, 800, size, SIGN_INK, true, 0, false, 1.2))
	if sub != "":
		v.add_child(lbl(sub, 600, 12, SUB, true, 0, false, 1.3))
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v

## .opt: label left, control right (wraps below on a narrow board); padding 12px 12px 12px 18px
static func opt(label: Control, ctrl: Control, pad := Vector4(18, 12, 12, 12)) -> MarginContainer:
	var r := FlexRow.new(12, 10)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(label)
	r.add_child(ctrl)
	return margin(r, pad)

## .tog: a switch row (role=switch); returns the Btn; set .checked to switch it
static func tog(title: String, sub: String) -> Btn:
	var pad := Vector4(18, 14, 18, 14)
	var b := Btn.new(pad_box(pad))
	b.ring_off = -3.0
	b.radius = 12
	var row := hbox(12)
	b.add_child(row)
	var v := vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lbl(title, 800, 16, SIGN_INK, true, 0, false, 1.2))
	v.add_child(lbl(sub, 600, 13, SUB, true, 0, false, 1.3))
	row.add_child(v)
	var sw := Switch.new()
	sw.custom_minimum_size = Vector2(50, 30)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sw)
	b.watch(func(c: bool, _h: bool) -> void: sw.on = c; sw.queue_redraw())
	return b

class Switch extends Control:
	var on := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var tr := StyleBoxFlat.new()
		tr.bg_color = Color("#f2c200") if on else Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.35)
		tr.set_corner_radius_all(15); tr.anti_aliasing = true; tr.corner_detail = 12
		tr.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		draw_circle(Vector2(35 if on else 15, 15), 12, Color("#161a22") if on else Color("#f7f7f2"), true, -1, true)

## the rounded icon box of a cupcard (.cupletter, 44 px)
static func cupletter(content: Control) -> PanelContainer:
	var p := panel(flat(WELL, 15))
	p.custom_minimum_size = Vector2(44, 44)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(content)
	return p

## .cupcard: icon box, title + small line, status on the right; sel = yellow
static func cupcard(icon: Control, title: String, sub: String) -> Btn:
	var pad := Vector4(18, 16, 18, 16)
	var b := Btn.new(flat(CARD, 16, pad), flat(CARD_HI, 16, pad), flat(DETOUR, 16, pad))
	b.radius = 16
	var row := hbox(16)
	b.add_child(row)
	var cl := cupletter(icon)
	row.add_child(cl)
	var body := vbox(3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := lbl(title, 800, 18, SIGN_INK, true, 0, false, 1.15)
	var s := lbl(sub, 600, 13, SUB, true, 0, false, 1.3)
	body.add_child(t); body.add_child(s)
	row.add_child(body)
	b.tint(t, SIGN_INK, INK, 800, 900)
	b.tint(s, SUB, INK, 600, 700)
	var em := hbox(4)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(em)
	b.set_meta("title", t); b.set_meta("sub", s); b.set_meta("em", em); b.set_meta("letter", cl)
	b.watch(func(c: bool, _h: bool) -> void:
		cl.add_theme_stylebox_override("panel", flat(INK if c else WELL, 15))
		for ch in cl.get_children():
			if ch is Label: ch.add_theme_color_override("font_color", DETOUR if c else SIGN_INK)
			elif ch is Icon: ch.col = DETOUR if c else SIGN_INK; ch.queue_redraw()
		for ch in em.get_children():
			if ch is Label: ch.add_theme_color_override("font_color", INK if c else SIGN_INK)
			elif ch is Icon: ch.col = INK if c else SIGN_INK; ch.queue_redraw())
	return b

## the status at the right of a cupcard (.cupcard em: 800 13px), with an optional icon in front
static func cup_status(b: Btn, text: String, icon_kind := "") -> void:
	var em: HBoxContainer = b.get_meta("em")
	for c in em.get_children(): c.queue_free()
	if icon_kind != "":
		em.add_child(icon(icon_kind, 13, 2.4, INK if b.checked else SIGN_INK))
	if text != "":
		em.add_child(lbl(text, 800, 13, INK if b.checked else SIGN_INK))

## .ccard: small car card (name + badge, one line under it)
static func ccard() -> Btn:
	var pad := Vector4(14, 12, 14, 12)
	var b := Btn.new(flat(CARD, 16, pad), flat(CARD_HI, 16, pad), flat(DETOUR, 16, pad))
	b.radius = 16
	var v := vbox(4)
	b.add_child(v)
	return b

## .badge / .tuned: a small pill (yellow; dark on a checked card)
static func badge(text: String) -> PanelContainer:
	var p := panel(flat(DETOUR, 999, Vector4(8, 5, 8, 5)))
	var l := lbl(text, 800, 11, INK, false, 0, false, 1.0)
	p.add_child(l)
	p.set_meta("label", l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

static func badge_on(p: PanelContainer, on: bool) -> void:
	p.add_theme_stylebox_override("panel", flat(INK if on else DETOUR, 999, Vector4(8, 5, 8, 5)))
	(p.get_meta("label") as Label).add_theme_color_override("font_color", DETOUR if on else INK)

## .credits: white pill with the money (900 15px/1)
static func credits_pill() -> PanelContainer:
	var p := panel(flat(SIGN_INK, 999, Vector4(13, 9, 13, 9)))
	var l := lbl("", 900, 15, SIGN, false, 0, false, 1.0)
	p.add_child(l)
	p.set_meta("label", l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

static func pill_text(p: Control, t: String) -> void:
	(p.get_meta("label") as Label).text = t

## .tag (yellow) / .earn (white): 900 13px/1 pills on the results screen
static func tag(text: String, earn := false) -> PanelContainer:
	var p := panel(flat(SIGN_INK if earn else DETOUR, 999, Vector4(12, 8, 12, 8)))
	var l := lbl(text, 900, 13, SIGN if earn else INK, false, 0, false, 1.0)
	p.add_child(l)
	p.set_meta("label", l)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return p

## kbd: a key cap (800 12px/1, white pill)
static func kbd(text: String, shadow := false) -> PanelContainer:
	var s := flat(SIGN_INK, 999, Vector4(9, 5, 9, 5))
	if shadow:
		s.shadow_color = Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.3); s.shadow_size = 8; s.shadow_offset = Vector2(0, 4)
	var p := panel(s)
	var l := lbl(text, 800, 12, SIGN, false, 0, false, 1.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 21.6 - 18
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## a progress bar (.bar: 8 px, yellow on dark)
class Bar extends Control:
	var v := 0.0
	var track := Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.35)
	var fill := Color("#f2c200")
	var h := 8.0
	func _init(height := 8.0) -> void:
		h = height
		custom_minimum_size = Vector2(0, height)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(int(h / 2)); s.anti_aliasing = true; s.corner_detail = 8
		s.bg_color = track
		s.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if v > 0.0:
			s.bg_color = fill
			s.draw(get_canvas_item(), Rect2(0, 0, maxf(h, size.x * clampf(v, 0, 1)), size.y))

## .stat: "Top ▬▬▬▬▬ 258" (label 44 px, bar, value 34 px right-aligned; 700 12px)
static func stat(label: String, v: float, txt: String) -> HBoxContainer:
	var r := hbox(8)
	var a := lbl(label, 700, 12, SUB)
	a.custom_minimum_size.x = 44
	var b := Bar.new(6)
	b.v = v
	b.track = Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.3)
	b.fill = SIGN_INK
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c := lbl(txt, 700, 12, SIGN_INK)
	c.custom_minimum_size.x = 34
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(a); r.add_child(b); r.add_child(c)
	r.set_meta("parts", [a, b, c])
	return r

## a checked card turns the stat rows dark (CSS [aria-checked=true] .stat)
static func stat_on(r: HBoxContainer, on: bool, lab_col := SUB, val_col := SIGN_INK) -> void:
	var p: Array = r.get_meta("parts")
	p[0].add_theme_color_override("font_color", INK if on else lab_col)
	p[1].track = Color(22 / 255.0, 26 / 255.0, 34 / 255.0, 0.18) if on else Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.3)
	p[1].fill = INK if on else SIGN_INK
	p[1].queue_redraw()
	p[2].add_theme_color_override("font_color", INK if on else val_col)

# ------------------------------------------------------------------ icons (the HTML's inline SVGs, drawn with lines)
## stroke icons on a 24 px grid: flag, bolt, road, cup, globe, lock, check
class Icon extends Control:
	var kind := ""
	var col := Color("#f7f7f2")
	var w := 2.2
	func _init(k: String, px := 22.0, stroke := 2.2) -> void:
		kind = k
		w = stroke
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _p(x: float, y: float) -> Vector2:
		return Vector2(x, y) * size.x / 24.0
	func _lw() -> float:
		return w * size.x / 24.0
	func _pl(pts: Array) -> void:
		var a := PackedVector2Array()
		for p in pts: a.append(_p(p[0], p[1]))
		draw_polyline(a, col, _lw(), true)
		for p in [a[0], a[a.size() - 1]]: draw_circle(p, _lw() / 2, col, true, -1, true)
	func _arc(cx: float, cy: float, r: float, a0: float, a1: float) -> void:
		draw_arc(_p(cx, cy), r * size.x / 24.0, a0, a1, 32, col, _lw(), true)
	func _draw() -> void:
		match kind:
			"flag":
				_pl([[5, 3], [5, 21]]); _pl([[5, 4], [16, 4], [14, 8], [16, 12], [5, 12]])
			"bolt":
				_pl([[13, 2], [4, 14], [11, 14], [10, 22], [19, 10], [12, 10], [13, 2]])
			"road":
				_pl([[4, 20], [8, 4], [16, 4], [20, 20]]); _pl([[12, 7], [12, 9]]); _pl([[12, 12], [12, 14]]); _pl([[12, 17], [12, 19]])
			"cup":
				_pl([[8, 8], [8, 3], [16, 3], [16, 8]]); _arc(12, 8, 4, 0, PI)
				_pl([[8, 5], [5, 5]]); _arc(8, 8, 3, PI * 0.5, PI * 1.5)
				_pl([[16, 5], [19, 5]]); _arc(16, 8, 3, -PI * 0.5, PI * 0.5)
				_pl([[12, 12], [12, 16]]); _pl([[8, 20], [16, 20]]); _pl([[10, 16], [14, 16], [14, 20], [10, 20], [10, 16]])
			"globe":
				_arc(12, 12, 9, 0, TAU); _pl([[3, 12], [21, 12]])
				var a := PackedVector2Array()
				for k in 33:
					var t := TAU * k / 32.0
					a.append(_p(12 + cos(t) * 4.5, 12 + sin(t) * 9))
				draw_polyline(a, col, _lw(), true)
			"lock":
				var s := StyleBoxFlat.new()
				s.draw_center = false; s.border_color = col; s.set_border_width_all(maxi(1, int(round(_lw()))))
				s.set_corner_radius_all(int(2.5 * size.x / 24.0)); s.anti_aliasing = true
				s.draw(get_canvas_item(), Rect2(_p(5, 11), _p(14, 9)))
				_pl([[8, 11], [8, 8]]); _arc(12, 8, 4, PI, TAU); _pl([[16, 8], [16, 11]])
			"check":
				_pl([[5, 12.5], [9.5, 17], [19, 7.5]])

static func icon(kind: String, px := 22.0, stroke := 2.2, col := SIGN_INK) -> Icon:
	var i := Icon.new(kind, px, stroke)
	i.col = col
	return i

# ------------------------------------------------------------------ story lines (career)
## .sline: a round avatar with the speaker's initial, the name in yellow, then the text
static func story_line(name: String, col: String, ink: String, text: String) -> HBoxContainer:
	var r := hbox(12)
	var av := Avatar.new()
	av.col = Color(col)
	av.ink = Color(ink) if ink != "" else SIGN_INK
	av.letter = name.trim_prefix("Opa ").trim_prefix("De ").substr(0, 1)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.add_child(av)
	var v := vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lbl(name, 900, 13, DETOUR, false, 0, false, 1.2))
	v.add_child(lbl(text, 600, 14, SIGN_INK, true, 0, false, 1.45))
	r.add_child(v)
	return r

class Avatar extends Control:
	var col := Color.WHITE
	var ink := Color.WHITE
	var letter := ""
	func _init() -> void:
		custom_minimum_size = Vector2(38, 38)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2(19, 19), 19, col, true, -1, true)
		draw_arc(Vector2(19, 19), 18, 0, TAU, 40, Color(1, 1, 1, 0.4), 2, true)
		var f := UiKit.font(900)
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		draw_string(f, Vector2(19 - w.x / 2, 19 + (f.get_ascent(17) - f.get_descent(17)) / 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ink)

## .story: a card with story lines
static func story_box() -> PanelContainer:
	var p := panel(flat(CARD, 16, Vector4(16, 14, 16, 14)))
	p.add_child(vbox(12))
	return p

static func story_clear(p: PanelContainer) -> VBoxContainer:
	var v: VBoxContainer = p.get_child(0)
	for c in v.get_children():
		v.remove_child(c)
		c.queue_free()
	return v

# ------------------------------------------------------------------ a swatch (.sw) for the paint colours
static func swatch(c: Color) -> Btn:
	var b := Btn.new(StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(30, 30)
	b.ring_off = 2.0
	b.ring_w = 2.0
	var sw := Swatch.new()
	sw.col = c
	b.add_child(sw)
	b.watch(func(on: bool, _h: bool) -> void: sw.on = on; sw.queue_redraw())
	return b

class Swatch extends Control:
	var col := Color.WHITE
	var on := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := size.x / 2
		var c := size / 2
		if on:
			draw_circle(c, r + 6, Color("#f2c200"), true, -1, true)
			draw_circle(c, r + 3, Color("#161a22"), true, -1, true)
		draw_circle(c, r, col, true, -1, true)
		draw_arc(c, r - 1, 0, TAU, 40, Color(247 / 255.0, 247 / 255.0, 242 / 255.0, 0.22), 2, true)

## remove and free every child of a container
static func clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()
