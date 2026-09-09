/** Local only, authenticated Firestore client load; no production credentials.
 * node tool/loadtest/14-qr-concurrency.mjs
 * LOADTEST_RULES selects a rules snapshot; QR_COUNTS/QR_MODES select scenarios.
 * Flutter registration is a JS port of RegistrationService, NOT a device test.
 * Web quota/queue functions are loaded from the local web source with imports
 * injected; each student gets independent module state and Firebase context.
 */
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import * as sdk from 'firebase/firestore';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, resolve } from 'node:path';
import { homedir, cpus, totalmem } from 'node:os';
import { performance } from 'node:perf_hooks';

const projectId = 'demo-regipass-qr-load';
const port = 9091;
const rulesPath = resolve(process.env.LOADTEST_RULES || 'tool/loadtest/firestore.rules');
const rules = readFileSync(rulesPath, 'utf8');
const webRoot = join(homedir(), 'Desktop', 'REGİPASS', 'js/modules/events');
const counts = (process.env.QR_COUNTS || '25,100,250,500,1000').split(',').map(Number);
const modes = (process.env.QR_MODES || 'door,session,unbounded').split(',');
const validModes = new Set(['door','session','unbounded','mobile','web','mixed','mobile-overflow','web-overflow','mixed-overflow','closed','stale-door','duplicate-door','duplicate-session']);
if (counts.some(n=>!Number.isInteger(n)||n<1||n>2000) || modes.some(m=>!validModes.has(m))) throw new Error('Invalid QR_COUNTS or QR_MODES');
const out = resolve('tool/loadtest/logs');
mkdirSync(out, {recursive: true});
const output = join(out, `qr-${Date.now()}.json`);
const sha = text => createHash('sha256').update(text).digest('hex');
const report = {startedAt: new Date().toISOString(), projectId, port, rulesPath,
  rulesSha256: sha(rules), cpu: cpus()[0]?.model, logicalCpus: cpus().length,
  ramGB: totalmem()/2**30, sdk: JSON.parse(readFileSync('tool/loadtest/node_modules/firebase/package.json')).version,
  caveat: 'Local emulator, synthetic authenticated clients; no camera, Auth/SMS, GPS, hosting, mobile runtime or production capacity measurement.', scenarios: []};
