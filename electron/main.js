const { app, BrowserWindow, ipcMain, shell, dialog, net, nativeTheme } = process.env.INSTALLSTREET_NATIVE ? require('../desktop/platform') : require('electron');
const path = require('node:path');
const fs = require('node:fs/promises');
const { pathToFileURL } = require('node:url');
const { createPresetStore, preset, selection, apps, settings } = require('./presets');
const { buildMedia, ensureOscdimg, findRufus } = require('./media');
let mediaBusy=false, builtIso=null;
const { Runner } = require('./runner');
const { createGitIdentity } = require('./git-identity');
const { createProfileStore } = require('./gh-profile');
const { SetupWorkflow } = require('./setup-workflow');
const { isAdministrator, elevate, ensureAdministrator } = require('./admin');
const { MaintenanceRunner, operation, publicCatalog } = require('./maintenance');
const { spawn } = require('node:child_process');
const { createUpdateSettings } = require('./update-settings');
const { Updates, hashFile } = require('./updates');
const { installLatestUpdate } = require('./update-flow');
let storageRequested=process.argv.includes('--storage-sense');
let storageWindow, maintenancePending=false, maintenanceLog;
const maintenance=new MaintenanceRunner();
const gitIdentity = createGitIdentity();

const root = process.env.INSTALLSTREET_NATIVE ? process.env.INSTALLSTREET_BACKEND : app.isPackaged ? path.join(process.resourcesPath, 'backend') : path.resolve(__dirname, '..');
const uiRoot = process.env.INSTALLSTREET_NATIVE ? path.join(process.resourcesPath, 'ui') : __dirname;
const dataRoot = app.isPackaged ? path.join(app.getPath('appData'), 'InstallStreet') : root;
const page = pathToFileURL(path.join(uiRoot, 'index.html')).href;
const smoke = process.argv.includes('--smoke-test');
app.setPath('userData', path.join(dataRoot, 'tmp', smoke ? 'electron-smoke-profile' : 'electron-user-data'));
app.setPath('crashDumps', path.join(dataRoot, 'tmp', 'electron-crashes'));
const runner = new Runner(root, undefined, dataRoot);
const updateSettings = createUpdateSettings(dataRoot);
const updates = new Updates({version:app.getVersion(),root:dataRoot,settings:updateSettings,enabled:app.isPackaged,request:(url,options)=>net.fetch(url,options)});
let installingUpdate=false, updateTimer, updateCheckTimer;
const workActive=()=>mediaBusy || workflow?.busy || runner.busy || maintenance.busy || maintenancePending;
updates.on('state',state=>{if(window && !window.isDestroyed())window.webContents.send('updates:state',state);});
async function installUpdate(automatic=false){
  if(installingUpdate)throw new Error('Update installation is already starting.');
  if(workActive())throw new Error('Wait for setup and StorageSense to finish before installing an update.');
  if(updates.busy || !updates.downloaded)throw new Error('Download and verify an update first.');
  installingUpdate=true;
  let started=false;
  try{
    if(!automatic){const answer=await dialog.showMessageBox(window,{type:'question',title:'Install update?',message:'Close InstallStreet, install the verified update, and reopen it?',detail:'Windows Installer will open. No automatic Windows restart occurs. For portable ZIP users, this installs an MSI copy; the extracted folder is unchanged.',buttons:['Install update','Cancel'],defaultId:1,cancelId:1,noLink:true});if(answer.response!==0)return {canceled:true};}
    const downloaded=updates.downloaded;
    if(await hashFile(downloaded.installer)!==downloaded.hash)throw new Error('The update file changed. Download it again.');
    const helper=path.join(path.dirname(downloaded.installer),'UpdateHelper.exe');
    await fs.copyFile(path.join(root,'UpdateHelper.exe'),helper);
    await new Promise((resolve,reject)=>{const child=spawn(helper,[downloaded.installer,downloaded.hash,String(process.pid)],{shell:false,detached:true,windowsHide:false,stdio:'ignore'});child.once('error',reject);child.once('spawn',()=>{child.unref();resolve();});});
    updates.report({phase:'installing',version:downloaded.version,message:`Installing version ${downloaded.version}. InstallStreet will reopen when the update finishes.`});
    started=true;app.quit();
    return {started:true};
  }finally{if(!started)installingUpdate=false;}
}
async function automaticUpdates(){
  if(!app.isPackaged || smoke)return;
  try{
    const settings=updateSettings.view();
    if(!settings.checkOnStartup)return;
    await updates.check();
    if(updates.release && settings.autoDownload){await updates.download();await maybeAutoInstall();}
  }catch{ /* State is displayed in Settings; startup remains usable. */ }
}
async function maybeAutoInstall(){
  if(!updateSettings.view().autoInstall || !updates.downloaded || installingUpdate || updates.busy)return;
  if(workActive()){updates.report({phase:'ready',version:updates.downloaded.version,message:'Update verified. Waiting for setup or maintenance to finish.'});return;}
  try{await installUpdate(true);}catch(error){updates.report({phase:'error',message:error.message});updates.downloaded=null;}
}
let window, workflow;
const storagePage=pathToFileURL(path.join(uiRoot,'storage.html')).href;
function openStorageWindow(){
  if(!window){storageRequested=true;return;}
  if(storageWindow && !storageWindow.isDestroyed()){storageWindow.show();storageWindow.focus();return;}
  storageWindow=new BrowserWindow({width:1180,height:900,minWidth:800,minHeight:620,title:'StorageSense — Administrator',backgroundColor:'#101419',webPreferences:{preload:path.join(uiRoot,'preload.js'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
  storageWindow.removeMenu();storageWindow.webContents.setWindowOpenHandler(()=>({action:'deny'}));storageWindow.webContents.on('will-navigate',event=>event.preventDefault());
  storageWindow.on('close',event=>{if(maintenance.busy||maintenancePending){event.preventDefault();storageWindow.webContents.send('maintenance:log','Wait for the active operation or confirmation to finish before closing.');}});
  storageWindow.on('closed',()=>{storageWindow=null;if(window && !window.isDestroyed() && !window.isVisible())window.close();});
  storageWindow.loadFile(path.join(uiRoot,'storage.html'));
}
maintenance.on('log',text=>{if(maintenanceLog)maintenanceLog.write(text+String.fromCharCode(10));if(storageWindow && !storageWindow.isDestroyed())storageWindow.webContents.send('maintenance:log',text);});
maintenance.on('state',state=>{if(storageWindow && !storageWindow.isDestroyed())storageWindow.webContents.send('maintenance:state',state);});
maintenance.on('progress',value=>{if(storageWindow && !storageWindow.isDestroyed())storageWindow.webContents.send('maintenance:progress',value);});
const profile = createProfileStore(dataRoot);
const presets=createPresetStore(dataRoot);
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', (_event,args) => { if(args.includes('--storage-sense')){openStorageWindow();return;}if(window){if(window.isMinimized())window.restore();window.show();window.focus();} });
  app.whenReady().then(async () => {
    const allowed = await ensureAdministrator(isAdministrator, () => elevate(app.isPackaged ? process.execPath : path.join(root, storageRequested ? 'StorageSense.exe' : 'InstallStreet.exe'), smoke));
    if (!allowed) { app.quit(); return; }
    nativeTheme.themeSource='dark';
    window = new BrowserWindow({ width: 1100, height: 780, minWidth: 800, minHeight: 600, show: false, backgroundColor: '#101419', title: 'InstallStreet — Administrator', icon: path.join(root, 'VaultHouse/icons/.running/running.ico'), webPreferences: { preload: path.join(uiRoot, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true, backgroundThrottling: false } });
    window.removeMenu();
    window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    window.webContents.on('will-navigate', event => event.preventDefault());
    window.webContents.session.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
    const validate = event => { if (event.sender !== window.webContents || event.senderFrame?.url !== page) throw new Error('Invalid application request.'); };
    ipcMain.handle('brand:icons8',event=>{validate(event);return shell.openExternal('https://icons8.com/');});
    ipcMain.handle('setup:close',event=>{validate(event);window.close();});
    ipcMain.handle('presets',async(event,action,value,id)=>{
      validate(event);
      if(action==='list')return presets.list();
      if(action==='save')return presets.save(value,id);
      if(action==='delete')return presets.remove(id);
      if(action==='export'){
        const clean=preset(value);const choice=await dialog.showSaveDialog(window,{title:'Export preset',defaultPath:'InstallStreet-preset.json',filters:[{name:'InstallStreet preset',extensions:['json']}]});
        if(!choice.canceled)await fs.writeFile(choice.filePath,JSON.stringify(clean,null,2));return;
      }
      if(action==='import'){
        const choice=await dialog.showOpenDialog(window,{title:'Import preset',properties:['openFile'],filters:[{name:'InstallStreet preset',extensions:['json']}]});if(choice.canceled)return null;
        if((await fs.stat(choice.filePaths[0])).size>65536)throw new Error('Preset file is too large.');
        return presets.save(JSON.parse(await fs.readFile(choice.filePaths[0],'utf8')));
      }
      throw new Error('Unknown preset action.');
    });
    ipcMain.handle('media:build',async(event,value)=>{
      validate(event);value=preset(value);if(workActive()||installingUpdate)throw new Error('Wait for the active operation.');mediaBusy=true;builtIso=null;
      try{
        const source=await dialog.showOpenDialog(window,{title:`Choose original Windows ${value.windows} x64 ISO`,properties:['openFile'],filters:[{name:'Windows ISO',extensions:['iso']}]});if(source.canceled)return null;
        const oscdimg=await ensureOscdimg(root,dataRoot,text=>window.webContents.send('setup:log',text));
        builtIso=await buildMedia({root,dataRoot,iso:source.filePaths[0],oscdimg,value,log:text=>window.webContents.send('setup:log',text)});return builtIso;
      }finally{mediaBusy=false;}
    });
    ipcMain.handle('media:flash', async event => {
      validate(event);
      if (workActive() || installingUpdate) throw new Error('Wait for the active operation.');
      if (!builtIso) throw new Error('Build an ISO first.');
      await fs.access(builtIso);
      let rufusExe = await findRufus(root);
      if (!rufusExe) {
        const tool = await dialog.showOpenDialog(window, {
          title: 'Choose Rufus to flash the ISO',
          properties: ['openFile'],
          filters: [{ name: 'Rufus executable', extensions: ['exe'] }]
        });
        if (tool.canceled) return;
        rufusExe = tool.filePaths[0];
      }
      if (!/^rufus.*\.exe$/i.test(path.basename(rufusExe))) throw new Error('Select a Rufus executable.');
      await new Promise((resolve, reject) => {
        const child = spawn(rufusExe, ['-i', builtIso], { shell: false, detached: true, stdio: 'ignore' });
        child.once('error', reject);
        child.once('spawn', () => { child.unref(); resolve(); });
      });
      return 'Rufus opened. Select the USB drive, review the target, and confirm erasure in Rufus.';
    });
    workflow = new SetupWorkflow(runner, profile, gitIdentity, async identity => {
      const answer = await dialog.showMessageBox(window, {
        type: 'warning', title: 'Change Git configuration?', message: 'Also use this profile for Git?',
        detail: `user.name: ${identity.name}\nuser.email: ${identity.email}\n\nThis replaces your global Git author name and email for this Windows account. It affects future commits in repositories that do not override these values. These details may be visible in published commits. Your local profile remains saved if you skip this step. This does not sign you into GitHub.`,
        buttons: ['Set Git identity', 'Keep Git configuration'], defaultId: 1, cancelId: 1, noLink: true
      });
      return answer.response === 0;
    });
    ipcMain.handle('setup:git-status', async event => { validate(event); return { ...await gitIdentity.status(), profile: await profile.load() }; });
    ipcMain.handle('setup:start', (event, mode, value, tasks) => { validate(event);selection(tasks);if(mediaBusy)throw new Error('Wait for media preparation.');if(installingUpdate)throw new Error('An update is starting.');if(maintenance.busy||maintenancePending)throw new Error('Wait for StorageSense to finish before starting setup.');return workflow.start(mode,value,tasks); });
    ipcMain.handle('setup:cancel', event => { validate(event); return runner.abort(); });
    try{await updateSettings.load();}catch(error){updates.report({phase:'error',message:error.message});}
    ipcMain.handle('updates:settings',event=>{validate(event);return {...updateSettings.view(),packaged:app.isPackaged,state:updates.state};});
    ipcMain.handle('updates:save',async(event,value)=>{
      validate(event);
      if(value?.autoInstall && !updateSettings.view().autoInstall){const answer=await dialog.showMessageBox(window,{type:'warning',title:'Enable automatic installation?',message:'Allow InstallStreet to close, install verified updates when idle, and reopen afterward?',detail:'Only published stable releases from glitchFling/InstallStreet are used. For a portable ZIP, updates install an MSI copy; the extracted folder is unchanged.',buttons:['Enable automatic installation','Cancel'],defaultId:1,cancelId:1,noLink:true});if(answer.response!==0)return {canceled:true};}
      return await updateSettings.save(value);
    });
    ipcMain.handle('updates:install-latest',event=>{validate(event);return installLatestUpdate({updates,install:()=>installUpdate(),workActive});});
    ipcMain.handle('storage:open',event=>{validate(event);openStorageWindow();});
    const validateStorage=event=>{if(!storageWindow || event.sender!==storageWindow.webContents || event.senderFrame?.url!==storagePage)throw new Error('Invalid StorageSense request.');};
    ipcMain.handle('maintenance:catalog',event=>{validateStorage(event);return publicCatalog();});
    ipcMain.handle('maintenance:start',async(event,id)=>{
      validateStorage(event);
      if(installingUpdate)throw new Error('An update is starting.');
      const selected=operation(id);
      if(mediaBusy||workflow.busy||runner.busy||maintenance.busy||maintenancePending)throw new Error('Another setup or maintenance operation is active.');
      maintenancePending=true;
      try{
        if(selected.confirmation){const answer=await dialog.showMessageBox(storageWindow,{type:'warning',title:selected.name,message:selected.confirmation,buttons:['Run operation','Cancel'],defaultId:1,cancelId:1,noLink:true});if(answer.response!==0)return {canceled:true};}
        const logs=path.join(dataRoot,'StorageSense','Logs');await fs.mkdir(logs,{recursive:true});
        const log=path.join(logs,new Date().toISOString().replaceAll(':','-')+'-'+id+'.log');
        const handle=await fs.open(log,'wx');maintenanceLog=handle.createWriteStream();maintenanceLog.on('error',error=>{if(storageWindow && !storageWindow.isDestroyed())storageWindow.webContents.send('maintenance:log','Log write failed: '+error.message);});
        try{return await maintenance.start(id);}finally{await new Promise(resolve=>maintenanceLog.end(resolve));maintenanceLog=null;}
      }finally{maintenancePending=false;}
    });
    ipcMain.handle('maintenance:open',async(event,id)=>{
      validateStorage(event);
      if(id==='settings'){await shell.openExternal('ms-settings:storagesense');return '';}
      if(id==='logs'){const folder=path.join(dataRoot,'StorageSense','Logs');try{await fs.access(folder);}catch{return 'No operation logs yet.';}return shell.openPath(folder);}
      const paths={dism:path.join(process.env.SystemRoot||'C:\\Windows','Logs/DISM/dism.log'),cbs:path.join(process.env.SystemRoot||'C:\\Windows','Logs/CBS/CBS.log')};
      if(!paths[id])throw new Error('Unknown StorageSense log.');
      try{await fs.access(paths[id]);}catch{return 'Windows has not created this log yet.';}
      spawn(path.join(process.env.SystemRoot||'C:\\Windows','System32/notepad.exe'),[paths[id]],{shell:false,windowsHide:false,stdio:'ignore'}).on('error',error=>storageWindow.webContents.send('maintenance:log',error.message));
      return '';
    });
    ipcMain.handle('setup:logs', async event => {
      validate(event);
      const folder = path.join(dataRoot, 'StatusHQ');
      try { await fs.access(folder); } catch { return 'No logs yet. Run setup first.'; }
      return shell.openPath(folder);
    });
    workflow.on('log', text => { if (!window.isDestroyed()) window.webContents.send('setup:log', text); });
    workflow.on('state', state => { if (!window.isDestroyed()) window.webContents.send('setup:state', state); });
    window.on('close', event => { if(installingUpdate)return;if (mediaBusy || workflow.busy || runner.busy || maintenance.busy || maintenancePending) { event.preventDefault(); window.webContents.send('setup:log', 'Setup or maintenance is active. Wait for it to finish before closing.'); } else if(storageWindow && !storageWindow.isDestroyed()){event.preventDefault();window.hide();} });
    await window.loadFile(path.join(uiRoot, 'index.html'));
    if (!smoke) { if(storageRequested)openStorageWindow();else window.show(); }
    else {
      try {
        const canceled = await window.webContents.executeJavaScript("(async () => { const pending = requestIdentity({ name: 'Existing Git Author', email: 'existing@example.org', profile: null }); if (!document.getElementById('git-dialog').open) throw new Error('Profile dialog did not open'); document.getElementById('git-skip').click(); return await pending; })()");
        if (canceled !== null) throw new Error('Skipping profile configuration did not cancel the profile.');
        const smokeTasks=JSON.stringify([...apps,...settings]);
        const result = await window.webContents.executeJavaScript(`(async () => { if (document.querySelector('.hero input[type=checkbox],.hero select') || !window.installstreet) throw new Error('Invalid UI'); return await window.installstreet.start('check',null,${smokeTasks}); })()`);
        if (result.code !== 0) throw new Error('Read-only backend check failed.');
        await new Promise(resolve => setTimeout(resolve, 300));
        const expectedTasks=apps.length+settings.length;
        const complete = await window.webContents.executeJavaScript(`document.getElementById('count').textContent === '${expectedTasks} / ${expectedTasks} tasks' && !document.getElementById('run').disabled`);
        if (!complete) throw new Error('Renderer did not finish the read-only check.');
        const screenshot = await window.webContents.capturePage();
        await fs.mkdir(path.join(dataRoot, 'tmp'), { recursive: true });
        await fs.writeFile(path.join(dataRoot, 'tmp/electron-preview.png'), screenshot.toPNG());
        console.log('Electron smoke test passed. Preview: tmp/electron-preview.png');
        app.exit(0);
      } catch (error) { console.error(error); app.exit(1); }
    }
    if(!smoke){void automaticUpdates();updateTimer=setInterval(()=>{void maybeAutoInstall();},15000);updateTimer.unref();updateCheckTimer=setInterval(()=>{if(!updates.busy && !updates.downloaded)void automaticUpdates();},6*60*60*1000);updateCheckTimer.unref();}
  }).catch(error => { console.error(error); if (!smoke) dialog.showErrorBox('InstallStreet', error.message); app.exit(1); });
  app.on('window-all-closed', () => app.quit());
  app.on('before-quit',()=>{if(updateTimer)clearInterval(updateTimer);if(updateCheckTimer)clearInterval(updateCheckTimer);});
}
