extends Node3D
## Vaizel G1 (Web runtime). NO kinematic motion and NO stand-in neural network.
## MuJoCo WASM handles all 12 joint torques and contacts; Godot only renders its poses.
## Android Godot Editor cannot load MuJoCo WASM as a native GDExtension.

const OFFICIAL_DEMO: String = "https://www.humanoidrobots.training/unitree/g1"

@onready var parts_root: Node3D = $Robot
@onready var status_label: Label = $Overlay/Status
@onready var eye_camera: Camera3D = $EyeViewport/EyeCamera

var _online: bool = false
var _rig_loaded: bool = false
var _runtime_status: String = ""
var _visuals: Dictionary = {}
var _last_step: int = -1
var _poll_clock: float = 0.0
var _hud_clock: float = 0.0
var _command: Vector3 = Vector3(0.5, 0.0, 0.0)
var _mesh_ids: Array[int] = []
var _mesh_clock: float = 0.0
var _loaded_mesh_count: int = 0


func _ready() -> void:
    _add_controls()
    if OS.has_feature("web"):
        _online = true
        _set_status("Vaizel G1 | Carregando MuJoCo WASM e rede oficial ONNX...\nNenhuma animacao falsa sera executada.")
    else:
        _set_status("Vaizel G1 | Android Editor: runtime Web nao disponivel.\nO corpo so aparece depois de ativar a politica oficial.\nUse DEMO REAL ou publique a exportacao Web no celular.")


func _process(delta: float) -> void:
    if not _online:
        return
    _poll_clock += delta
    _hud_clock += delta
    _mesh_clock += delta
    if _poll_clock >= 0.055:
        _poll_clock = 0.0
        _poll_runtime()
    if _mesh_clock > 0.3 and not _mesh_ids.is_empty():
        _mesh_clock = 0.0
        _upgrade_one_mesh()
    if _hud_clock >= 1.0:
        _hud_clock = 0.0
        _read_status()


func _js(expression: String) -> Variant:
    if not OS.has_feature("web"):
        return null
    return JavaScriptBridge.eval(expression)


func _poll_runtime() -> void:
    var raw: Variant = _js("window.VaizelG1Bridge ? window.VaizelG1Bridge.statusJSON() : ''")
    if not (raw is String) or raw.is_empty():
        return
    var info: Variant = JSON.parse_string(raw)
    if not (info is Dictionary):
        return
    var phase: String = str(info.get("stage", "INICIANDO"))
    if phase == "ERRO":
        _runtime_status = str(info.get("error", "Erro desconhecido"))
        return
    _runtime_status = phase
    if not bool(info.get("ready", false)):
        return
    if not _rig_loaded:
        var rig_string: Variant = _js("window.VaizelG1Bridge.rigJSON()")
        if rig_string is String:
            var rig: Variant = JSON.parse_string(rig_string)
            if rig is Dictionary:
                _build_rig(rig)
    if not _rig_loaded:
        return
    var pose_string: Variant = _js("window.VaizelG1Bridge.poseJSON()")
    if pose_string is String:
        var pose: Variant = JSON.parse_string(pose_string)
        if pose is Dictionary:
            _apply_pose(pose)


