const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const crypto=require('node:crypto');
const {Updates,compareVersions,hashFile}=require('./updates');
const {createUpdateSettings}=require('./update-settings');
const {installLatestUpdate}=require('./update-flow');
const fixtureRoot=path.resolve(__dirname,'../tmp/update-tests');
async function fixture(t){const root=path.join(fixtureRoot,crypto.randomUUID());await fs.mkdir(root,{recursive:true});t.after(()=>fs.rm(root,{recursive:true,force:true}));return root;}
const encryption={isEncryptionAvailable:()=>true,encryptString:value=>Buffer.from('encrypted:'+value),decryptString:bytes=>bytes.toString().slice(10)};
test('public settings preserve opt-ins and discard legacy encrypted tokens without decrypting',async t=>{
 const root=await fixture(t),store=createUpdateSettings(root);
 await fs.writeFile(path.join(root,'update-settings.json'),JSON.stringify({checkOnStartup:true,autoDownload:true,autoInstall:false,encryptedToken:'old-token'}));
 assert.equal((await store.load()).checkOnStartup,true);
 assert.equal((await fs.readFile(path.join(root,'update-settings.json'),'utf8')).includes('old-token'),false);
 await assert.rejects(store.save({checkOnStartup:false,autoDownload:false,autoInstall:true}),/requires/);
 await store.save({checkOnStartup:false,autoDownload:false,autoInstall:false,token:'ignored'});
 assert.equal((await fs.readFile(path.join(root,'update-settings.json'),'utf8')).includes('ignored'),false);
});
test('stable versions compare numerically and reject prerelease strings',()=>{
 assert.equal(compareVersions('1.10.0','1.9.0'),1);assert.equal(compareVersions('1.0.0','1.0.0'),0);assert.equal(compareVersions('1.0.0','2.0.0'),-1);assert.throws(()=>compareVersions('1.0.1-beta','1.0.0'));
});
function release(version='1.4.0'){return {tag_name:'v'+version,draft:false,prerelease:false,assets:[{name:`InstallStreet-${version}-x64.msi`,id:11},{name:'SHA256SUMS.txt',id:12}]};}
test('checks public releases through fixed GitHub endpoints and rejects drafts or missing payloads',async t=>{
 const calls=[];let value=release();
 const updater=new Updates({version:'1.3.0',root:await fixture(t),settings:{token:()=>{throw Error('Legacy token must not be accessed');}},request:async(url,options)=>{calls.push({url,options});return Response.json(value);}});
 assert.equal((await updater.check()).phase,'available');assert.equal(calls[0].url,'https://api.github.com/repos/glitchFling/InstallStreet/releases/latest');assert.equal(calls[0].options.headers.Authorization,undefined);
 value={...release(),draft:true};await assert.rejects(updater.check(),/stable/);
 value={...release(),assets:[]};await assert.rejects(updater.check(),/missing/);
 value=release('1.2.0');assert.equal((await updater.check()).phase,'current');assert.equal(updater.downloaded,null);
});
test('download validates checksum before allowing installation and removes mismatched payloads',async t=>{
 const bytes=Buffer.from('fixture MSI payload'),hash=crypto.createHash('sha256').update(bytes).digest('hex');let correct=true;
 const updater=new Updates({version:'1.3.0',root:await fixture(t),settings:{token:()=>null},request:async url=>{
  if(url.endsWith('/latest'))return Response.json(release());
  if(url.endsWith('/12'))return new Response(`${correct?hash:'0'.repeat(64)}  InstallStreet-1.4.0-x64.msi\n`);
  return new Response(bytes);
 }});
 await updater.check();await updater.download();assert.equal(await hashFile(updater.downloaded.installer),hash);assert.equal(updater.state.phase,'ready');
 correct=false;await assert.rejects(updater.download(),/checksum/);assert.equal(updater.downloaded,null);assert.equal(updater.busy,false);
});
test('missing public release is actionable without requesting credentials',async t=>{
 const updater=new Updates({version:'1.3.0',root:await fixture(t),settings:{token:()=> 'fixture-secret'},request:async()=>new Response('',{status:404})});
 await assert.rejects(updater.check(),/No published release/);assert.equal(updater.state.message.includes('fixture-secret'),false);assert.equal(updater.busy,false);
});
test('overlapping update requests are rejected',async t=>{
 let resolve;const updater=new Updates({version:'1.3.0',root:await fixture(t),settings:{token:()=>null},request:()=>new Promise(done=>{resolve=done;})});
 const pending=updater.check();await assert.rejects(updater.check(),/already active/);resolve(Response.json(release()));await pending;
});
test('Check for updates checks, downloads, verifies and installs in one action',async()=>{
 const steps=[],updates={downloaded:null,release:{version:'1.4.0'},check:async()=>steps.push('check'),download:async()=>{steps.push('download');updates.downloaded={version:'1.4.0'};}};
 const result=await installLatestUpdate({updates,workActive:()=>false,install:async()=>{steps.push('install');return {started:true};}});
 assert.deepEqual(steps,['check','download','install']);assert.deepEqual(result,{started:true});
});
test('Check for updates skips installation when current and reuses a verified download',async()=>{
 const calls=[],current={downloaded:null,release:null,check:async()=>calls.push('check'),download:async()=>calls.push('download')};
 assert.deepEqual(await installLatestUpdate({updates:current,workActive:()=>false,install:async()=>calls.push('install')}),{current:true});
 current.downloaded={version:'1.4.0'};
 await installLatestUpdate({updates:current,workActive:()=>false,install:async()=>calls.push('install')});
 assert.deepEqual(calls,['check','install']);
});
test('Check for updates does not run while setup or maintenance is active',async()=>{
 let checked=false;
 await assert.rejects(installLatestUpdate({updates:{check:async()=>{checked=true;}},workActive:()=>true,install:async()=>{}}),/Wait for setup/);
 assert.equal(checked,false);
});
