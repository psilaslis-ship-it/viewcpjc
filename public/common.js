let state;
const socket = io();
socket.on('state', next => { state = next; window.dispatchEvent(new CustomEvent('display-state', { detail: state })); });
async function api(url, options = {}) {
  const response = await fetch(url, { headers: { 'Content-Type': 'application/json', ...(options.headers || {}) }, ...options });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || 'Operação não concluída');
  return response.status === 204 ? null : response.json();
}
