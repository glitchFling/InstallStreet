const appRoster = [
  ['winget','WinGet','utilities'],['git','Git','dev'],['gh','GitHub CLI','dev'],['chrome','Google Chrome','browsers'],
  ['codex','OpenAI Codex','dev'],['rufus','Rufus','utilities'],['vscode','Visual Studio Code','dev'],['dotnet10','.NET 10 SDK','dev'],
  ['roblox','Roblox Player','gaming'],['nvm-windows','nvm · Node.js · npm','dev'],['playwright','Playwright','dev'],['dimmer','Dimmer','utilities'],['python','Python · pip','dev'],
  ['react','React + lucide-react','dev'],['tailwind','Tailwind CSS','dev'],['emscripten','Emscripten SDK','dev'],
  ['itunes','iTunes','media'],['icloud','iCloud','utilities'],['iloader','iLoader','utilities'],['veracrypt','VeraCrypt','utilities'],
  ['winrar','WinRAR','utilities'],['iconsextract','IconsExtract','utilities'],
  ['7zip','7-Zip','utilities'],['powertoys','Microsoft PowerToys','utilities'],['terminal','Windows Terminal','dev'],
  ['notepadplusplus','Notepad++','dev'],['vlc','VLC Media Player','media'],['firefox','Mozilla Firefox','browsers'],
  ['everything','Everything','utilities'],['sharex','ShareX','utilities'],['obs','OBS Studio','media'],
  ['steam','Steam','gaming'],['discord','Discord','gaming'],['nextdns','NextDNS','utilities'],
  ['googledrive','Google Drive','utilities'],['chatgpt','ChatGPT','utilities'],
  ['ahk','AutoHotkey','dev'],['clipchamp','Microsoft Clipchamp','media'],
  ['davinciresolve','DaVinci Resolve','media'],['githubdesktop','GitHub Desktop','dev'],['godot','Godot Engine','dev'],
  ['homebrew','Homebrew for WSL','dev'],['scoop','Scoop','dev'],['tailscale','Tailscale','utilities'],
  ['visualstudio','Visual Studio Community 2022','dev'],['wsl','Windows Subsystem for Linux','dev'],['zoom','Zoom Workplace','media']
];
const appIconExtensions = {
  '7zip':'webp',chrome:'webp',codex:'png',discord:'png',dotnet10:'webp',firefox:'webp',react:'svg',tailwind:'png',emscripten:'png',
  googledrive:'svg',icloud:'webp',itunes:'webp',nextdns:'svg',obs:'webp',playwright:'png',
  powertoys:'png',roblox:'webp',sharex:'png',steam:'webp',vlc:'png',winrar:'webp',winget:'png',
  clipchamp:'svg',davinciresolve:'webp',githubdesktop:'webp',godot:'webp',
  homebrew:'webp',tailscale:'png',visualstudio:'webp',wsl:'webp',ahk:'png',scoop:'webp',zoom:'png'
};
const appRosterRoot=document.getElementById('app-roster');
for(const [id,name,category] of appRoster){
  const item=document.createElement('li');item.dataset.app=id;item.dataset.category=category;
  const well=document.createElement('span');well.className='app-logo';
  const extension=appIconExtensions[id]||(id==='iloader'?'svg':'png');
  const logo=document.createElement('img');logo.src=`assets/apps/${id}.${extension}`;logo.alt='';logo.width=32;logo.height=32;well.append(logo);
  const text=document.createElement('span');text.textContent=name;
  const checkbox=document.createElement('input');checkbox.type='checkbox';checkbox.value=id;checkbox.setAttribute('aria-label',name);checkbox.className='task-choice';
  item.append(checkbox,well,text);appRosterRoot.append(item);
}

// ── Search & category filter ────────────────────────────────────────────────
function applyFilters() {
  const query = (document.getElementById('app-search').value || '').toLowerCase().trim();
  const activeChip = document.querySelector('.category-chip.active');
  const activeCategory = activeChip ? activeChip.dataset.category : 'all';
  document.querySelectorAll('#app-roster li[data-app]').forEach(li => {
    const nameEl = li.querySelector('span:not(.app-logo)');
    const nameMatch = !query || (nameEl && nameEl.textContent.toLowerCase().includes(query));
    const catMatch = activeCategory === 'all' || li.dataset.category === activeCategory;
    li.style.display = (nameMatch && catMatch) ? '' : 'none';
  });
}
document.getElementById('app-search').addEventListener('input', applyFilters);
document.querySelectorAll('.category-chip').forEach(chip => {
  chip.addEventListener('click', () => {
    document.querySelectorAll('.category-chip').forEach(c => c.classList.remove('active'));
    chip.classList.add('active');
    applyFilters();
  });
});

// ── Copy logs ───────────────────────────────────────────────────────────────
document.getElementById('copy-logs').addEventListener('click', () => {
  const output = document.getElementById('output');
  if (output) navigator.clipboard.writeText(output.textContent || '').catch(() => {});
});

document.getElementById('icons8-credit').addEventListener('click',async()=>{try{await window.installstreet.openIcons8();}catch(error){document.getElementById('status').textContent=error.message;}});
document.getElementById('finish').addEventListener('click',async()=>{try{await window.installstreet.closeSetup();}catch(error){document.getElementById('status').textContent=error.message;}});
window.installstreet.onState(state=>{
  const title=document.getElementById('wizard-title'),description=document.getElementById('wizard-description');
  const active=state.busy?2:state.code===undefined?1:3;
  document.querySelectorAll('[data-wizard-step]').forEach(item=>{item.classList.toggle('active',Number(item.dataset.wizardStep)===active);item.classList.toggle('completed',Number(item.dataset.wizardStep)<active);});
  document.getElementById('finish').disabled=state.busy;
  document.getElementById('finish').textContent=state.busy?'Close':state.code===0?'Finish':'Close';
  document.getElementById('run').textContent=state.busy?(state.mode==='check'?'Checking…':'Installing…'):state.code===undefined || state.mode==='check'?'Install':'Run again';
  // Show/hide Cancel button
  const cancelBtn=document.getElementById('cancel-setup');
  if(cancelBtn) cancelBtn.style.display=state.busy?'':'none';
  if(state.busy){title.textContent=state.mode==='check'?'Checking this computer':'Installing applications';description.textContent=state.mode==='check'?'InstallStreet is checking the current configuration.':'Please wait while InstallStreet completes the setup tasks.';}
  else if(state.code!==undefined){title.textContent=state.code===0?(state.mode==='check'?'Check completed':'Setup completed'):'Setup needs attention';description.textContent=state.code===0?'Review the results below, then choose Finish.':'Review the output below and use Retry setup after resolving the reported issues.';}
});

// ── Cancel setup ────────────────────────────────────────────────────────────
const cancelSetupBtn = document.getElementById('cancel-setup');
if (cancelSetupBtn) {
  cancelSetupBtn.addEventListener('click', async () => {
    try { await window.installstreet.cancelSetup(); } catch (error) { document.getElementById('status').textContent = error.message; }
  });
}
