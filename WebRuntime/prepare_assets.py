#!/usr/bin/env python3
"""Download and hash-check original Unitree G1 assets for a browser Godot build.

Runs in GitHub Actions. It never fabricates/retrains the official policy.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen, Request
import xml.etree.ElementTree as ET

REF = '276801e46c5d433564f24658bac64f254b7d2d4b'
BASE = f'https://raw.githubusercontent.com/unitreerobotics/unitree_rl_gym/{REF}/resources/robots/g1_description/'
ONNX_URL = 'https://www.humanoidrobots.training/policies/unitree_g1_walk/policy.onnx'
ONNX_SHA = '64451da5909cc03a96fb8e435dc2495217292614466f7628718d60a6cab834fd'


def download(url: str) -> bytes:
    with urlopen(Request(url, headers={'User-Agent': 'Vaizel-Android-Godot/1.0'}), timeout=90) as r:
        return r.read()


def get_asset_refs(xml: bytes) -> tuple[list[str], list[str]]:
    root = ET.fromstring(xml)
    includes = [e.attrib['file'] for e in root.iter('include') if e.get('file')]
    compiler = root.find('compiler')
    mesh_dir = compiler.get('meshdir', '') if compiler is not None else ''
    tex_dir = compiler.get('texturedir', '') if compiler is not None else ''
    references=[]
    for asset in root.iter():
        if asset.tag not in ('mesh', 'texture', 'hfield', 'skin') or not asset.get('file'):
            continue
        prefix = tex_dir if asset.tag == 'texture' else mesh_dir
        file = Path(prefix) / asset.attrib['file']
        if file.is_absolute() or '..' in file.parts:
            raise ValueError('Unsafe MJCF file reference: ' + str(file))
        references.append(file.as_posix())
    return includes, references


def add_world_obstacles(scene: bytes) -> bytes:
    """Mirror Godot's three static blocks as real MuJoCo collision geoms."""
    s=scene.decode('utf-8')
    if '</worldbody>' not in s:
        raise ValueError('Official scene.xml missing worldbody')
    extra='''
  <!-- Mirrored Godot World.tscn collision cubes in robot-relative coordinates. -->
  <geom name="godot_block_a" type="box" pos="-1 4 1" size="1 1 1" rgba="0.57 0.62 0.67 1"/>
  <geom name="godot_block_b" type="box" pos="7 8 1" size="1 1 1" rgba="0.57 0.62 0.67 1"/>
  <geom name="godot_block_c" type="box" pos="3 14 1" size="1 1 1" rgba="0.57 0.62 0.67 1"/>
'''
    return s.replace('</worldbody>',extra+'</worldbody>').encode()


def build(root: Path):
    root.mkdir(parents=True, exist_ok=True)
    queue=['scene.xml']; done=set(); files=[]
    while queue:
        name=queue.pop(0)
        if name in done: continue
        if Path(name).is_absolute() or '..' in Path(name).parts:raise ValueError('Illegal path '+name)
        payload=download(BASE + name)
        if name.endswith('.xml'):
            new,assets=get_asset_refs(payload)
            parent=Path(name).parent
            queue.extend((parent/child).as_posix() for child in new)
            queue.extend((parent/child).as_posix() for child in assets)
            if name=='scene.xml':payload=add_world_obstacles(payload)
        path=root/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(payload)
        files.append(name)
        done.add(name)
        print(name,len(payload),'bytes')
    policy=download(ONNX_URL)
    actual=hashlib.sha256(policy).hexdigest()
    if actual!=ONNX_SHA:
        raise RuntimeError(f'Official ONNX hash mismatch, refusing to ship: {actual}')
    (root/'policy.onnx').write_bytes(policy)
    manifest={
        'model':'unitree_g1_12dof','policySha256':actual,
        'policySource':ONNX_URL,'unitreeSource':BASE,'unitreeCommit':REF,
        'files':files, 'modifiedScene':'3 Godot static boxes mirrored; base robot unmodified'
    }
    (root/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('Complete: ',len(files),'official model/mesh assets + hash-verified ONNX')

if __name__=='__main__':
    a=argparse.ArgumentParser()
    a.add_argument('--output',default='WebRuntime/public/vaizel_assets')
    args=a.parse_args()
    build(Path(args.output))
