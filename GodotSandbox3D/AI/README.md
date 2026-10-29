# AI/ — interface de comando e percepção do Caine

Nesta versão **não existe uma inteligência artificial em execução**: Caine é um corpo controlável somente através de `CaineAPI.gd`. Não há decisão autônoma, patrulha, comunicação externa, aprendizado, navegação ou manipulação de objetos. O controlador físico não lê entradas de teclado, mouse ou touchscreen. Gravidade e colisões continuam ativas mesmo sem comandos.

## Arquivos e responsabilidades

- `Agents/Caine/CaineAPI.gd`: comandos externos, validade temporal, consultas de estado.
- `../Scripts/NPC/CaineController.gd`: física com `CharacterBody3D`, pulo, aceleração, orientação e `move_and_slide()`.
- `Perception/CaineSensors.gd`: duas sondas `RayCast3D`, observação periódica, consulta de visibilidade e contatos.
- `../Scenes/NPC/Caine.tscn`: humanoide de geometria primitiva, cápsula, sensores e pontos das mãos.
- `Behaviors/`: reservado para lógica de decisões (não implementada).
- `Navigation/`: reservado para planejamento/caminhos (não implementado).
- `Config/`: reservado para configurações adicionais de futuros agentes.

## Como acessar a API

A partir da cena principal, o nó está em `World/Caine/AIInterface`:

```gdscript
var api: CaineAPI = get_node("/root/World/Caine/AIInterface") as CaineAPI
```

A cena `World` deve estar na árvore, e o nó deve ter terminado `_ready()`. O exemplo a seguir é um **script externo opcional**, não adicionado à cena principal. Anexe-o manualmente a um nó de testes da cena World, nunca ao controlador do jogador:

```gdscript
extends Node

func _ready() -> void:
    await get_tree().physics_frame
    var api: CaineAPI = get_node("/root/World/Caine/AIInterface") as CaineAPI
    api.set_facing_direction(Vector3(1.0, 7.0, 0.0)) # Y ignorado: olhar para +X
    api.set_move_input(Vector2(0.0, 1.0))             # avançar na direção local -Z
    await get_tree().physics_frame
    await get_tree().physics_frame
    var observation: Dictionary = api.get_observation()
    print(JSON.stringify(observation))
    api.stop_movement()
```

**Comandos públicos:**

| API | Efeito |
| --- | --- |
| `set_move_input(Vector2(x, y))` | X+ direita, X- esquerda, Y+ frente, Y- trás; normaliza magnitude > 1 |
| `set_facing_direction(Vector3)` | gira yaw para orientação horizontal; ignora componente Y e vetores horizontais nulos |
| `request_jump()` | um único pedido, executado apenas se no chão; pedido no ar é descartado |
| `stop_movement()` | zera a intenção direcional; desaceleração física continua |
| `clear_commands()` | cancela caminhada, rotação pendente e salto pendente |
| `get_observation() -> Dictionary` | última amostra de dados reais dos sensores e do corpo |
| `get_position() -> Vector3` | posição global atual (base da cápsula) |
| `get_velocity() -> Vector3` | velocidade atual, m/s |
| `is_grounded() -> bool` | estado nativo do corpo no solo |
| `get_nearby_objects() -> Array` | lista amostrada de blocos detectados (visíveis), não todos os conhecidos |

Comandos de caminhada são **temporários**: parâmetro exportado `move_command_timeout` (padrão 0,35 s). Se a IA quiser caminhar continuamente, precisa renovar `set_move_input` antes de expirar. Se parar de enviar comandos, Caine desacelera até parar. Os comandos de rotação e salto são pedidos de uso único processados no próximo passo físico. Não há teleporte pela API.

## Percepção e JSON

`CaineSensors` amostra o mundo a cada **0,2 s** (configurável). As sondas são atualizadas sob demanda no passo físico, e a visibilidade dos blocos conhecidos usa consultas de linha de visão que não atravessam obstáculos. Observações são **cacheadas**: podem estar atrasadas em até um intervalo de amostragem. As consultas `get_position()`, `get_velocity()`, `is_grounded()` retornam os valores físicos atuais.

