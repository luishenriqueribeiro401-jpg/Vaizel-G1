extends SceneTree
## Executar com: godot --headless --path . --script res://Tests/SmokeTest.gd
## Testes reais exigem um binário Godot 4 instalado.

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    var packed: PackedScene = load("res://Scenes/World.tscn")
    _check(packed != null, "World.tscn carregada")
    if packed == null:
        quit(1)
        return
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    await physics_frame

    var player: PlayerController = world.get_node("Player") as PlayerController
    var ui: MobileControls = world.get_node("MobileControls/Overlay") as MobileControls
    var ground: StaticBody3D = world.get_node("Terrain") as StaticBody3D
    var ground_collider: CollisionShape3D = ground.get_node("CollisionShape3D") as CollisionShape3D
    _check(player != null and ui != null and ground != null, "Nós principais existem")
    _check(is_equal_approx(ground_collider.global_position.y, -0.1), "Topo do solo em Y=0")
    _check(player.collision_mask == 5 and player.collision_layer == 2, "Camadas e máscaras físicas")

    for frame in 60:
        await physics_frame
    _check(player.is_on_floor(), "Gravidade e contato com o chão")
    _check(absf(player.global_position.y) < 0.025, "Cápsula apoiada no nível Y=0")

    var initial_z: float = player.global_position.z
    player.set_touch_direction(Vector2(0.0, -1.0))
    for frame in 30:
        await physics_frame
    player.set_touch_direction(Vector2.ZERO)
    _check(player.global_position.z < initial_z - 0.5, "Movimento para frente via entrada analógica")

    for frame in 30:
        await physics_frame
    var before_jump: float = player.global_position.y
    player.request_jump()
    await physics_frame
    _check(player.velocity.y > 0.0 and player.global_position.y > before_jump, "Pulo do jogador")

    # Toques distintos devem ocupar joystick, câmera e botão, sem colisão de índices.
    ui.visible = true  # Ambiente headless não é classificado como celular.
    var joystick_center: Vector2 = ui.joystick.global_position + ui.joystick.size * 0.5
    var camera_point: Vector2 = ui.size * Vector2(0.65, 0.40)
    var touch: InputEventScreenTouch = InputEventScreenTouch.new()
    touch.pressed = true
    touch.index = 3
    touch.position = joystick_center
    ui._input(touch)
    touch = InputEventScreenTouch.new()
    touch.pressed = true
    touch.index = 4
    touch.position = camera_point
    ui._input(touch)
    touch = InputEventScreenTouch.new()
    touch.pressed = true
    touch.index = 5
    touch.position = ui._jump_center
    ui._input(touch)
    _check(ui.joystick.finger_index == 3 and ui._camera_finger == 4 and ui._jump_finger == 5, "Índices multitouch independentes")
    var move_drag: InputEventScreenDrag = InputEventScreenDrag.new()
    move_drag.index = 3
    move_drag.position = joystick_center + Vector2(50.0, 0.0)
    move_drag.relative = Vector2(50.0, 0.0)
    ui._input(move_drag)
    _check(ui.joystick.direction.x > 0.1, "Joystick com resposta analógica")
    var initial_yaw: float = player.rotation.y
    var look_drag: InputEventScreenDrag = InputEventScreenDrag.new()
    look_drag.index = 4
    look_drag.position = camera_point + Vector2(40.0, -12.0)
    look_drag.relative = Vector2(40.0, -12.0)
    ui._input(look_drag)
    for frame in 15:
        await process_frame
    _check(absf(player.rotation.y - initial_yaw) > 0.001, "Câmera responde a InputEventScreenDrag")
    ui._end_touch(3)
    _check(ui.joystick.direction == Vector2.ZERO and ui._camera_finger == 4 and ui._jump_finger == 5, "Release isolado do joystick")
    ui._end_touch(4)
    ui._end_touch(5)
    _check(ui._camera_finger == -1 and ui._jump_finger == -1, "Liberação de todos os dedos")

    var original_size: Vector2 = ui.size
    ui.size = Vector2(960.0, 540.0)
    ui._update_layout()
    _check(ui.joystick.position.y > 0.0 and ui._jump_center.x < ui.size.x,
        "Controles responsivos após redimensionamento")
    ui.size = original_size
    ui._update_layout()

    # O bloco C tem face frontal em Z=-11; cápsula (raio 0,35)
    # não pode avançar além da face (aprox. Z=-10,65).
    player.global_position = Vector3(0.0, 0.05, -8.0)
    player.velocity = Vector3.ZERO
    for frame in 60:
        await physics_frame
    player.set_touch_direction(Vector2(0.0, -1.0))
    for frame in 90:
        await physics_frame
    player.set_touch_direction(Vector2.ZERO)
    _check(player.global_position.z > -10.85, "Bloco C impede atravessamento")

    print("SMOKE TEST: ", "PASSOU" if _failures == 0 else "FALHOU", " (", _failures, " falhas)")
    quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
    if condition:
        print("[OK] ", description)
    else:
        _failures += 1
        printerr("[ERRO] ", description)