func _build_rig(rig: Dictionary) -> void:
    if str(rig.get("robot", "")) != "Unitree G1 12-DoF":
        _runtime_status = "Corpo incompatível com a politica oficial"
        return
    for existing: Node in parts_root.get_children():
        existing.queue_free()
    _visuals.clear()
    _mesh_ids.clear()
    for item: Variant in rig.get("geoms", []):
        if not (item is Dictionary):
            continue
        var geom_id: int = int(item.get("id", -1))
        if geom_id < 0:
            continue
        var dims: Array = item.get("size", [])
        var color_data: Array = item.get("rgba", [])
        var shape: String = str(item.get("shape", "box"))
        if dims.is_empty() or color_data.size() < 3:
            continue
        var geometry: PrimitiveMesh
        if shape == "sphere":
            var sphere: SphereMesh = SphereMesh.new()
            sphere.radius = maxf(float(dims[0]), 0.01)
            sphere.height = sphere.radius * 2.0
            geometry = sphere
        elif shape == "cylinder":
            var cylinder: CylinderMesh = CylinderMesh.new()
            cylinder.top_radius = maxf(float(dims[0]), 0.01)
            cylinder.bottom_radius = cylinder.top_radius
            cylinder.height = maxf(float(dims[1]) * 2.0, 0.03)
            geometry = cylinder
        elif shape == "capsule":
            var capsule: CapsuleMesh = CapsuleMesh.new()
            capsule.radius = maxf(float(dims[0]), 0.01)
            capsule.height = maxf(float(dims[1]) * 2.0 + capsule.radius * 2.0, 0.03)
            geometry = capsule
        else:
            var box: BoxMesh = BoxMesh.new()
            box.size = Vector3(maxf(float(dims[0]), 0.012), maxf(float(dims[1]), 0.012), maxf(float(dims[2]), 0.012))
            geometry = box
        var visual: MeshInstance3D = MeshInstance3D.new()
        visual.mesh = geometry
        var material: StandardMaterial3D = StandardMaterial3D.new()
        material.albedo_color = Color(float(color_data[0]),float(color_data[1]),float(color_data[2]), 1.0)
        material.metallic = 0.14
        material.roughness = 0.62
        visual.material_override = material
        visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parts_root.add_child(visual)
        _visuals[geom_id] = visual
        if str(item.get("shape", "")) == "box" and bool(item.get("is_mesh", false)):
            _mesh_ids.append(geom_id)
    _rig_loaded = not _visuals.is_empty()
    if not _rig_loaded:
        _runtime_status = "MuJoCo carregou, mas nao enviou geometrias validas"


func _apply_pose(packet: Dictionary) -> void:
    var counter: int = int(packet.get("step", -1))
    if counter == _last_step:
        return
    _last_step = counter
    for raw: Variant in packet.get("parts", []):
        if not (raw is Array) or raw.size() != 13:
            continue
        var geom_id: int = int(raw[0])
        if not _visuals.has(geom_id):
            continue
        var basis: Basis = Basis(
            Vector3(float(raw[4]),float(raw[7]),float(raw[10])),
            Vector3(float(raw[5]),float(raw[8]),float(raw[11])),
            Vector3(float(raw[6]),float(raw[9]),float(raw[12]))
        )
        var position: Vector3 = Vector3(float(raw[1]), float(raw[2]), float(raw[3]))
        var visual: MeshInstance3D = _visuals[geom_id]
        visual.transform = Transform3D(basis, position)
    var pelvis: Array = packet.get("pelvis", [])
    if pelvis.size() == 3:
        var point: Vector3 = Vector3(float(pelvis[0]), float(pelvis[1]), float(pelvis[2]))
        eye_camera.global_position = global_position + point + Vector3(0.0, 0.44, 0.0)
        eye_camera.rotation = Vector3(0, -PI / 2.0, 0)


func _read_status() -> void:
    var raw: Variant = _js("window.VaizelG1Bridge ? window.VaizelG1Bridge.statusJSON() : ''")
    var parsed: Variant = JSON.parse_string(raw) if raw is String and not raw.is_empty() else null
    if not (parsed is Dictionary):
        _set_status("VAIZEL | Script MuJoCo ainda nao iniciou. Verifique o pacote Web.")
        return
    var stage: String = str(parsed.get("stage", ""))
    if stage == "ERRO":
        var reason: String = str(parsed.get("error", ""))
        _set_status("VAIZEL G1 | ERRO REAL\n" + reason.substr(0, 190))
        return
    if bool(parsed.get("ready", false)) and _rig_loaded:
        _set_status("VAIZEL G1 | POLITICA OFICIAL ATIVA\nMuJoCo | %.1f Hz politica | %d passos | %.2f m\n12 motores fisicos | malhas: %d" % [float(parsed.get("policiesPerSec",0.0)),int(parsed.get("steps",0)),float(parsed.get("baseHeight",0.0)),_loaded_mesh_count])
    else:
        _set_status("VAIZEL G1 | " + stage + "\nEsperando rede oficial e modelo fisico carregarem.")


