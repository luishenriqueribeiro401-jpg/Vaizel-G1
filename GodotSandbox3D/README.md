# Sandbox 3D — Fundação (Godot 4.x)

Projeto minimalista em GDScript, compatível com o renderizador **Compatibility** (OpenGL 3.3 / OpenGL ES 3.0). Não utiliza addons nem assets externos. Projetado para **Godot 4.3+**; o parsing e a execução pelo motor precisam ser confirmados em um editor Godot instalado.

## Abrir e jogar

1. Instale Godot 4.x e abra o **Project Manager**.
2. Selecione **Importar** e escolha `project.godot` nesta pasta.
3. Aguarde a importação e execute com **F6** na `Scenes/World.tscn` ou **F5** no projeto inteiro.
4. No computador, **W A S D** movem o jogador, **mouse** olha, **Espaço** pula; **Esc** libera o cursor/pausa o jogador; um **clique esquerdo** retoma.
5. No Android, o joystick fica no canto inferior esquerdo; a metade direita controla a câmera; **PULAR** fica no canto inferior direito. Os três comandos podem ser simultâneos.

No desktop com tela touchscreen, a interface aparece no primeiro toque real. A emulação de toque a partir do mouse está desativada para não duplicar eventos. Para testar toques em desktop, habilite temporariamente `Input Devices > Pointing > Emulate Touch From Mouse` no editor e restaure para `false` antes de exportar; o mouse emulado não reproduz multitouch real.

## NPC Caine — controle exclusivo pela API

A cena principal contém **um** NPC humanoide `Caine` em `(3, 0.06, 2)`, com corpo visível de cabeça, tronco, braços e pernas, cápsula de colisão, gravidade e capacidade motora. Não existe IA conectada. **Caine permanece imóvel na ausência de comandos** e jamais lê WASD, mouse ou joystick. A física continua funcionando sem comandos.

- Cena `Scenes/NPC/Caine.tscn`, física `Scripts/NPC/CaineController.gd`.
- Fachada pública `AI/Agents/Caine/CaineAPI.gd` em `/root/World/Caine/AIInterface`.
- Sensores `AI/Perception/CaineSensors.gd`: observações estruturadas (posição, velocidade, solo, visão, objetos conhecidos, objetos visíveis, obstáculos e contatos) a cada 0,2 s por padrão.
- Comandos: `set_move_input(Vector2)`, `set_facing_direction(Vector3)`, `request_jump()`, `stop_movement()`, `clear_commands()`.
- Consultas: `get_observation()`, `get_position()`, `get_velocity()`, `is_grounded()`, `get_nearby_objects()`.
- A intenção de caminhada **expira em 0,35 s** por padrão, evitando continuar andando quando o controlador externo silencia.
- Duas âncoras (`LeftHandAnchor` e `RightHandAnchor`) reservadas para manipulação futura. **Não é possível agarrar blocos nesta versão.**

Exemplo de chamada em script de teste **não adicionado automaticamente à cena**:

```gdscript
var api: CaineAPI = get_node("/root/World/Caine/AIInterface") as CaineAPI
api.set_facing_direction(Vector3(0, 0, -1))
api.set_move_input(Vector2(0, 1)) # frente por no máximo 0,35 s sem renovação
var state: Dictionary = api.get_observation()
print(JSON.stringify(state))
api.stop_movement()
```

As observações são atualizadas em intervalos, então consulte-as após um passo de física para obter a primeira amostra. Veja **`AI/README.md`** para descrição completa da API, convenções de eixos, unidades, limites de linha de visão e futura integração de IA externa ou manipulação de objetos.

## Estrutura

