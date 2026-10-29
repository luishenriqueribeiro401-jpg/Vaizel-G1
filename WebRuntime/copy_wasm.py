"""Stage original official engine and ORT WASM needed by Vite output."""
from pathlib import Path
import shutil

root=Path(__file__).resolve().parent
modules=root/'node_modules'
output=root/'dist'
if not output.exists():raise SystemExit('Run npm run build first')
mj=list((modules/'@mujoco/mujoco').rglob('*.wasm'))
if not mj:raise SystemExit('MuJoCo WASM not found in package @mujoco/mujoco')
# Single-thread only. The WASM in package root/dist should be the ST build.
st=[p for p in mj if not any(t in str(p).lower() for t in ('/mt/','thread','pthread'))]
if not st:raise SystemExit('No single-threaded MuJoCo WASM')
shutil.copy2(st[0],output/'mujoco_wasm.wasm')
wasm_dir=output/'vaizel_wasm';wasm_dir.mkdir(exist_ok=True)
for f in (modules/'onnxruntime-web/dist').glob('ort-wasm-*'):
    if f.suffix in ('.wasm','.mjs'):
        shutil.copy2(f,wasm_dir/f.name)
if not any(wasm_dir.glob('*.wasm')):raise SystemExit('ONNX Runtime WASM missing')
print('MuJoCo:',st[0], 'and ORT files',len(list(wasm_dir.iterdir())))
