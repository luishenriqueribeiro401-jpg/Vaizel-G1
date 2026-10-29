import unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from prepare_assets import get_asset_refs, add_world_obstacles, ONNX_SHA, REF

class TestOfficialAssetPipeline(unittest.TestCase):
    def test_mjcf_files_and_meshdir(self):
        a,b=get_asset_refs(b'<mujoco><compiler meshdir="meshes"/><include file="g1_12dof.xml"/><asset><mesh name="limb" file="limb.stl"/></asset></mujoco>')
        self.assertEqual(a,['g1_12dof.xml'])
        self.assertEqual(b,['meshes/limb.stl'])
    def test_original_scene_adds_only_blocks(self):
        txt=b'<mujoco><worldbody><geom type="plane"/></worldbody></mujoco>'
        x=add_world_obstacles(txt)
        self.assertIn(b'godot_block_a',x)
        self.assertIn(b'godot_block_b',x)
        self.assertIn(b'godot_block_c',x)
        self.assertIn(b'geom type="plane"',x)
    def test_hash_and_commit_are_pinned(self):
        self.assertEqual(len(ONNX_SHA),64)
        self.assertEqual(len(REF),40)
if __name__=='__main__':unittest.main()
