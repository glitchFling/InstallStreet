const { EventEmitter } = require('node:events');
const fs = require('node:fs/promises');
const { createWriteStream, createReadStream } = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const api = 'https://api.github.com/repos/glitchFling/InstallStreet';
function compareVersions(a, b) {
  if (!/^\d+\.\d+\.\d+$/.test(a) || !/^\d+\.\d+\.\d+$/.test(b)) throw new Error('Invalid stable release version.');
  const x = a.split('.').map(Number), y = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i] ? 1 : -1;
  return 0;
}
async function hashFile(file) {
  const hash = crypto.createHash('sha256');
  for await (const bytes of createReadStream(file)) hash.update(bytes);
  return hash.digest('hex');
}
class Updates extends EventEmitter {
  constructor({ version, root, settings, request = fetch, enabled = true }) {
    super(); Object.assign(this, { version, root, settings, request, enabled });
    this.busy = false; this.release = null; this.downloaded = null;
    this.state = { phase: 'idle', message: 'No update check yet.', currentVersion: version };
  }
  report(value) { this.state = { ...value, currentVersion: this.version }; this.emit('state', this.state); return this.state; }
  async get(suffix, binary = false) {
    const headers = { 'User-Agent': 'InstallStreet', Accept: binary ? 'application/octet-stream' : 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
    let response;
    try { response = await this.request(api + suffix, { headers, signal: AbortSignal.timeout(binary ? 600000 : 30000) }); }
    catch { throw new Error('GitHub could not be reached. Check your internet connection.'); }
    if (!response.ok) {
      if (response.status === 404) throw new Error('No published release is available. Publish a stable release with its MSI and checksums. Drafts are excluded.');
      if ([401, 403].includes(response.status)) throw new Error('GitHub denied or rate-limited this public request. Try again later.');
      throw new Error('GitHub update request failed (HTTP ' + response.status + ').');
    }
    return response;
  }
  async check() {
    if (!this.enabled) throw new Error('Update installation is available in packaged releases.');
    if (this.busy) throw new Error('An update operation is already active.');
    this.busy = true;
    this.report({ phase: 'checking', message: 'Checking published GitHub releases…' });
    try {
      const release = await (await this.get('/releases/latest')).json();
      const version = typeof release.tag_name === 'string' ? release.tag_name.replace(/^v/, '') : '';
      if (release.draft || release.prerelease) throw new Error('Only published stable releases can be installed.');
      if (compareVersions(version, this.version) <= 0) { this.release = null; this.downloaded = null; return this.report({ phase: 'current', message: 'InstallStreet is up to date.' }); }
      const name = `InstallStreet-${version}-x64.msi`;
      const assets = release.assets || [];
      const installer = assets.find(item => item.name === name), checksums = assets.find(item => item.name === 'SHA256SUMS.txt');
      if (!installer || !checksums || ![installer.id, checksums.id].every(id => Number.isSafeInteger(id) && id > 0)) throw new Error('This release is missing its MSI or checksums.');
      this.release = { version, name, installerId: installer.id, checksumsId: checksums.id };
      this.downloaded = null;
      return this.report({ phase: 'available', version, message: `InstallStreet ${version} is available.` });
    } catch (error) { this.report({ phase: 'error', message: error.message }); throw error; }
    finally { this.busy = false; }
  }
  async download() {
    if (!this.enabled || !this.release) throw new Error('Check for a new release first.');
    if (this.busy) throw new Error('An update operation is already active.');
    this.busy = true; this.downloaded = null;
    const release = { ...this.release };
    this.report({ phase: 'downloading', version: release.version, message: 'Downloading and verifying the update…' });
    let installer;
    try {
      const text = await (await this.get('/releases/assets/' + release.checksumsId, true)).text();
      if (text.length > 100000) throw new Error('Release checksums are too large.');
      const entries = text.split(/\r?\n/).map(line => line.match(/^([a-f0-9]{64})\s+\*?(.+)$/i)).filter(Boolean).filter(item => item[2] === release.name);
      if (entries.length !== 1) throw new Error('The release has no unique checksum for this MSI.');
      const hash = entries[0][1].toLowerCase();
      const directory = path.join(this.root, 'Updates', crypto.randomUUID());
      await fs.mkdir(directory, { recursive: true });
      installer = path.join(directory, release.name);
      const response = await this.get('/releases/assets/' + release.installerId, true);
      if (!response.body) throw new Error('The update download was empty.');
      await pipeline(Readable.fromWeb(response.body), createWriteStream(installer, { flags: 'wx' }));
      if (await hashFile(installer) !== hash) throw new Error('Update checksum verification failed. Installation was blocked.');
      this.downloaded = { installer, hash, version: release.version };
      return this.report({ phase: 'ready', version: release.version, message: `Version ${release.version} is verified and ready to install.` });
    } catch (error) { if (installer) await fs.rm(installer, { force: true }).catch(() => {}); this.report({ phase: 'error', message: error.message }); throw error; }
    finally { this.busy = false; }
  }
}
module.exports = { Updates, compareVersions, hashFile };
