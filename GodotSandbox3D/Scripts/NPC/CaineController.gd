class_name CaineController
extends CharacterBody3D
## Física exclusivamente motora. Não lê Input, UI, teclado, mouse ou joystick.
## A intenção de movimento é consumida somente de AIInterface (CaineAPI).

@export_range(0.1, 12.0, 0.1) var move_speed: float = 4.0
@export_range(0.1, 50.0, 0.1) var acceleration: float = 16.0
@export_range(0.1, 50.0, 0.1) var deceleration: float = 22.0
@export_range(0.1, 30.0, 0.01) var gravity_strength: float = 9.81
@export_range(0.1, 5.0, 0.05) var jump_height: float = 1.2

@onready var _api: CaineAPI = $AIInterface


func _physics_process(delta: float) -> void:
    # A orientação é horizontal e só muda mediante comando explícito.
    var requested_facing: Vector3 = _api._take_facing_direction()
    if requested_facing.length_squared() > 0.000001:
        rotation.y = atan2(-requested_facing.x, -requested_facing.z)

    # +X = direita local; +Y = frente local (-Z na Godot).
    var input_direction: Vector2 = _api._consume_move_input(delta)
    var local_direction: Vector3 = Vector3(input_direction.x, 0.0, -input_direction.y)
    var desired_velocity: Vector3 = basis * local_direction * move_speed
    var current_horizontal: Vector2 = Vector2(velocity.x, velocity.z)
    var desired_horizontal: Vector2 = Vector2(desired_velocity.x, desired_velocity.z)
    var rate: float = acceleration if input_direction.length_squared() > 0.000001 else deceleration
    var new_horizontal: Vector2 = current_horizontal.move_toward(desired_horizontal, rate * delta)
    velocity.x = new_horizontal.x
    velocity.z = new_horizontal.y

    if not is_on_floor():
        velocity.y -= gravity_strength * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    # Pedido é de uso único; pedido no ar é descartado, nunca vira segundo pulo.
    if _api._take_jump_request() and is_on_floor():
        velocity.y = sqrt(2.0 * gravity_strength * jump_height)

    # CharacterBody3D.move_and_slide() usa velocity em m/s.
    move_and_slide()
