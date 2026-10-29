class_name CaineAPI
extends Node
## Fachada pública para futuros controladores de IA. Nenhuma decisão automática.
## Comandos contínuos expiram em segundos físicos quando não renovados.

@export_range(0.05, 2.0, 0.05) var move_command_timeout: float = 0.35

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _sensors: CaineSensors = get_node("../CaineSensors") as CaineSensors

var _move_intent: Vector2 = Vector2.ZERO
var _move_time_remaining: float = 0.0
var _jump_pending: bool = false
var _facing_pending: Vector3 = Vector3.ZERO


func set_move_input(direction: Vector2) -> void:
    # X+ direita; Y+ frente. Entradas diagonais nunca excedem magnitude 1.
    _move_intent = direction.limit_length(1.0)
    _move_time_remaining = move_command_timeout if not _move_intent.is_zero_approx() else 0.0


func set_facing_direction(direction: Vector3) -> void:
    var horizontal: Vector3 = Vector3(direction.x, 0.0, direction.z)
    if horizontal.length_squared() > 0.000001:
        _facing_pending = horizontal.normalized()


func request_jump() -> void:
    _jump_pending = true


func stop_movement() -> void:
    _move_intent = Vector2.ZERO
    _move_time_remaining = 0.0


func clear_commands() -> void:
    stop_movement()
    _jump_pending = false
    _facing_pending = Vector3.ZERO


func get_observation() -> Dictionary:
    return _sensors.get_observation()


func get_position() -> Vector3:
    return _body.global_position


func get_velocity() -> Vector3:
    return _body.velocity


func is_grounded() -> bool:
    return _body.is_on_floor()


func get_nearby_objects() -> Array:
    return _sensors.get_nearby_objects()


# Métodos internos consumidos somente pelo controlador físico; não são comandos de IA.
func _consume_move_input(delta: float) -> Vector2:
    if _move_time_remaining <= 0.0:
        _move_intent = Vector2.ZERO
        return Vector2.ZERO
    _move_time_remaining = maxf(0.0, _move_time_remaining - delta)
    return _move_intent


func _take_jump_request() -> bool:
    var requested: bool = _jump_pending
    _jump_pending = false
    return requested


func _take_facing_direction() -> Vector3:
    var requested: Vector3 = _facing_pending
    _facing_pending = Vector3.ZERO
    return requested
