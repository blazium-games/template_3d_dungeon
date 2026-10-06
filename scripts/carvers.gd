extends RefCounted

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

func build(name: String, seed_value: int, cols: int, rows: int) -> Dictionary:
	match name:
		"rooms":
			return _rooms(seed_value, cols, rows, false)
		"span":
			return _rooms(seed_value, cols, rows, true)
		"split":
			return _split_root(seed_value, cols, rows)
		"cave":
			return _cave(seed_value, cols, rows)
		"noise":
			return _noise_map(seed_value, cols, rows)
		"walk":
			return _walk(seed_value, cols, rows)
		"maze":
			return _maze_backtrack(seed_value, cols, rows)
		"prims":
			return _maze_prims(seed_value, cols, rows)
		"kruskal":
			return _maze_kruskal(seed_value, cols, rows)
		"aldous":
			return _maze_aldous(seed_value, cols, rows)
		"wilson":
			return _maze_wilson(seed_value, cols, rows)
		"hunt":
			return _maze_hunt(seed_value, cols, rows)
		"eller":
			return _maze_eller(seed_value, cols, rows)
		"binary":
			return _maze_binary(seed_value, cols, rows)
		"sidewinder":
			return _maze_sidewinder(seed_value, cols, rows)
		"growing":
			return _maze_growing(seed_value, cols, rows)
		_:
			return _rooms(seed_value, cols, rows, false)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _blank(cols: int, rows: int) -> PackedByteArray:
	var cells: PackedByteArray = PackedByteArray()
	cells.resize(cols * rows)
	cells.fill(0)
	return cells

func _idx(cols: int, x: int, y: int) -> int:
	return y * cols + x

func _cell(cells: PackedByteArray, cols: int, x: int, y: int) -> int:
	return cells[_idx(cols, x, y)]

func _put(cells: PackedByteArray, cols: int, x: int, y: int, value: int) -> void:
	cells[_idx(cols, x, y)] = value

func _pack(cells: PackedByteArray, cols: int, rows: int, start: Vector2i, exit_at: Vector2i, name: String) -> Dictionary:
	return {
		"cells": cells,
		"cols": cols,
		"rows": rows,
		"start": start,
		"exit": exit_at,
		"name": name,
	}

func _open_line(cells: PackedByteArray, cols: int, rows: int, a: Vector2i, b: Vector2i) -> void:
	var x: int = a.x
	var y: int = a.y
	_put(cells, cols, x, y, 1)
	while x != b.x:
		x += 1 if b.x > x else -1
		if x >= 0 and x < cols and y >= 0 and y < rows:
			_put(cells, cols, x, y, 1)
	while y != b.y:
		y += 1 if b.y > y else -1
		if x >= 0 and x < cols and y >= 0 and y < rows:
			_put(cells, cols, x, y, 1)

