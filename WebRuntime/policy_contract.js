/** Exact published Unitree G1 deploy_mujoco contract, 47 -> 12 LSTM @ 50 Hz. */
export const DEFAULT_ANGLES = Object.freeze([-.1,0,0,.3,-.2,0,-.1,0,0,.3,-.2,0]);
export const KP = Object.freeze([100,100,100,150,40,40,100,100,100,150,40,40]);
export const KD = Object.freeze([2,2,2,4,2,2,2,2,2,4,2,2]);
export const DT = .002;
export const ACTION_SCALE = .25;
export const DECIMATION = 10;
export function projectedGravity(q) {
  const [w,x,y,z]=q;
  return [2*(-z*x+w*y), -2*(z*y+w*x), 1-2*(w*w+z*z)];
}
export function observation(q,v,command,actions,steps) {
  if(q.length<19 || v.length<18 || command.length!==3 || actions.length!==12)
    throw Error('Contrato G1 invalido: qpos19, qvel18, command3, actions12 obrigatorios');
  const phase=((steps*DT)%.8)/.8;
  const o=[...Array.from(v.slice(3,6),x=>x*.25),
    ...projectedGravity(q.slice(3,7)),
    command[0]*2,command[1]*2,command[2]*.25,
    ...Array.from(q.slice(7,19),(x,i)=>x-DEFAULT_ANGLES[i]),
    ...Array.from(v.slice(6,18),x=>x*.05),
    ...actions,Math.sin(2*Math.PI*phase),Math.cos(2*Math.PI*phase)];
  if(o.length!==47 || !o.every(Number.isFinite))throw Error('Entrada neural NaN ou diferente de 47');
  return Float32Array.from(o);
}
export function torques(q,v,actions) {
  if(actions.length!==12 || q.length<19 || v.length<18)throw Error('Motor G1 incompativel');
  return Float64Array.from(actions, (a,i) => KP[i]*(DEFAULT_ANGLES[i]+ACTION_SCALE*a-q[7+i])-KD[i]*v[6+i]);
}
export function toGodotVector(p) {return [p[0],p[2],-p[1]];}
export function toGodotMatrix(m) {
  const C=[[1,0,0],[0,0,1],[0,-1,0]];
  const out=[];
  for(let r=0;r<3;r++)for(let c=0;c<3;c++){
    let v=0;
    for(let a=0;a<3;a++)for(let b=0;b<3;b++)v+=C[r][a]*m[a*3+b]*C[c][b];
    out.push(Math.round(v*1e6)/1e6);
  }
  return out;
}
