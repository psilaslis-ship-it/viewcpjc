let state;
let serverClockOffset = 0;
const socket = io();
socket.on('state', next => { serverClockOffset = next.serverNow - Date.now(); state = next; window.dispatchEvent(new CustomEvent('display-state', { detail: state })); });
function contrastColor(background) {
  const channels = background.match(/[0-9a-f]{2}/gi)?.slice(0, 3).map(part => parseInt(part, 16) / 255);
  if (!channels || channels.length !== 3) return '#ffffff';
  const luminance = channels.map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
  return luminance[0] * 0.2126 + luminance[1] * 0.7152 + luminance[2] * 0.0722 > 0.179 ? '#101820' : '#ffffff';
}
function clockSeconds(clock) {
  return clock.elapsedSeconds + (clock.running && Number.isFinite(clock.startedAt) ? Math.max(0, Date.now() + serverClockOffset - clock.startedAt) / 1000 : 0);
}
function clockColor(clock) { return clock.colorMode === 'manual' ? clock.color : contrastColor(clock.background); }
async function api(url, options = {}) {
  const response = await fetch(url, { headers: { 'Content-Type': 'application/json', ...(options.headers || {}) }, ...options });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || 'Operação não concluída');
  return response.status === 204 ? null : response.json();
}
