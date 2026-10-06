extends Node3D

const Rules = preload("res://scripts/rules.gd")

@export var map_name: String = "rooms"
@export var seed_value: int = 3
@export var follow_path: String = "res://scenes/deeper.tscn"
@export var cols: int = 24
@export var rows: int = 16

var rules = Rules.new()
var cells: PackedByteArray = PackedByteArray()
var start_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var walker: Vector2i = Vector2i.ZERO

func _ready() -> void:
	var eye: Camera3D = get_node("Eye")
	eye.current = true
	_show_map()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leap"):
		seed_value += 1
		_show_map()
		return
	if event.is_action_pressed("primary"):
		if walker == start_cell:
			rules.take_token()
		if follow_path != "" and rules.may_deeper(cells, cols, rows, start_cell, exit_cell, walker):
			get_tree().change_scene_to_file(follow_path)
			return
		map_name = rules.next_name(map_name)
		_show_map()
		return
	var step: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("stride_west"):
		step = Vector2i(-1, 0)
	elif event.is_action_pressed("stride_east"):
		step = Vector2i(1, 0)
	elif event.is_action_pressed("stride_north"):
		step = Vector2i(0, -1)
	elif event.is_action_pressed("stride_south"):
		step = Vector2i(0, 1)
	if step == Vector2i.ZERO:
		return
	var nxt: Vector2i = walker + step
	if not rules.may_step(cells, cols, rows, nxt):
		return
	walker = nxt
	_place_walker()

func _show_map() -> void:
	var body: Dictionary = rules.carve(map_name, seed_value, cols, rows)
	if not body.get("ok", false):
		return
	cells = body["cells"]
	start_cell = body["start"]
	exit_cell = body["exit"]
	walker = start_cell
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in rows:
		for x in cols:
			var at: Vector2i = Vector2i(x, y)
			var floor_cell: bool = rules.cell_at(cells, cols, at) == 1
			var color: Color = Color(0.22, 0.24, 0.3)
			var top: float = 1.1
			if floor_cell:
				color = Color(0.55, 0.52, 0.45)
				top = 0.15
			if at == start_cell:
				color = Color(0.3, 0.55, 0.35)
			if at == exit_cell:
				color = Color(0.75, 0.55, 0.2)
			_add_box(tool, Vector3(x, 0, y), Vector3(x + 1, top, y + 1), color)
	var mesh: ArrayMesh = tool.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	var map_mesh: MeshInstance3D = get_node("MapMesh")
	map_mesh.mesh = mesh
	var eye: Camera3D = get_node("Eye")
	eye.current = true
	eye.position = Vector3(cols * 0.5, maxf(cols, rows) * 0.85, rows * 0.55)
	eye.look_at(Vector3(cols * 0.5, 0, rows * 0.45))
	var tag: Label = get_node("Hud/Tag")
	tag.text = "%s  seed %d" % [map_name, seed_value]
	_place_walker()

func _place_walker() -> void:
	var marker: MeshInstance3D = get_node("Walker")
	marker.position = Vector3(walker.x + 0.5, 0.55, walker.y + 0.5)

func _add_box(tool: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	_quad(tool, Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3(0, 1, 0), color)
	_quad(tool, Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(0, -1, 0), color)
	_quad(tool, Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z), Vector3(-1, 0, 0), color)
	_quad(tool, Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z), Vector3(b.x, a.y, a.z), Vector3(1, 0, 0), color)
	_quad(tool, Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, a.y, a.z), Vector3(0, 0, -1), color)
	_quad(tool, Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z), Vector3(0, 0, 1), color)

func _quad(tool: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3, color: Color) -> void:
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(p0)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(p1)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(p2)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(p0)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(p2)
	tool.set_normal(normal)
	tool.set_color(color)
	tool.add_vertex(p3)
