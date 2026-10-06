extends Node

func register() -> void:
	var runtime := _runtime()
	if runtime == null:
		push_error("JustAMCP: mcp/register.gd needs the JustAMCPRuntime singleton")
		return
	runtime.register_tool(
		"read_dungeon3d",
		"Read the live rule state for Dungeon 3D.",
		{"type": "object", "properties": {}},
		Callable(self, "_read_state")
	)
	runtime.register_tool(
		"reset_dungeon3d",
		"Reset the live rule state for Dungeon 3D.",
		{"type": "object", "properties": {}},
		Callable(self, "_reset_state")
	)
	runtime.register_tool(
		"set_halt",
		"Pause or resume this starter.",
		{"type": "object", "properties": {"halted": {"type": "boolean", "description": "If omitted, toggle"}}},
		Callable(self, "_set_halt")
	)
	runtime.register_tool(
		"exercise_dungeon3d",
		"Call one rule function on the live scene. Pass action and an args array. This is not eval.",
		{
			"type": "object",
			"properties": {
				"action": {"type": "string", "description": "Rule function name"},
				"args": {"type": "array", "description": "Arguments for that function"},
			},
			"required": ["action"],
		},
		Callable(self, "_exercise")
	)
	if runtime.has_method("register_prompt"):
		runtime.register_prompt(
			"starter_brief",
			"How to extend Dungeon.",
			Callable(self, "_brief")
		)

func _runtime() -> Object:
	if Engine.has_singleton("JustAMCPRuntime"):
		return Engine.get_singleton("JustAMCPRuntime")
	return null

func _presenter() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return loop.root.get_node_or_null("Opener")

func _live_rules() -> Object:
	var node := _presenter()
	if node == null or not ("rules" in node):
		return null
	return node.rules

func _read_state(_args: Dictionary) -> Dictionary:
	var rules := _live_rules()
	if rules == null:
		return {"ok": false, "reason": "scene_down"}
	var node := _presenter()
	if node == null:
		return {"ok": false, "reason": "scene_down"}
	var joined: bool = node.rules.path_joins(node.cells, node.cols, node.rows, node.start_cell, node.exit_cell)
	return {"name": node.map_name, "seed": node.seed_value, "joined": joined}

func _reset_state(_args: Dictionary) -> Dictionary:
	var node := _presenter()
	if node == null or not ("rules" in node):
		return {"ok": false, "reason": "scene_down"}
	node.rules = preload("res://scripts/rules.gd").new()
	return {"reset": true}

func _set_halt(args: Dictionary) -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return {"ok": false, "reason": "scene_down"}
	var guard: Node = loop.root.get_node_or_null("BootGuard")
	if guard == null:
		return {"ok": false, "reason": "guard_down"}
	if args.has("halted"):
		guard.halted = bool(args["halted"])
		guard.get_tree().paused = guard.halted
	else:
		guard.toggle_halt()
	return {"halted": guard.halted}

func _exercise(args: Dictionary) -> Dictionary:
	var rules := _live_rules()
	if rules == null:
		return {"ok": false, "reason": "scene_down"}
	var action := str(args.get("action", ""))
	if action == "" or action.begins_with("_") or not rules.has_method(action):
		return {"ok": false, "reason": "unknown_action"}
	var call_args: Array = args.get("args", [])
	if typeof(call_args) != TYPE_ARRAY:
		return {"ok": false, "reason": "args_must_be_array"}
	return {"ok": true, "result": rules.callv(action, call_args)}

func _brief(_args: Dictionary) -> String:
	return "Dungeon 3D. Primary cycles the carver. Leap changes the seed. A step into a wall is rejected. The exit opens the next scene only when the path joins. Edit scripts/rules.gd and scripts/carvers.gd. Editor MCP is http://127.0.0.1:6506/mcp. Game MCP is http://127.0.0.1:6507/mcp. Tools: read_dungeon3d, reset_dungeon3d, set_halt, exercise_dungeon3d."
