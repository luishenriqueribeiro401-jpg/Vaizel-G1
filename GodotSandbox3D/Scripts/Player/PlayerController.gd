class_name PlayerController
extends CharacterBody3D
## Jogador em primeira pessoa. Não conhece os nós de UI.

@export_range(0.1, 20.0, 0.1) var move_speed: float = 5.0
@export_range(0.1, 50.0, 0.1) var acceleration: float = 18.0
@export_range(0.1, 50.0, 0.1) var deceleration: float = 24.0
@export_range(0.1, 30.0, 0.01) var gravity_strength: float = 9.81
@export_range(0.1, 5.0, 0.05) var jump_height: float = 1.2
@export_range(0.0001, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(0.0001, 0.02, 0.0001) var touch_sensitivity: float = 0.0028
@export_range(1.0, 40.0, 0.5) var touch_look_smoothing: float = 18.0

@onready var camera_pivot: Node3D = $CameraPivot

var _touch_direction: Vector2 = Vector2.ZERO
var _jump_requested: bool = false
var _paused: bool = false
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
const MAX_PITCH: float = PI * 0.47222222  # 85 graus.


func _ready() -> void:
    _target_yaw = rotation.y
    _target_pitch = camera_pivot.rotation.x
    set_process(false)  # Suavização só é processada quando há gesto de câmera.
    if OS.has_feature("mobile") or OS.get_name() == "Android":
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
    if _paused:
        return

    var direction_2d: Vector2 = Input.get_vector(
        "move_left", "move_right", "move_forward", "move_backward"
    )
    direction_2d = (direction_2d + _touch_direction).limit_length(1.0)

    # Só o yaw do corpo afeta a direção; o pitch é exclusivo da câmera.
    var desired: Vector3 = (transform.basis * Vector3(direction_2d.x, 0.0, direction_2d.y)) * move_speed
    var rate: float = acceleration if direction_2d.length_squared() > 0.0001 else deceleration
    velocity.x = move_toward(velocity.x, desired.x, rate * delta)
    velocity.z = move_toward(velocity.z, desired.z, rate * delta)

    if not is_on_floor():
        velocity.y -= gravity_strength * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    var wants_jump: bool = Input.is_action_just_pressed("jump") or _jump_requested
    _jump_requested = false
    if wants_jump and is_on_floor():
        velocity.y = sqrt(2.0 * gravity_strength * jump_height)

    # move_and_slide usa velocity em m/s; NÃO multiplicar velocity por delta.
    move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause") and not event.is_echo():
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _release_mouse()
        elif not (OS.has_feature("mobile") or OS.get_name() == "Android"):
            _capture_mouse()
        get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseButton:
        var click: InputEventMouseButton = event
        if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
            if not (OS.has_feature("mobile") or OS.get_name() == "Android"):
                _capture_mouse()
                get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var motion: InputEventMouseMotion = event
        _apply_mouse_look(motion.relative)


func _apply_mouse_look(delta_pixels: Vector2) -> void:
    rotation.y -= delta_pixels.x * mouse_sensitivity
    camera_pivot.rotation.x = clampf(
        camera_pivot.rotation.x - delta_pixels.y * mouse_sensitivity,
        -MAX_PITCH, MAX_PITCH
    )
    _target_yaw = rotation.y
    _target_pitch = camera_pivot.rotation.x


func set_touch_direction(direction: Vector2) -> void:
    _touch_direction = direction.limit_length(1.0)


func request_jump() -> void:
    if not _paused:
        _jump_requested = true


func add_touch_look(delta_pixels: Vector2) -> void:
    if _paused:
        return
    _target_yaw -= delta_pixels.x * touch_sensitivity
    _target_pitch = clampf(_target_pitch - delta_pixels.y * touch_sensitivity, -MAX_PITCH, MAX_PITCH)
    set_process(true)


func _process(delta: float) -> void:
    if _paused:
        return
    var blend: float = 1.0 - exp(-touch_look_smoothing * delta)
    rotation.y = lerp_angle(rotation.y, _target_yaw, blend)
    camera_pivot.rotation.x = lerpf(camera_pivot.rotation.x, _target_pitch, blend)
    if absf(wrapf(_target_yaw - rotation.y, -PI, PI)) < 0.0001 and absf(_target_pitch - camera_pivot.rotation.x) < 0.0001:
        rotation.y = _target_yaw
        camera_pivot.rotation.x = _target_pitch
        set_process(false)


func enable_touch_mode() -> void:
    # Toque não é pausa: o jogador continua andando e pulando no Android.
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _paused = false
    _target_yaw = rotation.y
    _target_pitch = camera_pivot.rotation.x


func _release_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _paused = true
    _jump_requested = false
    _touch_direction = Vector2.ZERO
    set_process(false)


func _capture_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _paused = false
    _target_yaw = rotation.y
    _target_pitch = camera_pivot.rotation.x
