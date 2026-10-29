import assert from 'node:assert/strict';
import {observation,torques,projectedGravity,toGodotVector,toGodotMatrix} from '../policy_contract.js';
import {test} from 'node:test';
test('g1 official observation: 47 terms in exact order',()=>{
  const q=new Float32Array(19);q[3]=1;
  const v=new Float32Array(18);v[3]=2;v[6]=4;
  const obs=observation(q,v,[.5,.1,-.4],new Float32Array(12),0);
  assert.equal(obs.length,47);
  assert.equal(obs[0],.5); // gyro
  assert.equal(obs[5],-1); // projected down gravity
  assert.equal(obs[6],1); // command forward scaling
  assert.ok(Math.abs(obs[7]-.2)<1e-6); // command lateral scaling
  assert.ok(Math.abs(obs[8]+.1)<1e-6);
  assert.ok(Math.abs(obs[9]-.1)<1e-6); // - default joint pos
  assert.ok(Math.abs(obs[21]-.2)<1e-6); // joint speed
  assert.equal(obs[45],0);assert.equal(obs[46],1);
});
test('g1 default posture has zero position torque',()=>{
  const q=new Float32Array(19),v=new Float32Array(18);q[3]=1;
  const defaults=[-.1,0,0,.3,-.2,0,-.1,0,0,.3,-.2,0];
  for(let i=0;i<12;i++)q[7+i]=defaults[i];
  const result=torques(q,v,new Float32Array(12));
  for(const t of result)assert.ok(Math.abs(t)<1e-5);
});
test('rotation matrix basis conversion preserves det +1',()=>{
  assert.deepEqual(toGodotVector([1,2,3]),[1,3,-2]);
  assert.deepEqual(toGodotMatrix([1,0,0,0,1,0,0,0,1]),[1,0,0,0,1,0,0,0,1]);
});
test('contract rejects bad sensors and NaN',()=>{
  assert.throws(()=>observation([],[],[0,0,0],new Float32Array(12),0));
  const q=new Float32Array(19);q[0]=NaN;
  assert.throws(()=>observation(q,new Float32Array(18),[NaN,0,0],new Float32Array(12),0));
});
