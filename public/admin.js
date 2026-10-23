const $ = selector => document.querySelector(selector);
let toastTimer;

function toast(message, error = false) {
  const element = $('#toast');
  element.textContent = message;
  element.classList.toggle('error', error);
  element.style.display = 'block';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => element.style.display = 'none', 3500);
}

function showTab(name) {
  document.querySelectorAll('.tab').forEach(tab => tab.classList.toggle('active', tab.id === name));
  document.querySelectorAll('.nav-item').forEach(button => {
    const selected = button.dataset.tab === name;
    button.classList.toggle('active', selected);
    if (selected) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  });
}
document.querySelectorAll('.nav-item').forEach(button => button.addEventListener('click', () => showTab(button.dataset.tab)));

function setClock(patch) {
  if (!state) return Promise.resolve();
  return api('/api/clock', { method: 'POST', body: JSON.stringify(patch) }).catch(error => toast(error.message, true));
}
function setHdmi(payload) {
  return api('/api/hdmi', { method: 'POST', body: JSON.stringify(payload) });
}
function formatTime(seconds, tenths) {
  const whole = Math.floor(Math.max(0, seconds));
  const parts = [Math.floor(whole / 3600), Math.floor(whole % 3600 / 60), whole % 60].map(value => String(value).padStart(2, '0'));
  return parts.join(':') + (tenths ? '.' + Math.floor((seconds % 1) * 10) : '');
}
function updatePreview() {
  if (!state) return;
  const clock = state.clock;
  $('#clockPreview').textContent = formatTime(clockSeconds(clock), clock.showTenths);
  $('#clockScreen').style.backgroundColor = clock.background;
  $('#clockPreview').style.color = clockColor(clock);
  $('#clockPreview').classList.toggle('mono', clock.font === 'mono');
}
setInterval(updatePreview, 100);

function updateRoutes(routes) {
  const select = $('#routeSelect');
  const selected = select.value;
  select.replaceChildren(...routes.map(route => new Option(route.name, route.url)));
  if (routes.some(route => route.url === selected)) select.value = selected;
  $('#routeCount').textContent = routes.length;
  const items = routes.map((route, index) => {
    const row = document.createElement('li');
    const description = document.createElement('span');
    const title = document.createElement('strong');
    const url = document.createElement('small');
    const remove = document.createElement('button');
    title.textContent = route.name;
    url.textContent = route.url;
    remove.type = 'button';
    remove.textContent = 'Excluir';
    remove.setAttribute('aria-label', 'Excluir rota ' + route.name);
    remove.addEventListener('click', () => api('/api/holyrics-routes/' + index, { method: 'DELETE' }).catch(error => toast(error.message, true)));
    description.append(title, url);
    row.append(description, remove);
    return row;
  });
  $('#routeList').replaceChildren(...items);
}
function updateHdmi(hdmi) {
  const labels = { message: 'Mensagem', image: 'Imagem', video: 'Vídeo', holyrics: 'Holyrics' };
  $('#hdmiCurrent').textContent = labels[hdmi.mode] || 'Aguardando conteúdo';
  $('#hdmiDetail').textContent = hdmi.mode === 'message' ? (hdmi.message || 'Aguardando conteúdo') : (hdmi.source || 'Nenhuma mídia selecionada');
}
function sync(next) {
  const clock = next.clock;
  $('#clockStatus').textContent = clock.running ? 'Em andamento' : 'Pausado';
  $('#clockColor').value = clock.color;
  $('#clockBg').value = clock.background;
  $('#colorHex').textContent = clock.color.toUpperCase();
  $('#bgHex').textContent = clock.background.toUpperCase();
  $('#font').value = clock.font;
  $('#tenths').checked = clock.showTenths;
  const mode = clock.colorMode === 'manual' ? 'manual' : 'auto';
  document.querySelector('input[name="colorMode"][value="' + mode + '"]').checked = true;
  $('#manualColorField').hidden = mode !== 'manual';
  updatePreview();
  updateHdmi(next.hdmi);
  updateRoutes(next.holyricsRoutes);
}
addEventListener('display-state', event => sync(event.detail));
socket.on('connect', () => { $('#status').classList.remove('offline'); $('#statusText').textContent = 'Conectado'; });
socket.on('disconnect', () => { $('#status').classList.add('offline'); $('#statusText').textContent = 'Sem conexão'; });

$('#start').addEventListener('click', () => setClock({ running: true }));
$('#pause').addEventListener('click', () => setClock({ running: false }));
$('#reset').addEventListener('click', () => {
  if (confirm('Reiniciar o contador para zero?')) setClock({ running: false, elapsedSeconds: 0 });
});
$('#clockColor').addEventListener('change', event => setClock({ color: event.target.value }));
$('#clockBg').addEventListener('change', event => setClock({ background: event.target.value }));
$('#font').addEventListener('change', event => setClock({ font: event.target.value }));
$('#tenths').addEventListener('change', event => setClock({ showTenths: event.target.checked }));
document.querySelectorAll('input[name="colorMode"]').forEach(input => input.addEventListener('change', event => {
  if (event.target.checked) setClock({ colorMode: event.target.value });
}));

function showMode(name) {
  const forms = { message: '#messageForm', upload: '#uploadForm', holyrics: '#holyricsForm' };
  Object.entries(forms).forEach(([mode, selector]) => { $(selector).hidden = mode !== name; });
  [['message', '#modeMessage'], ['upload', '#modeUpload'], ['holyrics', '#modeHolyrics']].forEach(([mode, selector]) => {
    $(selector).classList.toggle('active', mode === name);
  });
}
$('#modeMessage').addEventListener('click', () => showMode('message'));
$('#modeUpload').addEventListener('click', () => showMode('upload'));
$('#modeHolyrics').addEventListener('click', () => showMode('holyrics'));
$('#messageForm').addEventListener('submit', event => {
  event.preventDefault();
  setHdmi({ mode: 'message', message: new FormData(event.target).get('message') }).then(() => toast('Mensagem enviada à HDMI.')).catch(error => toast(error.message, true));
});
$('#holyricsForm').addEventListener('submit', event => {
  event.preventDefault();
  setHdmi({ mode: 'holyrics', source: new FormData(event.target).get('url') }).then(() => toast('Holyrics enviado à HDMI.')).catch(error => toast(error.message, true));
});
$('#uploadForm').addEventListener('submit', async event => {
  event.preventDefault();
  const button = event.target.querySelector('button[type="submit"]');
  button.disabled = true;
  button.textContent = 'Enviando arquivo…';
  try {
    const form = new FormData(event.target);
    const response = await fetch('/api/upload', { method: 'POST', body: form });
    const uploaded = await response.json();
    if (!response.ok) throw new Error(uploaded.error || 'Falha no envio');
    await setHdmi({ mode: uploaded.type, source: uploaded.url, fit: form.get('fit') });
    toast('Mídia enviada à HDMI.');
  } catch (error) { toast(error.message, true); }
  finally { button.disabled = false; button.textContent = 'Enviar e reproduzir'; }
});
$('#routeForm').addEventListener('submit', async event => {
  event.preventDefault();
  try {
    const fields = Object.fromEntries(new FormData(event.target));
    await api('/api/holyrics-routes', { method: 'POST', body: JSON.stringify(fields) });
    event.target.reset();
    toast('Rota adicionada.');
  } catch (error) { toast(error.message, true); }
});
