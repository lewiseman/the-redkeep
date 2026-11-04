// Loopback integration fixture: real, unchanged Companion protocol and jobs,
// synthetic model outputs. No user trust, writing, model cache, or data is read.
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { EventEmitter } = require('node:events');
const source = process.env.JOURNAL_COMPANION_SOURCE || path.resolve(__dirname,'../../../../Journal/desktop');
const { Vault } = require(path.join(source,'src/vault.cjs'));
const { Jobs } = require(path.join(source,'src/jobs.cjs'));
const { Voice } = require(path.join(source,'src/voice.cjs'));
const { Talk } = require(path.join(source,'src/talk.cjs'));
const { DeviceService, deviceId } = require(path.join(source,'src/device-service.cjs'));
class SyntheticRuntime extends EventEmitter {
  busy = false;
  async cancelGeneration() {}
  async generate(raw, {operation,onToken} = {}) {
    const input=JSON.parse(raw);
    let text;
    if(operation==='answer-diary-question') text=JSON.stringify({status:'answered',answer:'You planted a garden.',citations:['s0']});
    else text=input.action==='draft'?'I planted a garden.':'What did you notice in the garden?';
    onToken?.(text);return {ok:true,text};
  }
}
class SyntheticSpeech extends EventEmitter {
  model={id:'synthetic-speech'};
  capability(){return {id:'transcription',implemented:true,status:'ready',live:1,sampleRate:16000,channels:1,format:'s16le',languages:['en']};}
  release(){}
  async open(){let finish;const done=new Promise(resolve=>finish=resolve);return {write(){},end(){finish();},destroy(){finish();},async *[Symbol.asyncIterator](){await done;yield {id:0,text:'I planted a garden.',startMs:0,endMs:100};}};}
}
class SyntheticVision extends EventEmitter {
  model={id:'synthetic-vision-v1'};
  images=new Map();
  capability(){return {id:'vision',implemented:true,status:'ready',model:this.model.id,photoContract:2,operations:['diary-photo-questions']};}
  async store(device,id,bytes){this.images.set(`${device}:${id}`,bytes);return {type:'png',width:32,height:24,bytes:bytes.length};}
  async load(device,id){return this.images.get(`${device}:${id}`);}
  async sweep(){}
  async run(){return {ok:true,text:JSON.stringify({clear:true,observations:'An orange square.',moment:['What made you keep this photo?'],feeling:['How did you feel?'],little:['What was outside the frame?']})};}
}
(async()=>{
  const directory=await fs.mkdtemp(path.join(os.tmpdir(),'redkeep-media-peer-'));
  const vault=new Vault(directory,{isEncryptionAvailable:()=>true,encryptString:s=>Buffer.from(s),decryptString:b=>b.toString()});await vault.initialize();
  const key=crypto.generateKeyPairSync('ed25519').privateKey.export({format:'jwk'}),pub=Buffer.from(key.x,'base64url').toString('base64'),device=deviceId(pub);
  await vault.change(v=>{v.devices[device]={id:device,name:'Synthetic Redkeep',publicKey:pub};});
  const runtime=new SyntheticRuntime();
  const library={assignment:'synthetic-writing-v1',capability:()=>({id:'text',implemented:true,status:'ready',historyContract:1,operations:['diary.conversation','answer-diary-question']})};
  const jobs=new Jobs(vault,runtime,library);jobs.vision=new SyntheticVision();await jobs.initialize();
  const speech=new SyntheticSpeech(),voice=new Voice(vault,speech);await voice.initialize();voice.talk=new Talk(vault,speech,runtime);
  const service=new DeviceService(vault,library,jobs,{voice,port:0,host:'127.0.0.1',advertise:false});await service.initialize();await service.start();
  process.stdout.write(JSON.stringify({id:service.identity.id,name:'Synthetic media peer',pin:service.pin,endpoint:`https://127.0.0.1:${service.port}`,seed:Buffer.from(key.d,'base64url').toString('base64'),publicKey:pub,deviceId:device,enabled:true})+'\n');
  let stopping=false;
  async function stop(){if(stopping)return;stopping=true;await service.stop();await voice.shutdown();await jobs.shutdown();await fs.rm(directory,{recursive:true,force:true});process.exit(0);}
  process.stdin.on('data',d=>{if(d.toString().trim()==='quit')stop();});process.on('SIGTERM',stop);
})().catch(e=>{console.error(e.stack);process.exit(1);});
