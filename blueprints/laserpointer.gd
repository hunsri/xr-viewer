extends Node3D

@export var max_distance: float = 15.0
@export var beam_radius: float = 0.0035
@export var dot_radius: float = 0.012
@export var show_dot: bool = true
@export_flags_3d_physics var ray_collision_mask: int = 0x7FFFFFFF

@export var select_button_name: String = "ax_button"     # Toggle select

@export var scale_button_name: String = "by_button"     
@export var scale_axis_name: String = "primary"     
@export var scale_axis_y_fallback: String = ""       
@export var scale_axis_invert_y: bool = false
@export var scale_axis_deadzone: float = 0.10
@export var scale_min: float = 0.20
@export var scale_max: float = 4.00
@export var scale_speed: float = 1.20                 
@export var scale_snap_step: float = 0.0        

# ---------- Ziel-Filter ----------
@export var accept_pickable: bool = true               
@export var selectable_group: StringName = ""            

# ---------- Outline ----------
@export var outline_color: Color = Color(1.0, 0.7, 0.0, 1.0)
@export var outline_size: float = 0.008
@export var outline_max_nodes: int = 64

# ---------- Referenzen ----------
@onready var ray: RayCast3D = $Ray
@onready var beam: Node3D = $Beam
@onready var dot: Node3D = $Dot
@onready var controller: XRController3D = get_parent() as XRController3D

# ---------- State ----------
var _hovered: Node3D = null
var _selected: Node3D = null
var _selected_scale_node: Node3D = null

# Outline intern
var _outline_nodes: Array[MeshInstance3D] = []
var _outline_shader: Shader = null
var _outline_mat: ShaderMaterial = null

# Scale intern
var _scale_mode: bool = false
var _scale_base: Vector3 = Vector3.ONE
var _scale_factor: float = 1.0
var _ui_root: Node3D = null
var _ui_back: CSGBox3D = null
var _ui_fill: CSGBox3D = null


func _ready() -> void:
	# Ray
	ray.target_position = Vector3(0, 0, -max_distance)
	ray.enabled = true
	ray.collision_mask = ray_collision_mask

	# Beam (CSGCylinder angenommen)
	if beam is CSGCylinder3D:
		var b: CSGCylinder3D = beam as CSGCylinder3D
		b.radius = beam_radius
		b.height = 1.0
	beam.rotation_degrees = Vector3(-90, 0, 0)

	# Dot
	if dot is CSGSphere3D:
		var s: CSGSphere3D = dot as CSGSphere3D
		s.radius = dot_radius
	if not show_dot and dot is GeometryInstance3D:
		(dot as GeometryInstance3D).visible = false

	_update_beam(max_distance, false, Vector3(0, 0, -max_distance))

	if controller:
		controller.button_pressed.connect(_on_controller_button_pressed)
		controller.button_released.connect(_on_controller_button_released)
	else:
		push_warning("LaserPointer: Kein XRController3D gefunden – Laser unter den Controller hängen.")

	set_physics_process(true)


func _physics_process(dt: float) -> void:
	
	ray.force_raycast_update()
	var new_hover: Node3D = null

	if ray.is_colliding():
		var hit: Object = ray.get_collider()
		new_hover = _find_target(hit)
		var hit_local: Vector3 = to_local(ray.get_collision_point())
		_update_beam(hit_local.length(), true, hit_local)
	else:
		_update_beam(max_distance, false, Vector3(0, 0, -max_distance))

	_hovered = new_hover


	if _scale_mode and is_instance_valid(_selected_scale_node):
		_update_scale_from_stick(dt)

func _on_controller_button_pressed(btn: String) -> void:
	if btn == select_button_name:
		_on_press_select()


func _on_controller_button_released(_btn: String) -> void:
	pass


func _on_press_select() -> void:
	var target: Node3D = _hovered
	if target == null:
		ray.force_raycast_update()
		if ray.is_colliding():
			target = _find_target(ray.get_collider())

	if target == null:
		return

	if _selected == target:
		_set_selected(null)
	else:
		_set_selected(target)

func _find_target(obj: Object) -> Node3D:
	if not (obj is Node):
		return null
	var n: Node = obj as Node
	var depth: int = 0
	while n and depth < 16:
		if accept_pickable and (
			(n is XRToolsPickable) or
			(n.has_method("is_xr_class") and n.is_xr_class("XRToolsPickable")) or
			n.has_method("pick_up")
		):
			return n as Node3D

		if String(selectable_group) != "" and n.is_in_group(selectable_group):
			return n as Node3D

		n = n.get_parent()
		depth += 1
	return null


func _set_selected(n: Node3D) -> void:
	if _scale_mode:
		_toggle_scale_mode(true)

	_clear_outline()
	_selected = n
	_selected_scale_node = null

	if is_instance_valid(_selected):
		_selected_scale_node = _get_scale_node(_selected)
		_apply_outline(_selected)

		# 👉 Hier direkt Skalierungsmodus aktivieren
		_enter_scale_mode()

func _get_scale_node(n: Node3D) -> Node3D:
	var sr: Node = n.get_node_or_null("ScaleRoot")
	if sr is Node3D:
		return sr as Node3D

	var meshes: Array[MeshInstance3D] = _gather_meshes_limited(n, 1)
	if meshes.size() > 0:
		var parent: Node = meshes[0].get_parent()
		if parent is Node3D:
			return parent as Node3D

	return n


