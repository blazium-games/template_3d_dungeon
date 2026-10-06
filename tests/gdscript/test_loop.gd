extends AutoworkTest

const Rules = preload("res://scripts/rules.gd")

func test_rejects() -> void:
	var rules = Rules.new()
	var bad: Dictionary = rules.carve("nope", 1, 16, 16)
	assert_false(bad["ok"], "unknown name")
	var narrow: Dictionary = rules.carve("rooms", 1, 8, 16)
	assert_false(narrow["ok"], "too narrow")
	var tall: Dictionary = rules.carve("rooms", 1, 16, 50)
	assert_false(tall["ok"], "too tall")

func test_every_name() -> void:
	var rules = Rules.new()
	for name in rules.names():
		var body: Dictionary = rules.carve(str(name), 4, 16, 16)
		assert_true(body["ok"], str(name))
		var cells: PackedByteArray = body["cells"]
		var start: Vector2i = body["start"]
		var exit_at: Vector2i = body["exit"]
		assert_eq(rules.cell_at(cells, 16, start), 1, str(name) + " start")
		assert_eq(rules.cell_at(cells, 16, exit_at), 1, str(name) + " exit")
		assert_true(rules.path_joins(cells, 16, 16, start, exit_at), str(name) + " joins")
		var again: Dictionary = rules.carve(str(name), 4, 16, 16)
		var again_cells: PackedByteArray = again["cells"]
		assert_eq(again_cells, cells, str(name) + " stable")

func test_cycle_and_families() -> void:
	var rules = Rules.new()
	assert_eq(rules.next_name("rooms"), "span", "first step")
	assert_eq(rules.next_name("growing"), "rooms", "wrap")
	var listed: PackedStringArray = rules.names()
	var name: String = "rooms"
	for _i in listed.size():
		name = rules.next_name(name)
	assert_eq(name, "rooms", "full cycle")
	var maze: Dictionary = rules.carve("maze", 4, 16, 16)
	var prims: Dictionary = rules.carve("prims", 4, 16, 16)
	var maze_cells: PackedByteArray = maze["cells"]
	var prims_cells: PackedByteArray = prims["cells"]
	assert_false(maze_cells == prims_cells, "prims differs")
	var rooms: Dictionary = rules.carve("rooms", 4, 16, 16)
	var span: Dictionary = rules.carve("span", 4, 16, 16)
	var rooms_cells: PackedByteArray = rooms["cells"]
	var span_cells: PackedByteArray = span["cells"]
	assert_false(rooms_cells == span_cells, "span differs")

func test_wall_step() -> void:
	var rules = Rules.new()
	var body: Dictionary = rules.carve("rooms", 4, 16, 16)
	var cells: PackedByteArray = body["cells"]
	var start: Vector2i = body["start"]
	var exit_at: Vector2i = body["exit"]
	assert_true(rules.may_step(cells, 16, 16, start), "floor step")
	assert_false(rules.may_step(cells, 16, 16, Vector2i(0, 0)), "border wall")
	assert_false(rules.may_deeper(cells, 16, 16, start, exit_at, start), "not on exit")
	assert_false(rules.may_deeper(cells, 16, 16, start, exit_at, exit_at), "exit needs a token")
	rules.take_token()
	assert_true(rules.may_deeper(cells, 16, 16, start, exit_at, exit_at), "token and exit")
	assert_true(load("res://scenes/deeper.tscn") != null, "deeper loads")