func _set_status(message: String) -> void:
    status_label.text = message


func _set_velocity(vx: float, vy: float, wz: float) -> void:
    _command = Vector3(vx, vy, wz)
    if OS.has_feature("web"):
        _js("window.VaizelG1Bridge && window.VaizelG1Bridge.setVelocity(%f,%f,%f)" % [vx,vy,wz])


func _do_reset() -> void:
    if OS.has_feature("web"):
        _js("window.VaizelG1Bridge && window.VaizelG1Bridge.reset()")


func _add_controls() -> void:
    var bar: HBoxContainer = HBoxContainer.new()
    bar.position = Vector2(8, 210)
    bar.add_theme_constant_override("separation", 3)
    $Overlay.add_child(bar)
    var actions: Array = [
        ["AVANCAR", 0], ["VIRAR E", 1], ["VIRAR D", 2],
        ["PARAR", 3], ["RESET", 4], ["DEMO REAL", 5]
    ]
    for pair: Array in actions:
        var button: Button = Button.new()
        button.text = str(pair[0])
        button.custom_minimum_size = Vector2(76, 44)
        var action: int = int(pair[1])
        button.pressed.connect(_on_control.bind(action))
        bar.add_child(button)


func _on_control(action: int) -> void:
    match action:
        0: _set_velocity(0.5, 0.0, 0.0)
        1: _set_velocity(0.25,0.0,0.5)
        2: _set_velocity(0.25,0.0,-0.5)
        3: _set_velocity(0.0,0.0,0.0)
        4: _do_reset()
        5: OS.shell_open(OFFICIAL_DEMO)


func _upgrade_one_mesh() -> void:
    if _mesh_ids.is_empty():
        return
    var index: int = _mesh_ids.pop_front()
    var script: String = "window.VaizelG1Bridge ? window.VaizelG1Bridge.meshJSON(%d) : ''" % index
    var raw: Variant = _js(script)
    if not (raw is String) or raw.is_empty():
        return
    var parsed: Variant = JSON.parse_string(raw)
    if not (parsed is Dictionary) or not _visuals.has(index):
        return
    var vertices: Array = parsed.get("vertices", [])
    var faces: Array = parsed.get("faces", [])
    if vertices.size() < 9 or faces.size() < 3:
        return
    var arr: Array = []
    arr.resize(Mesh.ARRAY_MAX)
    var points: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    for n: int in range(0, faces.size()-2, 3):
        var i0: int = int(faces[n])*3
        var i1: int = int(faces[n+1])*3
        var i2: int = int(faces[n+2])*3
        if maxi(i0, maxi(i1,i2)) + 2 >= vertices.size() or mini(i0, mini(i1,i2)) < 0:
            continue
        var p0: Vector3 = Vector3(float(vertices[i0]),float(vertices[i0+1]),float(vertices[i0+2]))
        var p1: Vector3 = Vector3(float(vertices[i1]),float(vertices[i1+1]),float(vertices[i1+2]))
        var p2: Vector3 = Vector3(float(vertices[i2]),float(vertices[i2+1]),float(vertices[i2+2]))
        var normal: Vector3 = (p1-p0).cross(p2-p0).normalized()
        points.append_array(PackedVector3Array([p0,p1,p2]))
        normals.append_array(PackedVector3Array([normal,normal,normal]))
    if points.is_empty():
        return
    arr[Mesh.ARRAY_VERTEX] = points
    arr[Mesh.ARRAY_NORMAL] = normals
    var loaded_mesh: ArrayMesh = ArrayMesh.new()
    loaded_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var display: MeshInstance3D = _visuals[index]
    display.mesh = loaded_mesh
    _loaded_mesh_count += 1
