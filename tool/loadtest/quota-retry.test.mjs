// Executes the web functions from their actual source, with Firebase I/O
// injected. No duplicated queue or retry implementation, no network.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {homedir} from 'node:os';

const root=join(homedir(),'Desktop','REGİPASS','js/modules/events');
function load(file, dependencies, names) {
  const source=readFileSync(join(root,file),'utf8')
    .replace(/^import\s+[\s\S]*?;\s*$/gm,'')
    .replace(/^export\s*\{[^}]*\};?\s*$/gm,'')
    .replace(/\bexport\s+(?=(async\s+)?(function|class|const|let))/g,'');
  return new Function(...Object.keys(dependencies),`${source}\nreturn {${names}};`)(...Object.values(dependencies));
}
const denied=()=>Object.assign(new Error('real rule rejection'),{code:'permission-denied'});
const snap=data=>({exists:()=>data!==null,data:()=>data});
function quota({after=4,error=denied(),existing=false,readError=null}={}) {
  const writes=[];
  const api=load('quota-shards.js',{
    db:{},doc:(_db,...parts)=>({path:parts.join('/')}),regLog:{},
    buildShardPlan:()=>[],resolveShardCount:()=>1,
    getDocFromServer:async()=>{if(readError)throw readError;return snap(after===null?null:{count:after});},
    runTransaction:async(_db,body)=>{
      const result=await body({
        get:async ref=>ref.path==='registration'?snap(existing?{quotaShard:0}:null):snap({count:3,capacity:10}),
        set:(...args)=>writes.push(['set',...args]),update:(...args)=>writes.push(['update',...args]),
      });
      if(!existing)throw error;
      return result;
    },
  },'claimSpecificShard');
  return {...api,writes};
}

test('counter moved during rejected commit: retry as contention',async()=>{
  const q=quota();
  await assert.rejects(q.claimSpecificShard('event',0,{path:'registration'},()=>({studentId:'s'})),{code:'aborted'});
});
test('unchanged or missing counter: preserve the actual permission denial',async()=>{
  for(const after of [3,null]) {
    const error=denied(),q=quota({after,error});
    await assert.rejects(q.claimSpecificShard('event',0,{path:'registration'},()=>({})),e=>e===error);
  }
});
test('failed fresh read cannot turn a denial into success',async()=>{
  const error=Object.assign(new Error('offline'),{code:'unavailable'}),q=quota({readError:error});
  await assert.rejects(q.claimSpecificShard('event',0,{path:'registration'},()=>({})),e=>e===error);
});
test('existing registration does not increment quota twice',async()=>{
  const q=quota({existing:true});
  const result=await q.claimSpecificShard('event',0,{path:'registration'},()=>({}));
  assert.equal(result.alreadyRegistered,true);assert.equal(q.writes.length,0);
});

test('last free seat among 60 shards is found instead of exhausting retries',async()=>{
  const counts=Array.from({length:60},(_,i)=>i===59?4:5);
  const fixedMath=Object.assign(Object.create(Math),{random:()=>0});
  let saved=false;
  const q=load('quota-shards.js',{
    db:{},doc:(_db,...parts)=>({path:parts.join('/')}),collection:()=>({}),
    regLog:{},buildShardPlan:()=>[],resolveShardCount:()=>60,Math:fixedMath,
    getDocs:async()=>({size:60,docs:counts.map((count,i)=>({id:String(i),data:()=>({count,capacity:5})}))}),
    runTransaction:async(_db,body)=>body({
      get:async ref=>ref.path==='registration'?snap(null):snap({count:counts[Number(ref.path.split('/').at(-1))],capacity:5}),
      set:()=>{saved=true;},update:(ref,data)=>{counts[Number(ref.path.split('/').at(-1))]=data.count;},
    }),
  },'claimQuotaSlot');
  const result=await q.claimQuotaSlot({eventId:'e',shardCount:60,registrationRef:{path:'registration'},buildPayload:()=>({})});
  assert.equal(result.claimed,true);assert.equal(result.shardIndex,59);
  assert.equal(saved,true);assert.equal(counts.reduce((a,b)=>a+b),300);
});

const queue=()=>load('registration-queue.js',{
  regLog:{error:()=>{}},setTimeout:fn=>{fn();return 0;},
},'submitRegistration,resolveAdmissionWindowMs');
test('same student double click shares one in-flight registration',async()=>{
  const q=queue();let count=0,release;
  const run=()=>{count++;return new Promise(resolve=>{release=resolve;});};
  const a=q.submitRegistration({eventId:'e',event:{admissionWindowMs:0},run});
  const b=q.submitRegistration({eventId:'e',event:{admissionWindowMs:0},run});
  assert.equal(count,1);release('saved');
  assert.deepEqual(await Promise.all([a,b]),['saved','saved']);
});
test('queue retries transient contention and shows waiting; permission denial is terminal',async()=>{
  const q=queue();let calls=0,queued=0,retried=0;
  assert.equal(await q.submitRegistration({eventId:'e',event:{quota:300,quotaShardCount:16},
    onQueued:()=>queued++,onRetry:()=>retried++,run:async()=>{
      if(++calls<3)throw Object.assign(new Error('contended'),{code:'aborted'});return 'saved';
    }}),'saved');
  assert.equal(queued,1);assert.equal(retried,2);assert.equal(calls,3);
  calls=0;
  await assert.rejects(q.submitRegistration({eventId:'e',run:async()=>{calls++;throw denied();}}),{code:'permission-denied'});
  assert.equal(calls,1);
});
