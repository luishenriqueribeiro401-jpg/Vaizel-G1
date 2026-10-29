# Relatório de validação — expansão Caine

## Verificações realmente executadas

1. `python3 Tests/validate_structure.py` — **PASSOU**. Resultado: 0 erros, 5 cenas e 8 scripts GDScript. O verificador confere os caminhos dos recursos, identificadores de cenas, dependências, entrada existente, máscaras de colisão e estrutura de Caine/API/sensores.
2. Busca por executável `godot`/`godot4` no terminal — **não encontrado**. A tentativa de baixar o motor esbarrou em restrição de acesso à rede do ambiente.
3. Integridade do pacote ZIP — verificada separadamente na criação da entrega.

## Não executados (falta do executável Godot e hardware Android)

- Compilação/parse de GDScript com o Godot; importação da cena e execução da janela do jogo.
- `Tests/SmokeTest.gd`: FPS, terreno, colisões, joystick e eventos touchscreen simulados.
- `Tests/CaineSmokeTest.gd`: spawn único, corpo, gravidade, movimento por API, parada e expiração, giro, pulo único, blocos, colisão com jogador, serialização JSON, linhas de visão e oclusão.
- Multitouch real e desempenho em Android; exportação Windows/Linux/Android.

**Observação:** validação estática não substitui teste de física e compilação pelo Godot. Não se declara que os testes acima passaram.

## Comandos para validação com Godot 4.3+

A partir da pasta que contém `project.godot`:

```sh
python3 Tests/validate_structure.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://Tests/SmokeTest.gd
godot --headless --path . --script res://Tests/CaineSmokeTest.gd
```

Depois abrir `World.tscn` no editor e validar visualmente colisões, altura dos membros, campo de visão e controle simultâneo por toque no dispositivo.
