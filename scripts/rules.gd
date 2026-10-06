extends RefCounted

const Carvers = preload("res://scripts/carvers.gd")

const MIN_SPAN := 12
const MAX_SPAN := 40

var _carvers = Carvers.new()

func names() -> PackedStringArray:
	return PackedStringArray([
		"rooms", "span", "split", "cave", "noise", "walk",
		"maze", "prims", "kruskal", "aldous", "wilson", "hunt",
		"eller", "binary", "sidewinder", "growing",
	])

func carve(name: String, seed_value: int, cols: int, rows: int) -> Dictionary:
	if names().find(name) < 0:
		return {"ok": false, "reason": "unknown_name"}
	if cols < MIN_SPAN or rows < MIN_SPAN or cols > MAX_SPAN or rows > MAX_SPAN:
		return {"ok": false, "reason": "bad_span"}
	var body: Dictionary = _carvers.build(name, seed_value, cols, rows)
	var cells: PackedByteArray = body["cells"]
	var start: Vector2i = body["start"]
	var exit_at: Vector2i = body["exit"]
	_set_floor(cells, cols, rows, start)
	_set_floor(cells, cols, rows, exit_at)
	if not path_joins(cells, cols, rows, start, exit_at):
		_open_line(cells, cols, rows, start, exit_at)
	if not path_joins(cells, cols, rows, start, exit_at):
		return {"ok": false, "reason": "unjoined"}
	body["cells"] = cells
	body["ok"] = true
	body["reason"] = ""
	return body

func path_joins(cells: PackedByteArray, cols: int, rows: int, start: Vector2i, exit_at: Vector2i) -> bool:
	if cells.size() != cols * rows:
		return false
	if not may_step(cells, cols, rows, start):
		return false
	if not may_step(cells, cols, rows, exit_at):
		return false
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cells.size())
	seen.fill(0)
	var queue: Array[Vector2i] = [start]
	seen[start.y * cols + start.x] = 1
	var head: int = 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		if at == exit_at:
			return true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = at + step
			if not may_step(cells, cols, rows, nxt):
				continue
			var id: int = nxt.y * cols + nxt.x
			if seen[id] == 1:
				continue
			seen[id] = 1
			queue.append(nxt)
	return false

func may_step(cells: PackedByteArray, cols: int, rows: int, at: Vector2i) -> bool:
	if at.x < 0 or at.y < 0 or at.x >= cols or at.y >= rows:
		return false
	if cells.size() != cols * rows:
		return false
	return cells[at.y * cols + at.x] == 1

var token_held := false

func take_token() -> void:
	token_held = true

func may_deeper(cells: PackedByteArray, cols: int, rows: int, start: Vector2i, exit_at: Vector2i, at: Vector2i) -> bool:
	if not token_held:
		return false
	if at != exit_at:
		return false
	return path_joins(cells, cols, rows, start, exit_at)

func next_name(name: String) -> String:
	var list: PackedStringArray = names()
	var index: int = list.find(name)
	if index < 0:
		return list[0]
	return list[(index + 1) % list.size()]

func cell_at(cells: PackedByteArray, cols: int, at: Vector2i) -> int:
	if at.x < 0 or at.y < 0 or at.x >= cols:
		return 0
	var id: int = at.y * cols + at.x
	if id < 0 or id >= cells.size():
		return 0
	return cells[id]

func _set_floor(cells: PackedByteArray, cols: int, rows: int, at: Vector2i) -> void:
	if at.x < 0 or at.y < 0 or at.x >= cols or at.y >= rows:
		return
	cells[at.y * cols + at.x] = 1

func _open_line(cells: PackedByteArray, cols: int, rows: int, a: Vector2i, b: Vector2i) -> void:
	var x: int = clampi(a.x, 0, cols - 1)
	var y: int = clampi(a.y, 0, rows - 1)
	cells[y * cols + x] = 1
	while x != b.x:
		x += 1 if b.x > x else -1
		x = clampi(x, 0, cols - 1)
		cells[y * cols + x] = 1
	while y != b.y:
		y += 1 if b.y > y else -1
		y = clampi(y, 0, rows - 1)
		cells[y * cols + x] = 1
