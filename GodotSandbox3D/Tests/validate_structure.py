#!/usr/bin/env python3
"""Validação estática do projeto; não substitui parsing ou execução do Godot."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
failures = []
scenes = list((ROOT / 'Scenes').rglob('*.tscn'))
scripts = list((ROOT / 'Scripts').rglob('*.gd')) + list((ROOT / 'AI').rglob('*.gd'))


def check(condition, description):
    print(('PASS' if condition else 'FAIL') + ': ' + description)
    if not condition:
        failures.append(description)


check(len(scenes) == 6, 'Seis cenas: mundo, jogador, Caine, Vaizel e duas interfaces')
check(len(scripts) == 9, 'Nove scripts GDScript modulares')
check((ROOT / 'Shaders/TerrainGrid.gdshader').is_file(), 'Shader original preservado')
for path in scenes:
    content = path.read_text(encoding='utf-8')
    ext = re.findall(r'\[ext_resource type="[^"]+" path="res://([^"]+)" id="([^"]+)"\]', content)
    sub = re.findall(r'\[sub_resource type="[^"]+" id="([^"]+)"\]', content)
    for resource, rid in ext:
        check((ROOT / resource).is_file(), f'{path.name}: recurso {resource} existe')
    for ref in re.findall(r'ExtResource\("([^"]+)"\)', content):
        check(ref in {rid for _, rid in ext}, f'{path.name}: ExtResource {ref} definido')
    for ref in re.findall(r'SubResource\("([^"]+)"\)', content):
        check(ref in sub, f'{path.name}: SubResource {ref} definido')
    count_match = re.search(r'load_steps=(\d+)', content)
    check(bool(count_match) and int(count_match.group(1)) == len(ext) + len(sub) + 1,
          f'{path.name}: load_steps consistente')

world = (ROOT / 'Scenes/World.tscn').read_text(encoding='utf-8')
caine = (ROOT / 'Scenes/NPC/Caine.tscn').read_text(encoding='utf-8')
player = (ROOT / 'Scenes/Player.tscn').read_text(encoding='utf-8')
project = (ROOT / 'project.godot').read_text(encoding='utf-8')
api = (ROOT / 'AI/Agents/Caine/CaineAPI.gd').read_text(encoding='utf-8')
controller = (ROOT / 'Scripts/NPC/CaineController.gd').read_text(encoding='utf-8')
sensors = (ROOT / 'AI/Perception/CaineSensors.gd').read_text(encoding='utf-8')
check(world.count('[node name="Caine" parent="." instance=') == 1, 'Um único NPC Caine no mundo')
check(world.count('[node name="VaizelG1" parent="." instance=') == 1, 'Vaizel G1 oficial incluído exatamente uma vez')
check('groups=["world_blocks"]' in world and world.count('groups=["world_blocks"]') == 3,
      'Três blocos cadastrados como conhecidos no mundo')
check('groups=["terrain"]' in world, 'Terreno identificado para sensores')
check('collision_layer = 4' in caine and 'collision_mask = 11' in caine,
      'Caine em layer 3, colisão com mundo, jogador e interativos')
check('collision_layer = 2' in player and 'collision_mask = 5' in player,
      'Jogador colide com mundo e Caine sem mudar input FPS')
check('capsule' in caine.lower() and all(f'[node name="{part}"' in caine for part in
      ['Head', 'Torso', 'LeftArm', 'RightArm', 'LeftLeg', 'RightLeg']),
      'Humanoide com cápsula, cabeça, tronco, braços e pernas')
for node in ['PerceptionOrigin', 'ForwardSensor', 'GroundSensor', 'LeftHandAnchor',
             'RightHandAnchor', 'AIInterface', 'CaineSensors']:
    check(f'[node name="{node}"' in caine, f'Nó de Caine: {node}')
for method in ['set_move_input', 'set_facing_direction', 'request_jump', 'stop_movement',
               'clear_commands', 'get_observation', 'get_position', 'get_velocity',
               'is_grounded', 'get_nearby_objects']:
    check(f'func {method}(' in api, f'Comando/consulta CaineAPI: {method}')
check('move_command_timeout' in api and '_consume_move_input' in api,
      'Comando direcional expira sem renovação')
check('_physics_process(delta: float)' in controller and 'move_and_slide()' in controller,
      'Física de Caine via motor Godot')
check(not any(word in controller for word in ['Input.', 'randi(', 'randf(', 'get_vector(', 'get_action_strength(']),
      'Controlador de Caine não consulta entradas nem gera aleatoriedade')
check('force_raycast_update()' in sensors and 'intersect_ray(query)' in sensors,
      'Percepção com RayCast e linha de visão física')
check('known_objects' in sensors and 'detected_objects' in sensors,
      'Observações distinguem conhecimento do mundo de visão')
check('window/handheld/orientation=0' in project and 'rendering_method="gl_compatibility"' in project,
      'Landscape e Compatibility preservados')
for key in ['move_forward', 'move_backward', 'move_left', 'move_right', 'jump', 'pause']:
    check(f'\n{key}={{' in project, f'Input Map existente: {key}')
check('pointing/emulate_mouse_from_touch=false' in project, 'Sem duplicação mouse/toque')
for folder in ['Behaviors', 'Navigation', 'Config']:
    check((ROOT / f'AI/{folder}/.gitkeep').exists(), f'AI/{folder} preservado')
check((ROOT / 'Tests/CaineSmokeTest.gd').exists(), 'Testes físicos de Caine preparados')
print(f'\nVALIDAÇÃO ESTÁTICA: {len(failures)} erro(s) em {len(scenes)} cenas e {len(scripts)} scripts')
raise SystemExit(bool(failures))