func _ensure_outline_material() -> void:
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = """
			shader_type spatial;
			render_mode unshaded, cull_front;

			uniform vec4 outline_color : source_color = vec4(1.0, 0.7, 0.0, 1.0);
			uniform float outline_size = 0.008;

			void vertex() { VERTEX += NORMAL * outline_size; }
			void fragment() { ALBEDO = outline_color.rgb; ALPHA = outline_color.a; }
		"""
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = _outline_shader
	_update_outline_material_params()


func _update_outline_material_params() -> void:
	if _outline_mat:
		_outline_mat.set_shader_parameter("outline_color", Vector4(outline_color.r, outline_color.g, outline_color.b, outline_color.a))
		_outline_mat.set_shader_parameter("outline_size", outline_size)

func _apply_outline(root: Node3D) -> void:
	_ensure_outline_material()
	var meshes: Array[MeshInstance3D] = _gather_meshes_limited(root, outline_max_nodes)
	if meshes.is_empty():
		return

	for m in meshes:
		var outline_mesh: MeshInstance3D = MeshInstance3D.new()
		outline_mesh.mesh = m.mesh
		outline_mesh.transform = m.transform
		outline_mesh.material_override = _outline_mat
		outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.get_parent().add_child(outline_mesh)
		_outline_nodes.append(outline_mesh)


func _clear_outline() -> void:
	for n in _outline_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_outline_nodes.clear()

func _toggle_scale_mode(force_off: bool=false) -> void:
	if not is_instance_valid(_selected_scale_node):
		return
	if _scale_mode or force_off:
		_exit_scale_mode()
	else:
		_enter_scale_mode()


func _enter_scale_mode() -> void:
	_scale_mode = true
	_scale_base = _selected_scale_node.scale
	_scale_factor = 1.0
	_create_scale_ui()


func _exit_scale_mode() -> void:
	_scale_mode = false
	_destroy_scale_ui()


func _update_scale_from_stick(dt: float) -> void:
	var y: float = 0.0

	if controller.has_method("get_vector2"):
		var v: Vector2 = controller.get_vector2(scale_axis_name)
		y = v.y

	if absf(y) < 0.001 and scale_axis_y_fallback != "" and controller.has_method("get_float"):
		y = controller.get_float(scale_axis_y_fallback)

	if scale_axis_invert_y:
		y = -y

	# Deadzone
	if absf(y) < scale_axis_deadzone:
		return

	_scale_factor += y * scale_speed * dt
	_scale_factor = clamp(_scale_factor, scale_min, scale_max)

	if scale_snap_step > 0.0:
		var steps: float = round(_scale_factor / scale_snap_step)
		_scale_factor = clamp(steps * scale_snap_step, scale_min, scale_max)

	_selected_scale_node.scale = _scale_base * _scale_factor
	_update_scale_ui()

func _create_scale_ui() -> void:
	_destroy_scale_ui()

	_ui_root = Node3D.new()
	add_child(_ui_root)
	_ui_root.position = Vector3(0.0, 0.06, -0.12)

	_ui_back = CSGBox3D.new()
	_ui_back.size = Vector3(0.14, 0.012, 0.001)
	_ui_back.use_collision = false
	var back_mat: StandardMaterial3D = StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.95)
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ui_back.material = back_mat
	_ui_root.add_child(_ui_back)

	_ui_fill = CSGBox3D.new()
	_ui_fill.size = Vector3(0.001, 0.010, 0.001)
	_ui_fill.position = Vector3(-0.07, 0.0, 0.0)
	_ui_fill.use_collision = false
	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.95, 0.75, 0.15, 1.0)
	fill_mat.emission_enabled = true
	fill_mat.emission = fill_mat.albedo_color
	fill_mat.emission_energy_multiplier = 1.2
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ui_fill.material = fill_mat
	_ui_root.add_child(_ui_fill)

	_update_scale_ui()


func _update_scale_ui() -> void:
	if _ui_fill == null:
		return
	var t: float = 0.0
	if scale_max > scale_min:
		t = (_scale_factor - scale_min) / (scale_max - scale_min)
	t = clamp(t, 0.0, 1.0)
	var w: float = 0.14 * t
	_ui_fill.size = Vector3(max(w, 0.001), 0.010, 0.001)
	_ui_fill.position.x = -0.07 + (w * 0.5)


func _destroy_scale_ui() -> void:
	if _ui_root and is_instance_valid(_ui_root):
		_ui_root.queue_free()
	_ui_root = null
	_ui_back = null
	_ui_fill = null


func _gather_meshes_limited(root: Node, limit: int) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root == null or limit <= 0:
		return out
	var stack: Array[Node] = [root]
	while stack.size() > 0 and out.size() < limit:
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			out.append(cur as MeshInstance3D)
		for ch in cur.get_children():
			stack.push_back(ch)
	return out


func _update_beam(length: float, draw_dot: bool, local_end: Vector3) -> void:
	var L: float = clamp(length, 0.0, max_distance)

	if beam is CSGCylinder3D:
		var b: CSGCylinder3D = beam as CSGCylinder3D
		b.height = max(L, 0.001)
		beam.position = Vector3(0, 0, -L * 0.5)

	if dot is GeometryInstance3D:
		var gi: GeometryInstance3D = dot as GeometryInstance3D
		gi.visible = show_dot and draw_dot

	if draw_dot:
		dot.position = local_end
	else:
		dot.position = Vector3(0, 0, -L)
