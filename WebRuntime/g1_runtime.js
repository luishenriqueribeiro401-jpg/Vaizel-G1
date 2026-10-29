/*
 * VAIZEL G1: native MuJoCo WebAssembly + official Unitree G1 12-DoF ONNX actor.
 * Physics: MuJoCo, not Godot. Godot only displays poses from MuJoCo.
 * Official policy exported without retraining by humanoidrobots.training.
 * See CREDITS_AND_LIMITS.md. MIT/BSD/Apache attribution remains with owners.
 */
import loadMuJoCo from '@mujoco/mujoco';
import * as ort from 'onnxruntime-web/wasm';
import {DT, observation, torques, toGodotVector, toGodotMatrix} from './policy_contract.js';

const BASE = './vaizel_assets/';
const ROOT_PATH = '/vaizel';

function getQ(array, start, size) {return Array.from(array.subarray(start,start+size));}
function finite(xs) {return xs.every(Number.isFinite);}

class G1Runtime {
  constructor() {
    this.stage='NAO_INICIADO'; this.error=''; this.ready=false;
    this.mj=null; this.model=null; this.data=null; this.session=null;
    this.rig={kind:'rig', geoms:[]}; this.packet={kind:'pose',parts:[]};
    this.steps=0; this._timer=0; this._busy=false; this._poseCounter=0;
    this.actions=new Float32Array(12);
    this.h=new Float32Array(64); this.c=new Float32Array(64);
    this.command=[.5,0,0]; this.fallen=false;
    this.lastPolicyAt=0; this.policiesPerSec=0;
  }
  statusJSON() {return JSON.stringify({stage:this.stage,error:this.error,ready:this.ready,
     steps:this.steps,policiesPerSec:this.policiesPerSec,
     baseHeight:this.data?Number(this.data.qpos[2]):0,
     command:this.command});}
  rigJSON() {return JSON.stringify(this.rig);}
  poseJSON() {return JSON.stringify(this.packet);}
  setVelocity(vx,vy,wz) {
    this.command=[Math.max(-.6,Math.min(1,Number(vx)||0)),
      Math.max(-.5,Math.min(.5,Number(vy)||0)),
      Math.max(-.8,Math.min(.8,Number(wz)||0))];
  }
  reset() {
    if(!this.ready)return;
    this.mj.mj_resetData(this.model,this.data);
    this.mj.mj_forward(this.model,this.data);
    this.actions.fill(0);this.h.fill(0);this.c.fill(0);
    this.steps=0;this.fallen=false;this._writePacket();
  }
  async start() {
    if(this.stage!=='NAO_INICIADO' && this.stage!=='ERRO')return;
    this.stage='BAIXANDO MODELO E REDE OFICIAIS'; this.error='';
    try {
      // These files are staged during a cloud build; nothing synthetic is substituted.
      const manifest=await this._readJSON(BASE+'manifest.json');
      if(manifest.model!=='unitree_g1_12dof') throw Error('Corpo incorreto: esperado unitree_g1_12dof');
      if(manifest.policySha256!=='64451da5909cc03a96fb8e435dc2495217292614466f7628718d60a6cab834fd') {
        throw Error('Hash esperada da politica nao corresponde ao manifesto');
      }
      this.stage='INICIALIZANDO MUJOCO WASM';
      this.mj=await loadMuJoCo({locateFile: (file)=>file.endsWith('.wasm') ? './mujoco_wasm.wasm' : file});
      const fs=this.mj.FS;
      // Files preserve official paths/mesh includes under a private VFS mount.
      fs.mkdir(ROOT_PATH);
      for(const name of manifest.files) {
        const path=ROOT_PATH+'/'+name;
        const segments=path.split('/');
        let prefix='';
        for(const dir of segments.slice(1,-1)) {
          prefix+='/'+dir;
          try {fs.mkdir(prefix);} catch(e) {if(!String(e).includes('File exists')) { /* Emscripten returns EEXIST */ }}
        }
        const response=await fetch(BASE+name);
        if(!response.ok) throw Error(`Arquivo do G1 nao encontrado: ${name} (${response.status})`);
        fs.writeFile(path,new Uint8Array(await response.arrayBuffer()));
      }
      this.model=this.mj.MjModel.mj_loadXML(ROOT_PATH+'/scene.xml');
      if(!this.model)throw Error('MuJoCo nao carregou o scene.xml oficial');
      this.data=new this.mj.MjData(this.model);
      if(Number(this.model.nq)!==19 || Number(this.model.nv)!==18 || Number(this.model.nu)!==12) {
        throw Error(`Incompativel com politica oficial: nq=${this.model.nq}, nv=${this.model.nv}, nu=${this.model.nu}`);
      }
      this.model.opt.timestep=DT;
      this.mj.mj_forward(this.model,this.data);
      this.stage='CARREGANDO LSTM OFICIAL ONNX';
      ort.env.wasm.numThreads=1;
      ort.env.wasm.simd=true;
      // Both ONNX Runtime JS and its WASM assets get copied beside the bundled script.
      ort.env.wasm.wasmPaths='./vaizel_wasm/';
      this.session=await ort.InferenceSession.create(BASE+'policy.onnx',{
        executionProviders:['wasm'],graphOptimizationLevel:'all'
      });
      for(const input of ['obs','h_in','c_in']) {
        if(!this.session.inputNames.includes(input))throw Error(`ONNX nao tem entrada ${input}`);
      }
      for(const output of ['actions','h_out','c_out']) {
        if(!this.session.outputNames.includes(output))throw Error(`ONNX nao tem saida ${output}`);
      }
      this.rig=this._buildRig();
      this.ready=true;this.stage='POLITICA OFICIAL ATIVA';
      this._writePacket();
      this._timer=window.setInterval(()=>this._stepBatch(),20);
    } catch(e) {
      this.stage='ERRO';this.error=String(e?.stack||e);
      console.error('Vaizel G1',e);
    }
  }
  _buildRig() {
    const m=this.model, mj=this.mj, list=[];
    for(let i=0;i<m.ngeom;i++) {
      const gt=Number(m.geom_type[i]);
      if(gt===mj.mjtGeom.mjGEOM_PLANE.value || Number(m.geom_bodyid[i])===0)continue;
      if(gt===mj.mjtGeom.mjGEOM_MESH.value && Number(m.geom_group[i])!==1)continue;
      const gp=i*3,rgba=i*4;
      const color=getQ(m.geom_rgba,rgba,4);
      let shape='box',size=[.1,.1,.1];
      if(gt===mj.mjtGeom.mjGEOM_BOX.value) {
        size=[m.geom_size[gp]*2,m.geom_size[gp+2]*2,m.geom_size[gp+1]*2];
      } else if(gt===mj.mjtGeom.mjGEOM_SPHERE.value) {
        shape='sphere';size=[m.geom_size[gp]];
      } else if(gt===mj.mjtGeom.mjGEOM_CAPSULE.value || gt===mj.mjtGeom.mjGEOM_CYLINDER.value) {
        shape=gt===mj.mjtGeom.mjGEOM_CAPSULE.value?'capsule':'cylinder';
        size=[m.geom_size[gp],m.geom_size[gp+1]];
      } else if(gt===mj.mjtGeom.mjGEOM_MESH.value) {
        // Use the body's actual MuJoCo mesh extents for the lightweight Godot viewer.
        // Collision/contact meshes stay exact inside MuJoCo.
        const mesh=Number(m.geom_dataid[i]);
        if(mesh<0)continue;
        const start=Number(m.mesh_vertadr[mesh])*3, cnt=Number(m.mesh_vertnum[mesh]);
        let lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
        for(let j=0;j<cnt;j++)for(let k=0;k<3;k++) {
          const v=m.mesh_vert[start+j*3+k];lo[k]=Math.min(lo[k],v);hi[k]=Math.max(hi[k],v);
        }
        size=[hi[0]-lo[0],hi[2]-lo[2],hi[1]-lo[1]].map(v=>Math.max(.016,v));
      } else continue;
      list.push({id:i,shape,size,rgba:color,is_mesh:gt===mj.mjtGeom.mjGEOM_MESH.value});
    }
    return {kind:'rig',geoms:list,robot:'Unitree G1 12-DoF'};
  }
  _observation() {
    return observation(this.data.qpos,this.data.qvel,this.command,this.actions,this.steps);
  }
  _applyMotors() {
    this.data.ctrl.set(torques(this.data.qpos,this.data.qvel,this.actions));
  }
  async _stepBatch() {
    if(!this.ready||this._busy)return;
    this._busy=true;
    try {
      for(let j=0;j<10;j++) {
        this._applyMotors();
        this.mj.mj_step(this.model,this.data);this.steps++;
      }
      const now=performance.now();
      const output=await this.session.run({
        obs:new ort.Tensor('float32',this._observation(),[1,47]),
        h_in:new ort.Tensor('float32',this.h,[1,1,64]),
        c_in:new ort.Tensor('float32',this.c,[1,1,64])
      });
      const a=output.actions.data;
      if(a.length!==12||!finite(a))throw Error('Acoes LSTM invalidas');
      this.actions=Float32Array.from(a);
      this.h=Float32Array.from(output.h_out.data);
      this.c=Float32Array.from(output.c_out.data);
      this.policiesPerSec=this.lastPolicyAt?1000/(now-this.lastPolicyAt):0;
      this.lastPolicyAt=now;
      this._writePacket();
    }catch(e){
      window.clearInterval(this._timer);this.ready=false;
      this.stage='ERRO';this.error=String(e?.stack||e);
      console.error('G1 physics step',e);
    }finally{this._busy=false;}
  }
  meshJSON(geomId) {
    // Transfer one official MuJoCo triangle mesh at a time to Godot renderer.
    // We never substitute a new physical body; contact remains inside MuJoCo.
    if(!this.ready || !Number.isInteger(geomId) || geomId<0 || geomId>=this.model.ngeom) return '';
    const m=this.model,mesh=Number(m.geom_dataid[geomId]);
    if(mesh<0)return '';
    const first=Number(m.mesh_vertadr[mesh]),count=Number(m.mesh_vertnum[mesh]);
    const ffirst=Number(m.mesh_faceadr[mesh]),fcount=Number(m.mesh_facenum[mesh]);
    if(count>18000||fcount>36000)return ''; // phone memory safeguard
    const vertices=[];
    for(let i=0;i<count;i++)vertices.push(...toGodotVector(m.mesh_vert.subarray((first+i)*3,(first+i+1)*3)));
    const faces=Array.from(m.mesh_face.subarray(ffirst*3,(ffirst+fcount)*3));
    return JSON.stringify({vertices,faces});
  }
  _writePacket() {
    const parts=[], d=this.data;
    for(const g of this.rig.geoms) {
      const i=g.id,p=toGodotVector(d.geom_xpos.subarray(i*3,i*3+3));
      const m=toGodotMatrix(d.geom_xmat.subarray(i*9,i*9+9));
      parts.push([i,...p,...m]);
    }
    this.packet={kind:'pose',step:this.steps,parts,
      pelvis:toGodotVector(d.qpos.subarray(0,3)),base_height:Number(d.qpos[2]),
      command:this.command};
  }
  async _readJSON(url) {
    const r=await fetch(url);if(!r.ok)throw Error(`HTTP ${r.status}: ${url}`);
    return r.json();
  }
}

const bridge=new G1Runtime();
window.VaizelG1Bridge=bridge;
bridge.start();
export default bridge;