Campos principais:

- `agent`, `position`, `rotation_y`, `forward`, `velocity`, `grounded`, `moving`, `horizontal_speed_mps`, `can_jump`.
- `known_objects`: blocos cadastrados no grupo `world_blocks`, incluindo os que estão fora do campo de visão. Cada item inclui `id`, `type`, `position`, `distance_m`, `relative_direction` e `visible`.
- `detected_objects`, `nearby_objects`: somente os blocos conhecidos dentro do alcance/cone e com linha de visão livre.
- `nearest_known_block_distance_m`: distância até o bloco conhecido mais próximo, mesmo que não esteja visível; `null` se não houver blocos cadastrados.
- `obstacle_ahead`, `obstacle`: leitura do raio central frontal, com ponto inicial na cabeça e até 6 m à frente.
- `terrain_below`: leitura do sensor inferior; diferencia `terrain`, `static_block`, `player` etc. quando detecta um colisor.
- `contacts`: até quatro colisões de deslizamento registradas no último passo físico.
- `sensor_range_m`, `sensor_fov_degrees`, `sensor_interval_s`: parâmetros da amostragem.

**Convenções:** origem da posição de Caine na base do corpo; coordenadas globais em metros (X direita do mundo, Y altura, Z profundidade), eixo local **-Z é frente**, giro `rotation_y` em radianos (yaw), velocidades em m/s, distâncias em metros. `relative_direction` é um vetor unitário (X direita local, Y para cima, Z local negativo para frente), não um deslocamento em metros. `null` representa ausência de leitura válida. Só se retornam números, booleans, strings, dicionários e arrays, sem `Vector3`, nós, RID ou recursos na observação; é seguro usar `JSON.stringify()`.

**Limitações dos sensores:** cones e raios não equivalem a uma imagem; os blocos devem fazer parte do grupo `world_blocks`, e o limite de blocos consultados por amostra é configurável (32). A visibilidade usa um raio até o centro de cada bloco: pode deixar de detectar objetos parcialmente encobertos ou fora do campo. O raio frontal é central, então não cobre toda a largura corporal. O solo é inferido por um raio curto e pelo contato nativo `is_on_floor()`. O campo `known_objects` representa cadastro global, **não algo que Caine necessariamente viu**. Para uma futura percepção visual, acrescente uma câmera ou sensores adicionais ao `PerceptionOrigin`, preservando a diferença entre cadastro e detecção.

## Integrar uma IA futuramente

Uma futura IA pode ler `get_observation()`, escolher ações, enviar `set_move_input()`, `set_facing_direction()` e `request_jump()`, e repetir essa sequência em uma frequência menor que a atualização de física. Deve renovar os comandos contínuos periodicamente e limpar comandos em interrupções. Se houver um serviço remoto futuramente, ele deverá residir em outro componente de integração, com validação de mensagens; **nenhuma conexão nem credencial existe neste projeto**.

## Futuro agarrar e manipular

Os nós `LeftHandAnchor` e `RightHandAnchor` marcam posições futuras de pega. Uma etapa futura poderá definir um contrato de ações (`grab`, `hold`, `carry`, `release`) na API, detectar quais objetos possuem permissão de manipulação, usar `RigidBody3D` na camada 4, e implementar interação física controlada com limites de massa, alcance e forças. **Nenhuma dessas ações está implementada aqui.** Não há joints nem rigidbodies novos.

## Verificação

A partir da raiz, com um Godot 4.x instalado:

```bash
python3 Tests/validate_structure.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://Tests/SmokeTest.gd
godot --headless --path . --script res://Tests/CaineSmokeTest.gd
```

O arquivo `CaineSmokeTest.gd` envia comandos de teste apenas quando iniciado explicitamente. Não participa da cena principal.