```text
res://
├── project.godot
├── Scenes/
│   ├── World.tscn
│   ├── Player.tscn
│   ├── NPC/Caine.tscn
│   └── UI/{MobileControls,DebugHUD}.tscn
├── Scripts/
│   ├── Player/PlayerController.gd
│   ├── World/WorldController.gd
│   ├── NPC/CaineController.gd
│   └── UI/{VirtualJoystick,MobileControls,DebugHUD}.gd
├── Shaders/TerrainGrid.gdshader
├── Materials/.gitkeep
├── Tests/{SmokeTest.gd,CaineSmokeTest.gd,validate_structure.py}
├── AI/
│   ├── README.md
│   ├── Agents/Caine/CaineAPI.gd
│   ├── Perception/CaineSensors.gd
│   └── {Behaviors,Navigation,Config}
└── README.md
```

## Especificações

- Chão: 200 × 200 m, topo em Y=0, material shader de grade 1 × 1 m no próprio plano (sem sobreposição de geometria).
- Jogador: corpo de cápsula de 1,80 m, olhos a 1,62 m, 5 m/s, gravidade de 9,81 m/s², pulo de ~1,2 m.
- Aceleração e frenagem: 18 e 24 m/s² por padrão; parâmetros exportados em `PlayerController.gd`.
- Colisões: camada 1 mundo, camada 2 jogador, camada 3 Caine, camada 4 interativos (reservada); máscara do jogador 5 (mundo e Caine), máscara de Caine 11 (mundo, jogador e interativos).
- HUD: coordenadas em metros X/Y/Z, FPS, velocidade horizontal em m/s e estado do solo, atualizado 5 vezes por segundo. Para ocultar, desmarque `show_on_start` na raiz da cena `DebugHUD.tscn`.
- Joystick: zona morta editável em `VirtualJoystick.gd`; sensibilidade de câmera móvel e suavização em `PlayerController.gd`.
- A cena principal liga sinais sem dependências de UI dentro do jogador.

## Exportação Android

1. No editor Godot, instale os **export templates** da mesma versão.
2. Configure **Java SDK** e **Android SDK** em Editor Settings e conecte um dispositivo Android com depuração USB.
3. Em Project > Export, adicione o preset Android, informe pacote único e configure assinatura para APK final.
4. Verifique no dispositivo real: dois dedos simultâneos para andar e olhar, terceiro dedo no botão PULAR, retirada de cada dedo, redimensionamento e taxa de quadros.
5. A orientação foi configurada para **landscape** e o renderizador para **Compatibility**.

Não há `export_presets.cfg` porque dependeria de dados do SDK/assinatura local. Android, Windows e Linux compartilham o mesmo projeto; são necessários os templates específicos para produzir instaladores/apks.

## Validação esperada

- Editor: abrir `project.godot`, conferir ausência de erros no painel Output/Debugger, usar F5.
- Física: caminhar até cada bloco, verificar que não atravessa; pular parado e próximo das paredes.
- Movimento: W, A, S, D, diagonal WA; câmera limitada em pitch; Esc e clique.
- Multitouch: caminhar e girar simultaneamente, e usar terceiro dedo para pular; retirar apenas o dedo do joystick deve parar o movimento.
- Teste automatizado sugerido se houver Godot instalado: `godot --headless --path . --editor --quit`, `godot --headless --path . --quit-after 120` e `godot --headless --path . --script res://Tests/SmokeTest.gd` e `godot --headless --path . --script res://Tests/CaineSmokeTest.gd`. A checagem estrutural independente é `python3 Tests/validate_structure.py`.

Consulte `AI/README.md` para a API de Caine, percepção atual e planejamento de expansões de IA. Não há inteligência artificial conectada.

## Estado da validação nesta entrega

O ambiente em que o projeto foi gerado não tinha binário do Godot nem dispositivo Android conectado. Portanto apenas a validação estrutural em Python foi efetivamente executada; os testes `SmokeTest.gd` e `CaineSmokeTest.gd` estão preparados, mas **não foram executados**. A inicialização gráfica, a compilação dos scripts pelo Godot e o multitouch físico devem ser confirmados com as instruções acima.
