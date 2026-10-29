class_name CaineSensors
extends Node
## Observações reais e leves: duas sondas + linha de visão para blocos conhecidos.
## Atualizadas no passo físico, em intervalo configurável; nunca movem o NPC.

@export_range(0.05, 2.0, 0.05) var update_interval: float = 0.2
@export_range(1.0, 30.0, 0.5) var detection_range: float = 12.0
@export_range(30.0, 180.0, 5.0) var field_of_view_degrees: float = 130.0
@export_range(1, 128, 1) var max_checked_blocks: int = 32

@onready var _body: CharacterBody3D = get_parent() as CharacterBody3D
@onready var _eye: Node3D = get_node("../PerceptionOrigin") as Node3D
@onready var _forward_ray: RayCast3D = get_node("../PerceptionOrigin/ForwardSensor") as RayCast3D
@onready var _ground_ray: RayCast3D = get_node("../GroundSensor") as RayCast3D

var _time_since_update: float = 0.0
var _observation: Dictionary = {}
var _detected_objects: Array[Dictionary] = []


func _ready() -> void:
    _forward_ray.add_exception(_body)
    _ground_ray.add_exception(_body)
    # Amostragem já no primeiro _physics_process; o resto a ~5 Hz.
    _time_since_update = update_interval


func _physics_process(delta: float) -> void:
    _time_since_update += delta
    if _time_since_update < update_interval:
        return
    _time_since_update = fmod(_time_since_update, update_interval)
    _sample()


func get_observation() -> Dictionary:
    # Nunca vazar referências a nós ou permitir que o consumidor altere o cache.
    return _observation.duplicate(true)


func get_nearby_objects() -> Array:
    return _detected_objects.duplicate(true)


func _sample() -> void:
    _forward_ray.force_raycast_update()
    _ground_ray.force_raycast_update()

    var forward: Vector3 = -_body.global_transform.basis.z.normalized()
    var eye_position: Vector3 = _eye.global_position
    var known_blocks: Array[Dictionary] = []
    var detected_blocks: Array[Dictionary] = []
    var nearest_distance: float = INF
    var checked: int = 0

    # "Conhecido" = cadastrado pelo mundo; "detectado" = dentro do cone e com LOS.
    for candidate: Node in get_tree().get_nodes_in_group("world_blocks"):
        if checked >= max_checked_blocks:
            break
        var block: StaticBody3D = candidate as StaticBody3D
        if block == null:
            continue
        checked += 1
        var difference: Vector3 = block.global_position - _body.global_position
        var distance: float = difference.length()
        nearest_distance = minf(nearest_distance, distance)
        var visible: bool = _is_visible(block, eye_position, forward)
        var local_direction: Vector3 = _body.global_transform.basis.inverse() * difference.normalized() if distance > 0.00001 else Vector3.ZERO
        var record: Dictionary = {
            "id": String(block.name),
            "type": "static_block",
            "position": _vector_data(block.global_position),
            "distance_m": distance,
            "relative_direction": _vector_data(local_direction),
            "visible": visible
        }
        known_blocks.append(record)
        if visible:
            detected_blocks.append(record)

    _detected_objects = detected_blocks
    var obstacle: Dictionary = _ray_result(_forward_ray)
    var terrain: Dictionary = _ray_result(_ground_ray)
    var horizontal_speed: float = Vector2(_body.velocity.x, _body.velocity.z).length()
    var collision_contacts: Array[Dictionary] = []
    for index: int in range(mini(_body.get_slide_collision_count(), 4)):
        var collision: KinematicCollision3D = _body.get_slide_collision(index)
        var collider: Object = collision.get_collider()
        collision_contacts.append({
            "id": _object_id(collider),
            "type": _object_type(collider),
            "point": _vector_data(collision.get_position()),
            "normal": _vector_data(collision.get_normal())
        })

    _observation = {
        "agent": String(_body.name),
        "position": _vector_data(_body.global_position),
        "rotation_y": _body.rotation.y,
        "forward": _vector_data(forward),
        "velocity": _vector_data(_body.velocity),
        "grounded": _body.is_on_floor(),
        "moving": horizontal_speed > 0.08,
        "horizontal_speed_mps": horizontal_speed,
        "can_jump": _body.is_on_floor(),
        "known_objects": known_blocks,
        "detected_objects": detected_blocks,
        "nearby_objects": detected_blocks,
        "nearest_known_block_distance_m": nearest_distance if not is_inf(nearest_distance) else null,
        "obstacle_ahead": _forward_ray.is_colliding(),
        "obstacle": obstacle,
        "terrain_below": terrain,
        "contacts": collision_contacts,
        "sensor_range_m": detection_range,
        "sensor_fov_degrees": field_of_view_degrees,
        "sensor_interval_s": update_interval
    }


func _is_visible(block: StaticBody3D, eye_position: Vector3, forward: Vector3) -> bool:
    var to_block: Vector3 = block.global_position - eye_position
    var distance: float = to_block.length()
    if distance <= 0.00001 or distance > detection_range:
        return false
    if forward.dot(to_block / distance) < cos(deg_to_rad(field_of_view_degrees * 0.5)):
        return false
    # O primeiro colisor tem de ser o próprio bloco, não algo atrás da parede.
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        eye_position, block.global_position, 1 | 2 | 4 | 8, [_body.get_rid()]
    )
    var hit: Dictionary = _body.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit.get("collider") == block


func _ray_result(ray: RayCast3D) -> Dictionary:
    if not ray.is_colliding():
        return {"detected": false, "id": null, "type": null, "distance_m": null, "normal": null}
    var hit: Object = ray.get_collider()
    return {
        "detected": true,
        "id": _object_id(hit),
        "type": _object_type(hit),
        "distance_m": ray.global_position.distance_to(ray.get_collision_point()),
        "normal": _vector_data(ray.get_collision_normal())
    }


func _object_id(object: Object) -> Variant:
    if object is Node:
        return String((object as Node).name)
    return null


func _object_type(object: Object) -> String:
    if object is Node:
        var node: Node = object as Node
        if node.is_in_group("world_blocks"):
            return "static_block"
        if node.is_in_group("terrain"):
            return "terrain"
        if node.is_in_group("player"):
            return "player"
        if node.is_in_group("caine"):
            return "caine"
    return "other_physics_body"


func _vector_data(value: Vector3) -> Dictionary:
    return {"x": value.x, "y": value.y, "z": value.z}