func _fill_room(cells: PackedByteArray, cols: int, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(cells, cols, xx, yy, 1)

func _blocked(cells: PackedByteArray, cols: int, rows: int, x: int, y: int, w: int, h: int) -> bool:
	for yy in range(y - 1, y + h + 1):
		for xx in range(x - 1, x + w + 1):
			if xx < 0 or yy < 0 or xx >= cols or yy >= rows:
				return true
			if _cell(cells, cols, xx, yy) == 1:
				return true
	return false

func _rooms(seed_value: int, cols: int, rows: int, use_span: bool) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var cells: PackedByteArray = _blank(cols, rows)
	var centers: Array[Vector2i] = []
	var tries: int = 28
	while centers.size() < 5 and tries > 0:
		tries -= 1
		var rw: int = rng.randi_range(3, 5)
		var rh: int = rng.randi_range(3, 5)
		var rx: int = rng.randi_range(1, cols - rw - 2)
		var ry: int = rng.randi_range(1, rows - rh - 2)
		if _blocked(cells, cols, rows, rx, ry, rw, rh):
			continue
		_fill_room(cells, cols, rx, ry, rw, rh)
		centers.append(Vector2i(rx + int(rw / 2), ry + int(rh / 2)))
	if centers.size() < 3:
		_fill_room(cells, cols, 2, 2, 3, 3)
		centers.append(Vector2i(3, 3))
		_fill_room(cells, cols, cols - 6, rows - 6, 3, 3)
		centers.append(Vector2i(cols - 5, rows - 5))
		_fill_room(cells, cols, 2, rows - 6, 3, 3)
		centers.append(Vector2i(3, rows - 5))
	if use_span:
		_span_links(cells, cols, rows, centers, rng)
		var mark: int = centers[0].x
		if mark < 1:
			mark = 1
		if mark > cols - 2:
			mark = cols - 2
		_put(cells, cols, mark, 0, 1)
	else:
		for i in range(centers.size() - 1):
			_open_line(cells, cols, rows, centers[i], centers[i + 1])
	var exit_at: Vector2i = centers[centers.size() - 1]
	return _pack(cells, cols, rows, centers[0], exit_at, "span" if use_span else "rooms")

func _span_links(cells: PackedByteArray, cols: int, rows: int, centers: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var edges: Array = []
	for i in range(centers.size()):
		for j in range(i + 1, centers.size()):
			var weight: int = absi(centers[i].x - centers[j].x) + absi(centers[i].y - centers[j].y)
			edges.append([weight, i, j])
	edges.sort_custom(func(a, b): return a[0] < b[0])
	var parent: Array = []
	parent.resize(centers.size())
	for i in parent.size():
		parent[i] = i
	var used: int = 0
	for edge in edges:
		var ra: int = _find(parent, edge[1])
		var rb: int = _find(parent, edge[2])
		if ra == rb:
			continue
		parent[ra] = rb
		_open_line(cells, cols, rows, centers[edge[1]], centers[edge[2]])
		used += 1
		if used >= centers.size() - 1:
			break
	if centers.size() >= 3:
		var extra: int = rng.randi_range(0, centers.size() - 1)
		var other: int = (extra + centers.size() / 2) % centers.size()
		_open_line(cells, cols, rows, centers[extra], centers[other])

func _find(parent: Array, index: int) -> int:
	var root: int = index
	while parent[root] != root:
		root = parent[root]
	var at: int = index
	while parent[at] != root:
		var nxt: int = parent[at]
		parent[at] = root
		at = nxt
	return root

func _split_root(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var cells: PackedByteArray = _blank(cols, rows)
	var start: Vector2i = _split(cells, cols, rows, rng, 1, 1, cols - 2, rows - 2)
	var exit_at: Vector2i = _farthest_floor(cells, cols, rows, start)
	return _pack(cells, cols, rows, start, exit_at, "split")

func _split(cells: PackedByteArray, cols: int, rows: int, rng: RandomNumberGenerator, x: int, y: int, w: int, h: int) -> Vector2i:
	var min_leaf: int = 7
	if w < min_leaf * 2 and h < min_leaf * 2:
		return _plant_room(cells, cols, rng, x, y, w, h)
	var horizontal: bool = false
	if w < min_leaf * 2:
		horizontal = true
	elif h < min_leaf * 2:
		horizontal = false
	else:
		horizontal = rng.randf() < 0.5
	if horizontal:
		var cut: int = rng.randi_range(min_leaf, h - min_leaf)
		var top: Vector2i = _split(cells, cols, rows, rng, x, y, w, cut)
		var bottom: Vector2i = _split(cells, cols, rows, rng, x, y + cut, w, h - cut)
		_open_line(cells, cols, rows, top, bottom)
		return top
	var cut_x: int = rng.randi_range(min_leaf, w - min_leaf)
	var left: Vector2i = _split(cells, cols, rows, rng, x, y, cut_x, h)
	var right: Vector2i = _split(cells, cols, rows, rng, x + cut_x, y, w - cut_x, h)
	_open_line(cells, cols, rows, left, right)
	return left

func _plant_room(cells: PackedByteArray, cols: int, rng: RandomNumberGenerator, x: int, y: int, w: int, h: int) -> Vector2i:
	var rw: int = mini(w - 2, rng.randi_range(2, maxi(2, w - 2)))
	var rh: int = mini(h - 2, rng.randi_range(2, maxi(2, h - 2)))
	if rw < 2:
		rw = mini(2, w)
	if rh < 2:
		rh = mini(2, h)
	var rx: int = x + rng.randi_range(0, maxi(0, w - rw))
	var ry: int = y + rng.randi_range(0, maxi(0, h - rh))
	rx = clampi(rx, 1, cols - rw - 1)
	ry = clampi(ry, 1, int(cells.size() / cols) - rh - 1)
	_fill_room(cells, cols, rx, ry, rw, rh)
	return Vector2i(rx + int(rw / 2), ry + int(rh / 2))

func _cave(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var cells: PackedByteArray = _blank(cols, rows)
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			if rng.randf() < 0.46:
				_put(cells, cols, x, y, 1)
	for _pass in 4:
		var nxt: PackedByteArray = cells.duplicate()
		for y in range(1, rows - 1):
			for x in range(1, cols - 1):
				var around: int = _count8(cells, cols, rows, x, y)
				nxt[_idx(cols, x, y)] = 1 if around >= 5 else 0
		cells = nxt
	_keep_largest(cells, cols, rows)
	return _ends(cells, cols, rows, "cave")

func _noise_map(seed_value: int, cols: int, rows: int) -> Dictionary:
	var cells: PackedByteArray = _blank(cols, rows)
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			if _value_noise(x, y, seed_value) > 0.48:
				_put(cells, cols, x, y, 1)
	_keep_largest(cells, cols, rows)
	return _ends(cells, cols, rows, "noise")

func _value_noise(x: int, y: int, seed_value: int) -> float:
	var x0: int = int(x / 4)
	var y0: int = int(y / 4)
	var fx: float = float(x % 4) / 4.0
	var fy: float = float(y % 4) / 4.0
	var v00: float = _hash(x0, y0, seed_value)
	var v10: float = _hash(x0 + 1, y0, seed_value)
	var v01: float = _hash(x0, y0 + 1, seed_value)
	var v11: float = _hash(x0 + 1, y0 + 1, seed_value)
	var ix0: float = v00 + (v10 - v00) * fx
	var ix1: float = v01 + (v11 - v01) * fx
	return ix0 + (ix1 - ix0) * fy

func _hash(x: int, y: int, seed_value: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + seed_value * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0x7fffffff) / float(0x7fffffff)

func _walk(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var cells: PackedByteArray = _blank(cols, rows)
	var x: int = int(cols / 2)
	var y: int = int(rows / 2)
	var first: Vector2i = Vector2i(x, y)
	var last: Vector2i = first
	var unique: int = 0
	var need: int = int(cols * rows * 0.28)
	var guard: int = cols * rows * 6
	while unique < need and guard > 0:
		guard -= 1
		if _cell(cells, cols, x, y) == 0:
			unique += 1
			last = Vector2i(x, y)
		_put(cells, cols, x, y, 1)
		var step: Vector2i = DIRS[rng.randi_range(0, 3)]
		x = clampi(x + step.x, 1, cols - 2)
		y = clampi(y + step.y, 1, rows - 2)
	return _pack(cells, cols, rows, first, last, "walk")

func _count8(cells: PackedByteArray, cols: int, rows: int, x: int, y: int) -> int:
	var total: int = 0
	for yy in range(y - 1, y + 2):
		for xx in range(x - 1, x + 2):
			if xx == x and yy == y:
				continue
			if xx < 0 or yy < 0 or xx >= cols or yy >= rows:
				continue
			if _cell(cells, cols, xx, yy) == 1:
				total += 1
	return total

func _keep_largest(cells: PackedByteArray, cols: int, rows: int) -> void:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cells.size())
	seen.fill(0)
	var best: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			if _cell(cells, cols, x, y) != 1 or seen[_idx(cols, x, y)] == 1:
				continue
			var region: Array[Vector2i] = _collect(cells, cols, rows, seen, Vector2i(x, y))
			if region.size() > best.size():
				best = region
	cells.fill(0)
	for spot in best:
		_put(cells, cols, spot.x, spot.y, 1)
	if best.is_empty():
		_fill_room(cells, cols, 2, 2, 3, 3)
		_fill_room(cells, cols, cols - 6, rows - 6, 3, 3)
		_open_line(cells, cols, rows, Vector2i(3, 3), Vector2i(cols - 5, rows - 5))

func _collect(cells: PackedByteArray, cols: int, rows: int, seen: PackedByteArray, start: Vector2i) -> Array[Vector2i]:
	var region: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	seen[_idx(cols, start.x, start.y)] = 1
	var head: int = 0
	while head < queue.size():
		var at: Vector2i = queue[head]
		head += 1
		region.append(at)
		for step in DIRS:
			var nxt: Vector2i = at + step
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= cols or nxt.y >= rows:
				continue
			if _cell(cells, cols, nxt.x, nxt.y) != 1:
				continue
			var id: int = _idx(cols, nxt.x, nxt.y)
			if seen[id] == 1:
				continue
			seen[id] = 1
			queue.append(nxt)
	return region

func _ends(cells: PackedByteArray, cols: int, rows: int, name: String) -> Dictionary:
	var start: Vector2i = Vector2i(1, 1)
	var exit_at: Vector2i = Vector2i(cols - 2, rows - 2)
	var found_start: bool = false
	for y in rows:
		for x in cols:
			if _cell(cells, cols, x, y) != 1:
				continue
			if not found_start:
				start = Vector2i(x, y)
				found_start = true
			exit_at = Vector2i(x, y)
	if start == exit_at:
		_fill_room(cells, cols, 2, 2, 3, 3)
		_fill_room(cells, cols, cols - 6, rows - 6, 3, 3)
		_open_line(cells, cols, rows, Vector2i(3, 3), Vector2i(cols - 5, rows - 5))
		start = Vector2i(3, 3)
		exit_at = Vector2i(cols - 5, rows - 5)
	return _pack(cells, cols, rows, start, exit_at, name)

func _farthest_floor(cells: PackedByteArray, cols: int, rows: int, start: Vector2i) -> Vector2i:
	var best: Vector2i = start
	var best_d: int = -1
	for y in rows:
		for x in cols:
			if _cell(cells, cols, x, y) != 1:
				continue
			var dist: int = absi(x - start.x) + absi(y - start.y)
			if dist > best_d:
				best_d = dist
				best = Vector2i(x, y)
	return best

func _maze_wh(cols: int, rows: int) -> Vector2i:
	return Vector2i(int((cols - 1) / 2), int((rows - 1) / 2))

func _passage(cells: PackedByteArray, cols: int, cx: int, cy: int) -> void:
	_put(cells, cols, 1 + cx * 2, 1 + cy * 2, 1)

func _link(cells: PackedByteArray, cols: int, a: Vector2i, b: Vector2i) -> void:
	_passage(cells, cols, a.x, a.y)
	_passage(cells, cols, b.x, b.y)
	_put(cells, cols, 1 + a.x * 2 + (b.x - a.x), 1 + a.y * 2 + (b.y - a.y), 1)

func _maze_blank(cols: int, rows: int) -> Dictionary:
	var span: Vector2i = _maze_wh(cols, rows)
	var cells: PackedByteArray = _blank(cols, rows)
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(span.x * span.y)
	visited.fill(0)
	return {"cells": cells, "visited": visited, "mw": span.x, "mh": span.y}

func _maze_pack(built: Dictionary, cols: int, rows: int, name: String) -> Dictionary:
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	var start: Vector2i = Vector2i(1, 1)
	var exit_at: Vector2i = Vector2i(1 + (mw - 1) * 2, 1 + (mh - 1) * 2)
	return _pack(built["cells"], cols, rows, start, exit_at, name)

func _cell_in(mw: int, mh: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < mw and cell.y < mh

func _unvisited(built: Dictionary, cell: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var visited: PackedByteArray = built["visited"]
	var mw: int = built["mw"]
	for step in DIRS:
		var nxt: Vector2i = cell + step
		if not _cell_in(mw, built["mh"], nxt):
			continue
		if visited[nxt.y * mw + nxt.x] == 0:
			found.append(nxt)
	return found

func _maze_backtrack(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	_mark(built, cols, Vector2i(0, 0))
	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array[Vector2i] = _unvisited(built, cur)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		_link(built["cells"], cols, cur, pick)
		_mark(built, cols, pick)
		stack.append(pick)
	return _maze_pack(built, cols, rows, "maze")

func _mark(built: Dictionary, cols: int, cell: Vector2i) -> void:
	var visited: PackedByteArray = built["visited"]
	var mw: int = built["mw"]
	visited[cell.y * mw + cell.x] = 1
	_passage(built["cells"], cols, cell.x, cell.y)

func _maze_prims(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	_mark(built, cols, Vector2i(0, 0))
	var frontier: Array = []
	_push_frontier(built, frontier, Vector2i(0, 0))
	while frontier.size() > 0:
		var pick: int = rng.randi_range(0, frontier.size() - 1)
		var edge: Array = frontier[pick]
		frontier.remove_at(pick)
		var dest: Vector2i = edge[1]
		var visited: PackedByteArray = built["visited"]
		var mw: int = built["mw"]
		if visited[dest.y * mw + dest.x] == 1:
			continue
		_link(built["cells"], cols, edge[0], dest)
		_mark(built, cols, dest)
		_push_frontier(built, frontier, dest)
	return _maze_pack(built, cols, rows, "prims")

func _push_frontier(built: Dictionary, frontier: Array, cell: Vector2i) -> void:
	var visited: PackedByteArray = built["visited"]
	var mw: int = built["mw"]
	for step in DIRS:
		var nxt: Vector2i = cell + step
		if not _cell_in(mw, built["mh"], nxt):
			continue
		if visited[nxt.y * mw + nxt.x] == 1:
			continue
		frontier.append([cell, nxt])

func _maze_kruskal(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	var edges: Array = []
	for y in mh:
		for x in mw:
			_passage(built["cells"], cols, x, y)
			if x + 1 < mw:
				edges.append([Vector2i(x, y), Vector2i(x + 1, y)])
			if y + 1 < mh:
				edges.append([Vector2i(x, y), Vector2i(x, y + 1)])
	for i in range(edges.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = edges[i]
		edges[i] = edges[j]
		edges[j] = tmp
	var parent: Array = []
	parent.resize(mw * mh)
	for i in parent.size():
		parent[i] = i
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		var ra: int = _find(parent, a.y * mw + a.x)
		var rb: int = _find(parent, b.y * mw + b.x)
		if ra == rb:
			continue
		parent[ra] = rb
		_link(built["cells"], cols, a, b)
	return _maze_pack(built, cols, rows, "kruskal")

func _maze_aldous(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	var left: int = mw * mh - 1
	var cur: Vector2i = Vector2i(0, 0)
	_mark(built, cols, cur)
	var guard: int = mw * mh * mw * mh * 4
	while left > 0 and guard > 0:
		guard -= 1
		var options: Array[Vector2i] = []
		for step in DIRS:
			var nxt: Vector2i = cur + step
			if _cell_in(mw, mh, nxt):
				options.append(nxt)
		var prev: Vector2i = cur
		cur = options[rng.randi_range(0, options.size() - 1)]
		var visited: PackedByteArray = built["visited"]
		if visited[cur.y * mw + cur.x] == 0:
			_link(built["cells"], cols, prev, cur)
			_mark(built, cols, cur)
			left -= 1
	_finish_unvisited(built, cols)
	return _maze_pack(built, cols, rows, "aldous")

func _aldous_prev(built: Dictionary, cur: Vector2i) -> Vector2i:
	var visited: PackedByteArray = built["visited"]
	var mw: int = built["mw"]
	for step in DIRS:
		var nxt: Vector2i = cur + step
		if _cell_in(mw, built["mh"], nxt) and visited[nxt.y * mw + nxt.x] == 1:
			return nxt
	return Vector2i(0, 0)

func _finish_unvisited(built: Dictionary, cols: int) -> void:
	var visited: PackedByteArray = built["visited"]
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	var pending: bool = true
	while pending:
		pending = false
		for y in mh:
			for x in mw:
				if visited[y * mw + x] == 1:
					continue
				var here: Vector2i = Vector2i(x, y)
				for step in DIRS:
					var nxt: Vector2i = here + step
					if not _cell_in(mw, mh, nxt):
						continue
					if visited[nxt.y * mw + nxt.x] != 1:
						continue
					_link(built["cells"], cols, here, nxt)
					_mark(built, cols, here)
					pending = true
					break

func _maze_wilson(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	_mark(built, cols, Vector2i(0, 0))
	var left: int = mw * mh - 1
	while left > 0:
		var pick: int = rng.randi_range(0, left - 1)
		var seen: int = 0
		var origin: Vector2i = Vector2i(0, 0)
		var visited: PackedByteArray = built["visited"]
		for y in mh:
			for x in mw:
				if visited[y * mw + x] == 1:
					continue
				if seen == pick:
					origin = Vector2i(x, y)
				seen += 1
		var path: Array[Vector2i] = []
		var index_of: Dictionary = {}
		var cur: Vector2i = origin
		var guard: int = mw * mh * 40
		var hit: Vector2i = origin
		var landed: bool = false
		while guard > 0:
			guard -= 1
			if visited[cur.y * mw + cur.x] == 1 and path.size() > 0:
				hit = cur
				landed = true
				break
			if index_of.has(_key(cur)):
				var at: int = index_of[_key(cur)]
				while path.size() > at + 1:
					var dropped: Vector2i = path.pop_back()
					index_of.erase(_key(dropped))
			else:
				index_of[_key(cur)] = path.size()
				path.append(cur)
			var options: Array[Vector2i] = []
			for step in DIRS:
				var nxt: Vector2i = cur + step
				if _cell_in(mw, mh, nxt):
					options.append(nxt)
			cur = options[rng.randi_range(0, options.size() - 1)]
		if path.is_empty():
			_finish_unvisited(built, cols)
			break
		if not landed:
			hit = _aldous_prev(built, path[path.size() - 1])
		_link(built["cells"], cols, path[path.size() - 1], hit)
		for spot in path:
			if visited[spot.y * mw + spot.x] == 0:
				_mark(built, cols, spot)
				left -= 1
	return _maze_pack(built, cols, rows, "wilson")

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _maze_hunt(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var cur: Vector2i = Vector2i(0, 0)
	_mark(built, cols, cur)
	var left: int = built["mw"] * built["mh"] - 1
	while left > 0:
		var options: Array[Vector2i] = _unvisited(built, cur)
		if options.size() > 0:
			var nxt: Vector2i = options[rng.randi_range(0, options.size() - 1)]
			_link(built["cells"], cols, cur, nxt)
			_mark(built, cols, nxt)
			cur = nxt
			left -= 1
			continue
		var found: bool = false
		var visited: PackedByteArray = built["visited"]
		var mw: int = built["mw"]
		for y in built["mh"]:
			for x in mw:
				if visited[y * mw + x] == 1:
					continue
				var here: Vector2i = Vector2i(x, y)
				for step in DIRS:
					var nb: Vector2i = here + step
					if not _cell_in(mw, built["mh"], nb):
						continue
					if visited[nb.y * mw + nb.x] != 1:
						continue
					_link(built["cells"], cols, here, nb)
					_mark(built, cols, here)
					cur = here
					left -= 1
					found = true
					break
				if found:
					break
			if found:
				break
		if not found:
			break
	return _maze_pack(built, cols, rows, "hunt")

func _maze_eller(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	var set_of: Array = []
	set_of.resize(mw)
	var next_set: int = 1
	for x in mw:
		set_of[x] = next_set
		next_set += 1
		_passage(built["cells"], cols, x, 0)
	for y in mh:
		var last_row: bool = y == mh - 1
		for x in range(mw - 1):
			if set_of[x] == set_of[x + 1]:
				continue
			if not last_row and rng.randf() >= 0.5:
				continue
			var old: int = set_of[x + 1]
			var keep: int = set_of[x]
			for i in mw:
				if set_of[i] == old:
					set_of[i] = keep
			_link(built["cells"], cols, Vector2i(x, y), Vector2i(x + 1, y))
		if last_row:
			break
		var members: Dictionary = {}
		for x in mw:
			var key: int = set_of[x]
			if not members.has(key):
				members[key] = []
			members[key].append(x)
		var open_down: Array = []
		open_down.resize(mw)
		open_down.fill(false)
		for key in members.keys():
			var xs: Array = members[key]
			var any: bool = false
			for x in xs:
				if rng.randf() < 0.5:
					open_down[x] = true
					any = true
			if not any:
				open_down[xs[rng.randi_range(0, xs.size() - 1)]] = true
		var nxt: Array = []
		nxt.resize(mw)
		for x in mw:
			if open_down[x]:
				_link(built["cells"], cols, Vector2i(x, y), Vector2i(x, y + 1))
				nxt[x] = set_of[x]
			else:
				nxt[x] = next_set
				next_set += 1
				_passage(built["cells"], cols, x, y + 1)
		set_of = nxt
	return _maze_pack(built, cols, rows, "eller")

func _maze_binary(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	for y in mh:
		for x in mw:
			_passage(built["cells"], cols, x, y)
			var choices: Array[Vector2i] = []
			if x + 1 < mw:
				choices.append(Vector2i(1, 0))
			if y + 1 < mh:
				choices.append(Vector2i(0, 1))
			if choices.is_empty():
				continue
			var step: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
			_link(built["cells"], cols, Vector2i(x, y), Vector2i(x, y) + step)
	return _maze_pack(built, cols, rows, "binary")

func _maze_sidewinder(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var mw: int = built["mw"]
	var mh: int = built["mh"]
	for y in mh:
		for x in mw:
			_passage(built["cells"], cols, x, y)
		if y == 0:
			for x in range(mw - 1):
				_link(built["cells"], cols, Vector2i(x, 0), Vector2i(x + 1, 0))
			continue
		var run_start: int = 0
		for x in mw:
			var carve_east: bool = x + 1 < mw and rng.randf() < 0.5
			if carve_east:
				_link(built["cells"], cols, Vector2i(x, y), Vector2i(x + 1, y))
				continue
			var pick: int = rng.randi_range(run_start, x)
			_link(built["cells"], cols, Vector2i(pick, y), Vector2i(pick, y - 1))
			run_start = x + 1
	return _maze_pack(built, cols, rows, "sidewinder")

func _maze_growing(seed_value: int, cols: int, rows: int) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var built: Dictionary = _maze_blank(cols, rows)
	var active: Array[Vector2i] = [Vector2i(0, 0)]
	_mark(built, cols, Vector2i(0, 0))
	while active.size() > 0:
		var idx: int = active.size() - 1
		if rng.randf() < 0.5:
			idx = rng.randi_range(0, active.size() - 1)
		var cur: Vector2i = active[idx]
		var options: Array[Vector2i] = _unvisited(built, cur)
		if options.is_empty():
			active.remove_at(idx)
			continue
		var nxt: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		_link(built["cells"], cols, cur, nxt)
		_mark(built, cols, nxt)
		active.append(nxt)
	return _maze_pack(built, cols, rows, "growing")
