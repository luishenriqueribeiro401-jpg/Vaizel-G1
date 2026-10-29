extends SceneTree
## Rodar SOMENTE em testes: godot --headless --path . --script res://Tests/CaineSmokeTest.gd
## O NPC da cena normal nunca recebe comandos automáticos.

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    var scene: PackedScene = load("res://Scenes/World.tscn")
    _check(scene != null, "Carregamento da cena World")
    if scene == null:
        quit(1)
        return
    var world: Node3D = scene.instantiate() as Node3D
    root.add_child(world)
    await physics_frame

    var caine: CaineController = world.get_node("Caine") as CaineController
    var api: CaineAPI = world.get_node("Caine/AIInterface") as CaineAPI
    var player: PlayerController = world.get_node("Player") as PlayerController
    _check(caine != null and api != null and player != null, "Caine, API e jogador instanciados")
    if caine == null or api == null or player == null:
        quit(1)
        return
    _check(world.get_tree().get_nodes_in_group("caine").size() == 1, "Exatamente um Caine")
    _check(caine.collision_layer == 4 and caine.collision_mask == 11,
        "Caine: camada 3 e máscaras do mundo, jogador e objetos")
    _check((player.collision_mask & 4) != 0, "Jogador colide com a camada de Caine")
    _check(caine.get_node("VisualBody").get_child_count() >= 7, "Corpo humanoide com membros")
    _check(caine.get_node("LeftHandAnchor") is Marker3D and caine.get_node("RightHandAnchor") is Marker3D,
        "Âncoras para mãos prontas")

    for frame in 65:
        await physics_frame
    _check(caine.is_on_floor() and absf(caine.global_position.y) < 0.035,
        "Gravidade nativa e contato com terreno")
    var idle: Vector3 = caine.global_position
    for frame in 50:
        await physics_frame
    _check(Vector2(caine.global_position.x - idle.x, caine.global_position.z - idle.z).length() < 0.025,
        "Nenhum deslocamento espontâneo")

    # O controle do jogador não transmite comandos ao NPC.
    player.set_touch_direction(Vector2(0.0, -1.0))
    for frame in 15:
        await physics_frame
    player.set_touch_direction(Vector2.ZERO)
    _check(caine.global_position.distance_to(idle) < 0.025,
        "Entrada de movimento do jogador não controla Caine")

    var initial: Vector3 = caine.global_position
    api.set_move_input(Vector2(0.0, 1.0))
    for frame in 18:
        await physics_frame
    _check(caine.global_position.z < initial.z - 0.4, "Comando API: avanço local -Z")
    for frame in 55:
        await physics_frame
    _check(Vector2(caine.velocity.x, caine.velocity.z).length() < 0.025,
        "Comando expira sem renovação")
    var after_expiry: Vector3 = caine.global_position
    for frame in 30:
        await physics_frame
    _check(caine.global_position.distance_to(after_expiry) < 0.04,
        "Após expirar, Caine permanece parado")

    api.set_facing_direction(Vector3(1.0, 999.0, 0.0))
    await physics_frame
    _check((-caine.global_basis.z).dot(Vector3.RIGHT) > 0.99 and absf(caine.rotation.x) < 0.0001,
        "Rotação explícita sem inclinação vertical")
    api.set_move_input(Vector2(1.0, 1.0))
    for frame in 15:
        await physics_frame
    var diagonal_velocity: Vector2 = Vector2(caine.velocity.x, caine.velocity.z)
    _check(diagonal_velocity.length() <= caine.move_speed + 0.005
        and absf(diagonal_velocity.x) > 0.4 and absf(diagonal_velocity.y) > 0.4,
        "Diagonal realmente usa os dois eixos sem ultrapassar velocidade")
    api.stop_movement()
    for frame in 40:
        await physics_frame
    _check(Vector2(caine.velocity.x, caine.velocity.z).length() < 0.025,
        "stop_movement desacelera até parar")
    api.set_move_input(Vector2(0.0, -1.0))
    api.request_jump()
    api.clear_commands()
    await physics_frame
    _check(Vector2(caine.velocity.x, caine.velocity.z).length() < 0.025 and caine.velocity.y <= 0.0,
        "clear_commands cancela salto e movimento pendentes")

    api.request_jump()
    await physics_frame
    var upward_speed: float = caine.velocity.y
    _check(upward_speed > 0.0 and not caine.is_on_floor(), "Salto via API")
    api.request_jump()
    await physics_frame
    _check(caine.velocity.y < upward_speed, "Pedido no ar não causa salto duplo")
    for frame in 90:
        await physics_frame
    _check(caine.is_on_floor(), "Caine retorna ao chão")

    # Posicionamento direto é exclusivo do teste de cenários, não da API de caminhar.
    api.clear_commands()
    caine.global_position = Vector3(4.0, 0.06, -2.5)
    caine.velocity = Vector3.ZERO
    api.set_facing_direction(Vector3(0.0, 0.0, -1.0))
    for frame in 20:
        await physics_frame
    var initial_block_distance: float = caine.global_position.distance_to(world.get_node("Obstacles/BlockB").global_position)
    for frame in 110:
        if frame % 10 == 0:
            api.set_move_input(Vector2(0.0, 1.0))
        await physics_frame
    api.stop_movement()
    _check(caine.global_position.z > -4.8, "Bloco impede atravessamento")
    _check(caine.global_position.distance_to(world.get_node("Obstacles/BlockB").global_position) < initial_block_distance,
        "Caine aproxima-se de obstáculo mediante comando")
    for frame in 15:
        await physics_frame
    var info: Dictionary = api.get_observation()
    _check(info.get("agent") == "Caine" and info.get("grounded") == true,
        "Observação fornece identidade e contato com solo")
    _check(info.has("position") and info.has("forward") and info.has("velocity") and info.has("contacts"),
        "Observação possui coordenadas, orientação e contatos")
    var known: Array = info.get("known_objects", [])
    var detected: Array = info.get("detected_objects", [])
    _check(known.size() == 3 and detected.size() <= known.size(), "Conhecidos separados de visíveis")
    _check(info.get("obstacle_ahead") == true, "Sensor frontal detecta bloco")
    var ground_data: Dictionary = info.get("terrain_below", {})
    _check(ground_data.get("detected", false), "Sensor inferior identifica superfície")
    _check(api.get_nearby_objects().size() == detected.size(),
        "get_nearby_objects retorna objetos detectados, não todo o cadastro")
    _check(JSON.parse_string(JSON.stringify(info)) is Dictionary, "Observação serializável em JSON")
    _check(api.get_position().distance_to(caine.global_position) < 0.001 and api.is_grounded(),
        "Consultas diretas à API retornam estado real")

    # Teste de oclusão: um objeto estático não cadastrado bloqueia a vista de BlockC.
    api.clear_commands()
    caine.global_position = Vector3(0.0, 0.06, -7.0)
    caine.velocity = Vector3.ZERO
    api.set_facing_direction(Vector3(0.0, 0.0, -1.0))
    var wall: StaticBody3D = StaticBody3D.new()
    wall.name = "OccluderTest"
    wall.collision_layer = 1
    wall.collision_mask = 0
    wall.position = Vector3(0.0, 1.5, -9.0)
    var wall_shape: CollisionShape3D = CollisionShape3D.new()
    var wall_box: BoxShape3D = BoxShape3D.new()
    wall_box.size = Vector3(4.0, 3.0, 0.4)
    wall_shape.shape = wall_box
    wall.add_child(wall_shape)
    world.add_child(wall)
    for frame in 25:
        await physics_frame
    info = api.get_observation()
    var block_c: Dictionary = {}
    for record: Dictionary in info.get("known_objects", []):
        if record.get("id") == "BlockC":
            block_c = record
    _check(not block_c.is_empty() and block_c.get("visible") == false,
        "Linha de visão não atravessa parede")
    _check(info.get("obstacle_ahead") == true, "Obstáculo não cadastrado ainda bloqueia sensor")

    # Colisão física entre dois CharacterBody3D independentes.
    wall.queue_free()
    player.global_position = Vector3(8.0, 0.06, 0.0)
    player.velocity = Vector3.ZERO
    caine.global_position = Vector3(8.0, 0.06, 2.0)
    caine.velocity = Vector3.ZERO
    for frame in 90:
        if frame % 10 == 0:
            api.set_move_input(Vector2(0.0, 1.0))
        await physics_frame
    api.clear_commands()
    var separation: float = Vector2(caine.global_position.x - player.global_position.x,
        caine.global_position.z - player.global_position.z).length()
    _check(separation > 0.55, "Cápsulas de Caine e jogador não se atravessam")

    print("CAINE SMOKE TEST: ", "PASSOU" if _failures == 0 else "FALHOU", " (", _failures, " falhas)")
    quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
    if condition:
        print("[OK] ", description)
    else:
        _failures += 1
        printerr("[ERRO] ", description)
