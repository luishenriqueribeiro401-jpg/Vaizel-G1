class_name SandboxVirtualJoystick
extends Control
## Joystick visual; cada dedo pertence a somente um controle.
signal direction_changed(direction: Vector2)

@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.14
@export_range(0.3, 1.0, 0.05) var knob_travel: float = 0.63

var finger_index: int = -1
var direction: Vector2 = Vector2.ZERO


func try_begin(index: int, screen_position: Vector2) -> bool:
    if finger_index >= 0:
        return false
    var center: Vector2 = global_position + size * 0.5
    var radius: float = minf(size.x, size.y) * 0.5
    if center.distance_to(screen_position) > radius * 1.25:
        return false
    finger_index = index
    move_finger(screen_position)
    return true


func move_finger(screen_position: Vector2) -> void:
    if finger_index < 0:
        return
    var center: Vector2 = global_position + size * 0.5
    var radius: float = minf(size.x, size.y) * 0.5 * knob_travel
    var raw_direction: Vector2 = (screen_position - center) / maxf(radius, 1.0)
    raw_direction = raw_direction.limit_length(1.0)
    var magnitude: float = raw_direction.length()
    if magnitude < dead_zone:
        direction = Vector2.ZERO
    else:
        direction = raw_direction.normalized() * ((magnitude - dead_zone) / (1.0 - dead_zone))
    direction_changed.emit(direction)
    queue_redraw()


func end_finger(index: int) -> void:
    if index != finger_index:
        return
    finger_index = -1
    direction = Vector2.ZERO
    direction_changed.emit(Vector2.ZERO)
    queue_redraw()


func reset() -> void:
    if finger_index >= 0:
        end_finger(finger_index)


func _draw() -> void:
    var center: Vector2 = size * 0.5
    var radius: float = minf(size.x, size.y) * 0.5
    draw_circle(center, radius, Color(0.07, 0.10, 0.14, 0.30))
    draw_arc(center, radius - 2.0, 0.0, TAU, 64, Color(0.92, 0.95, 1.0, 0.42), 2.0, true)
    var thumb_position: Vector2 = center + direction * radius * knob_travel
    draw_circle(thumb_position, radius * 0.35, Color(0.85, 0.90, 0.96, 0.62))
    draw_arc(thumb_position, radius * 0.35, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.65), 2.0, true)