const persist = () => writeFileSync(output, JSON.stringify(report, null, 2));
const deadline = setTimeout(()=>{report.timedOutAt=new Date().toISOString();persist();console.error(`Test exceeded 15 minutes: ${output}`);process.exit(2);},900000);
deadline.unref();
report.mobileSources = Object.fromEntries(['lib/services/registration_service.dart','lib/services/event_repository.dart','lib/domain/registration_capacity.dart'].map(file=>[file,sha(readFileSync(file,'utf8'))]));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const noopLog = new Proxy({}, {get: () => () => {}});
function factory(file, dependencies, exports) {
  const source = readFileSync(join(webRoot, file), 'utf8');
  (report.webSources ??= {})[file] = sha(source);
  const body = source.replace(/^import\s+[\s\S]*?;\s*$/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*$/gm, '').replace(/\bexport\s+(?=(async\s+)?(function|class|const|let))/g, '');
  return new Function(...dependencies, `${body}\nreturn {${exports.join(',')}};`);
}
const plan = factory('quota-plan.js', [], ['buildShardPlan','resolveShardCount'])();
const quotaFactory = factory('quota-shards.js', ['collection','doc','getDocFromServer','getDocs','runTransaction','writeBatch','db','regLog','buildShardPlan','resolveShardCount'], ['claimQuotaSlot']);
const queueFactory = factory('registration-queue.js', ['regLog'], ['submitRegistration']);
function webClient(db) {
  const quota = quotaFactory(sdk.collection,sdk.doc,sdk.getDocFromServer,sdk.getDocs,sdk.runTransaction,sdk.writeBatch,db,noopLog,plan.buildShardPlan,plan.resolveShardCount);
  return {...quota,...queueFactory(noopLog)};
}
const shardCount = q => Math.min(q, q <= 50 ? 4 : q <= 200 ? 8 : q <= 1000 ? 16 : 32);
function payload(eventId, uid, shard) {
  return {registrationId:`${eventId}_${uid}`,eventId,studentId:uid,clubId:'load_club',
    eventTitle:'Synthetic QR load',clubName:'Synthetic club',eventImageUrl:'',deadlineAtMs:Date.now()+86400000,
    studentEmail:`${uid}@example.invalid`,studentName:'Synthetic Student',studentFirstName:'Synthetic',studentLastName:'Student',
    studentPhone:'',studentCity:'',studentUniversity:'Load University',studentDepartment:'Test',studentClassYear:'1',
    registeredAtMs:Date.now(),createdAt:sdk.serverTimestamp(),updatedAt:sdk.serverTimestamp(),
    ...(shard == null ? {} : {quotaShard:shard})};
}
async function mobileRegister(db, event, uid) {
  let hash=0;
  for (const char of uid) hash=(hash*31+char.charCodeAt(0))&0x7fffffff;
  const start=hash%event.quotaShardCount;
  if(event.quota>=40) await sleep(Math.floor(Math.random()*Math.min(8000,Math.max(2000,Math.ceil(event.quota/event.quotaShardCount)*1200))));
  const live=(await sdk.getDocFromServer(sdk.doc(db,`events/${event.id}`))).data();
  if(!live || live.registrationClosed || live.entryOpen || live.currentSession>0 || live.deadlineAtMs<Date.now()) return 'closed';
  for(let round=0;round<8;round++) {
    let full=0,contended=false;
    for(let step=0;step<event.quotaShardCount;step++) {
      const s=(start+step)%event.quotaShardCount;
      const shard=sdk.doc(db,`events/${event.id}/quota_shards/${s}`);
      let attemptedCount=null;
      try {
        const outcome=await sdk.runTransaction(db,async tx=>{
          const ref=sdk.doc(db,`event_registrations/${event.id}_${uid}`);
          const a=await tx.get(shard),b=await tx.get(ref);
          if(b.exists()) return 'already';
          if(!a.exists() || a.data().count>=a.data().capacity) return 'full';
          attemptedCount=a.data().count;
          tx.set(ref,payload(event.id,uid,s));tx.update(shard,{count:a.data().count+1});
          return 'ok';
        },{maxAttempts:1});
        if(outcome==='full'){full++;continue;} return outcome;
      } catch(e) {
        if(e.code==='permission-denied' && attemptedCount!==null) {
          const latest=await sdk.getDocFromServer(shard);
          if(latest.exists() && Number.isInteger(latest.data().count) && latest.data().count!==attemptedCount) e={code:'aborted'};
        }
        if(e.code==='permission-denied') throw e;
        if(!['aborted','failed-precondition','unavailable','deadline-exceeded','resource-exhausted','internal','cancelled'].includes(e.code)) throw e;
        contended=true;break;
      }
    }
    if(!contended && full===event.quotaShardCount) return 'quota-full';
    if(round<7) await sleep(Math.floor(Math.random()*(Math.min(6000,150*2**round)+1)));
  }
  const shards=await sdk.getDocs(sdk.collection(db,`events/${event.id}/quota_shards`));
  return shards.size===event.quotaShardCount && shards.docs.every(d=>d.data().count>=d.data().capacity) ? 'quota-full':'retry-exhausted';
}
const env = await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port,rules}});
sdk.setLogLevel('silent');
let clients=[];
try {
  for(const n of counts) {
    clients=Array.from({length:n},(_,i)=>{const uid=`load_${i.toString(36).padStart(6,'0')}`;
      const db=env.authenticatedContext(uid).firestore();return {uid,db,web:webClient(db)};});
    for(const mode of modes) {
      const quotaMode=mode.startsWith('mobile')||mode.startsWith('web')||mode.startsWith('mixed');
      const quota=quotaMode ? (mode.endsWith('overflow')?Math.max(1,Math.floor(n/2)):n):0;
      const shards=quotaMode ? (mode.startsWith('web')?plan.resolveShardCount(quota):shardCount(quota)):0;
      const eventId=`qr_${mode}_${n}_${Date.now()}`;
      const event={id:eventId,clubId:'load_club',title:'Synthetic QR load',feeType:'free',hiddenGlobally:false,
        targetScope:'public',registrationClosed:['door','session','closed','duplicate-door','duplicate-session'].includes(mode),
        entryOpen:['door','closed','stale-door','duplicate-door'].includes(mode),currentSession:['session','duplicate-session'].includes(mode)?1:0,
        sessionCount:3,checkinMode:'checkin_attendance',allowSessionWithoutCheckin:false,sessionsCompleted:false,
        quota,quotaShardCount:shards,deadlineAtMs:Date.now()+86400000};
      await env.withSecurityRulesDisabled(async ctx=>{
        const db=ctx.firestore();await sdk.setDoc(sdk.doc(db,`events/${eventId}`),event);
        const records=[];
        for(let s=0;s<shards;s++) records.push([`events/${eventId}/quota_shards/${s}`,{count:0,capacity:Math.floor(quota/shards)+(s<quota%shards?1:0)}]);
        if(['door','session','duplicate-session','duplicate-door'].includes(mode)) for(const {uid} of clients)
          records.push([`event_registrations/${eventId}_${uid}`,{...payload(eventId,uid),...(['session','duplicate-session'].includes(mode)?{checkedInAtMs:Date.now()-5000,checkedInAt:sdk.Timestamp.now(),checkedInVia:'self-qr'}:{})}]);
        for(let i=0;i<records.length;i+=400){const batch=sdk.writeBatch(db);for(const [path,data] of records.slice(i,i+400))batch.set(sdk.doc(db,path),data);await batch.commit();}
      });
      // Warm each channel outside timing. Server reads, not cached snapshots.
      for(let i=0;i<clients.length;i+=50) await Promise.all(clients.slice(i,i+50).map(c=>sdk.getDocFromServer(sdk.doc(c.db,`events/${eventId}`))));
      console.log(`START ${mode} N=${n} quota=${quota} shards=${shards}`);
      const started=performance.now();
      const results=await Promise.all(clients.map(async c=>{
        const t=performance.now();let status='ok',message;
        try {
          await sdk.getDocFromServer(sdk.doc(c.db,`events/${eventId}`));
          const ref=sdk.doc(c.db,`event_registrations/${eventId}_${c.uid}`);
          const reg=await sdk.getDocFromServer(ref);
          if(mode.startsWith('duplicate-')) {
            const data=mode==='duplicate-door'
              ? {checkedInAtMs:Date.now(),checkedInAt:sdk.serverTimestamp(),checkedInVia:'self-qr',updatedAt:sdk.serverTimestamp()}
              : {checkedInAtMs:reg.data().checkedInAtMs,checkedInAt:sdk.serverTimestamp(),sessionsAttended:1,lastAttendedSession:1,lastSessionCheckInAtMs:Date.now(),updatedAt:sdk.serverTimestamp()};
            const pair=await Promise.allSettled([sdk.updateDoc(ref,data),sdk.updateDoc(ref,data)]);
            status=pair.filter(r=>r.status==='fulfilled').length===1 && pair.some(r=>r.reason?.code==='permission-denied') ? 'one-ok-one-denied':'duplicate-check-failed';
          }
          else if(mode==='door') await sdk.updateDoc(ref,{checkedInAtMs:Date.now(),checkedInAt:sdk.serverTimestamp(),checkedInVia:'self-qr',updatedAt:sdk.serverTimestamp()});
          else if(mode==='session') await sdk.updateDoc(ref,{checkedInAtMs:reg.data().checkedInAtMs,checkedInAt:sdk.serverTimestamp(),sessionsAttended:(reg.data().sessionsAttended||0)+1,lastAttendedSession:1,lastSessionCheckInAtMs:Date.now(),updatedAt:sdk.serverTimestamp()});
          else if(mode.startsWith('mobile') || (mode.startsWith('mixed') && parseInt(c.uid.slice(5),36)%2===0)) status=await mobileRegister(c.db,event,c.uid);
          else if(mode.startsWith('web') || mode.startsWith('mixed')) await c.web.submitRegistration({eventId,event,run:()=>c.web.claimQuotaSlot({eventId,shardCount:shards,registrationRef:ref,buildPayload:s=>payload(eventId,c.uid,s)})});
          else await sdk.setDoc(ref,payload(eventId,c.uid),{merge:true});
        } catch(e){status=e.reason==='full'?'quota-full':e.code||e.name;message=e.message?.slice(0,300);}
        return {uid:c.uid,status,ms:Math.round(performance.now()-t),...(message?{message}:{})};
      }));
      const elapsedMs=Math.round(performance.now()-started);
      const statuses={};for(const r of results)statuses[r.status]=(statuses[r.status]||0)+1;
      const times=results.map(r=>r.ms).sort((a,b)=>a-b);
      const pct=p=>times[Math.min(times.length-1,Math.ceil(p*times.length)-1)];
      let integrity;
      await env.withSecurityRulesDisabled(async ctx=>{
        const db=ctx.firestore();const regs=await sdk.getDocs(sdk.query(sdk.collection(db,'event_registrations'),sdk.where('eventId','==',eventId)));
        const ss=await sdk.getDocs(sdk.collection(db,`events/${eventId}/quota_shards`));
        const used=ss.docs.reduce((sum,d)=>sum+d.data().count,0);
        integrity={stored:regs.size,checkedIn:regs.docs.filter(d=>d.data().checkedInAtMs>0).length,
          session1:regs.docs.filter(d=>d.data().sessionsAttended===1&&d.data().lastAttendedSession===1).length,
          shardUsed:used,quotaOverflow:quotaMode?regs.size>quota:false,
          countersMatch:quotaMode?used===regs.size:null,overfullShards:ss.docs.filter(d=>d.data().count>d.data().capacity).length};
      });
      const row={mode,n,quota,shards,elapsedMs,statuses,p50Ms:pct(.5),p95Ms:pct(.95),p99Ms:pct(.99),maxMs:pct(1),integrity,results};
      report.scenarios.push(row);persist();
      console.log(JSON.stringify({...row,results:undefined}));
    }
    await Promise.all(clients.map(c=>c.db.terminate()));clients=[];
  }
  report.completedAt=new Date().toISOString();persist();console.log(`REPORT ${output}`);
} finally { clearTimeout(deadline); await env.cleanup(); }
