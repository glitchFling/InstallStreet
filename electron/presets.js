const fs = require('node:fs/promises');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const apps = ['winget','git','gh','chrome','codex','rufus','vscode','dotnet10','roblox','nvm-windows','playwright','react','tailwind','emscripten','dimmer','python','itunes','icloud','iloader','veracrypt','winrar','iconsextract','7zip','powertoys','terminal','notepadplusplus','vlc','firefox','everything','sharex','obs','steam','discord','nextdns','googledrive','chatgpt','ahk','clipchamp','davinciresolve','githubdesktop','godot','homebrew','scoop','tailscale','visualstudio','wsl','zoom'];
const settings = ['remove-linkedin','consumer-features','wallpaper','dark-mode','hidden-files','file-extensions','desktop-apps','running-icon','developer-mode','long-paths','disable-bing-search','taskbar-left','end-task-context'];
const dependencies = Object.fromEntries(['git','codex','rufus','vscode','dotnet10','roblox','nvm-windows','python','veracrypt','winrar','7zip','powertoys','terminal','notepadplusplus','vlc','firefox','everything','sharex','obs','steam','discord','nextdns','googledrive','chatgpt'].map(id=>[id,['winget']]));
for (const id of ['ahk','clipchamp','githubdesktop','godot','tailscale','visualstudio','wsl','zoom']) dependencies[id]=['winget'];
dependencies.playwright=['nvm-windows'];
dependencies.react=['nvm-windows']; dependencies.tailwind=['nvm-windows']; dependencies.emscripten=['git'];
dependencies.gh=['winget','git']; dependencies.iloader=['itunes'];
dependencies.homebrew=['winget','wsl'];
function selection(value) {
  if (!Array.isArray(value) || !value.length || value.length > apps.length + settings.length || value.some(id=>typeof id!=='string'||![...apps,...settings].includes(id))) throw new Error('Select at least one valid app or setting.');
  const result=[];
  const add=id=>{for(const dep of dependencies[id]||[])add(dep);if(!result.includes(id))result.push(id);};
  value.forEach(add);return result;
}
function preset(value) {
  if(!value || value.version!==1 || typeof value.name!=='string' || !value.name.trim() || value.name.length>80 || !['10','11'].includes(value.windows))throw new Error('Invalid InstallStreet preset.');
  if(!Array.isArray(value.tasks))throw new Error('Invalid InstallStreet preset.');
  const tasks=[...new Set(value.tasks.filter(id=>id!=='vmware'&&id!=='blender'))];
  selection(tasks);
  return {version:1,name:value.name.trim(),windows:value.windows,tasks};
}
function createPresetStore(root) {
  const folder=path.join(root,'Presets');
  const filename=id=>{if(!/^[a-f0-9-]{36}$/.test(id))throw new Error('Invalid preset ID.');return path.join(folder,id+'.json');};
  return {
    async list(){await fs.mkdir(folder,{recursive:true});const result=[];for(const file of await fs.readdir(folder)){if(!/^[a-f0-9-]{36}\.json$/.test(file))continue;try{result.push({id:file.slice(0,-5),...preset(JSON.parse(await fs.readFile(path.join(folder,file),'utf8')))});}catch{}}return result.sort((a,b)=>a.name.localeCompare(b.name));},
    async save(value,id){const clean=preset(value);id=id||randomUUID();const target=filename(id);await fs.mkdir(folder,{recursive:true});const temp=target+'.'+randomUUID()+'.tmp';await fs.writeFile(temp,JSON.stringify(clean,null,2),{flag:'wx'});await fs.rename(temp,target);return {id,...clean};},
    async remove(id){await fs.unlink(filename(id));}
  };
}
module.exports={apps,settings,selection,preset,createPresetStore};
