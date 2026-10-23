const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const multer = require('multer');
const { createProxyMiddleware } = require('http-proxy-middleware');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const APP_ROOT = __dirname;
const DATA_DIR = process.env.DATA_DIR || path.join(APP_ROOT, 'data');
const UPLOAD_DIR = path.join(DATA_DIR, 'uploads');
const CONFIG_FILE = path.join(DATA_DIR, 'config.json');
const DEFAULT_FILE = path.join(APP_ROOT, 'config', 'default.json');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

function readConfig() {
  if (!fs.existsSync(CONFIG_FILE)) fs.copyFileSync(DEFAULT_FILE, CONFIG_FILE);
  return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
}
let config = readConfig();
// Configurações de instalações anteriores continuam válidas após a atualização.
if (!['auto', 'manual'].includes(config.clock.colorMode)) config.clock.colorMode = 'auto';
if (config.clock.running && !Number.isFinite(config.clock.startedAt)) config.clock.startedAt = Date.now();
function saveConfig() {
  const temp = `${CONFIG_FILE}.tmp`;
  fs.writeFileSync(temp, JSON.stringify(config, null, 2));
  fs.renameSync(temp, CONFIG_FILE);
}
function publicState() {
  return { ...config, serverNow: Date.now() };
}
function safeMediaName(name) {
  return `${crypto.randomUUID()}${path.extname(name).toLowerCase()}`;
}
function validHttpUrl(value) {
  try { const u = new URL(value); return u.protocol === 'http:' || u.protocol === 'https:'; } catch { return false; }
}

const app = express();
const server = http.createServer(app);
const io = new Server(server);
const upload = multer({
  storage: multer.diskStorage({ destination: UPLOAD_DIR, filename: (_, file, cb) => cb(null, safeMediaName(file.originalname)) }),
  limits: { fileSize: 2 * 1024 * 1024 * 1024 }
});
app.use(express.json({ limit: '1mb' }));
app.use('/media', express.static(UPLOAD_DIR, { fallthrough: false }));
app.use(express.static(path.join(APP_ROOT, 'public')));

function publish() { saveConfig(); io.emit('state', publicState()); }
app.get('/api/state', (_, res) => res.json(publicState()));
app.post('/api/clock', (req, res) => {
  const input = req.body || {};
  if ('elapsedSeconds' in input && (!Number.isFinite(Number(input.elapsedSeconds)) || Number(input.elapsedSeconds) < 0)) return res.status(400).json({ error: 'Tempo inválido' });
  if ('colorMode' in input && !['auto', 'manual'].includes(input.colorMode)) return res.status(400).json({ error: 'Modo de cor inválido' });
  if ('font' in input && !['digital', 'mono'].includes(input.font)) return res.status(400).json({ error: 'Fonte inválida' });
  for (const key of ['color', 'background']) {
    if (key in input && !/^#[0-9a-f]{6}$/i.test(input[key])) return res.status(400).json({ error: 'Cor inválida' });
  }
  const clock = config.clock;
  if (clock.running && input.running === false) {
    clock.elapsedSeconds += (Date.now() - clock.startedAt) / 1000;
    clock.startedAt = null;
  }
  if ('elapsedSeconds' in input) clock.elapsedSeconds = Number(input.elapsedSeconds);
  if (input.running === true && !clock.running) clock.startedAt = Date.now();
  if ('elapsedSeconds' in input && clock.running) clock.startedAt = Date.now();
  if ('running' in input) clock.running = input.running === true;
  for (const key of ['color', 'background', 'font', 'colorMode', 'showTenths']) {
    if (key in input) clock[key] = input[key];
  }
  publish(); res.json(config.clock);
});
app.post('/api/hdmi', (req, res) => {
  const { mode, source, fit, message } = req.body;
  if (!['message', 'image', 'video', 'holyrics'].includes(mode)) return res.status(400).json({ error: 'Modo inválido' });
  if (mode === 'holyrics' && !validHttpUrl(source)) return res.status(400).json({ error: 'URL do Holyrics inválida' });
  config.hdmi = { mode, source: source || '', fit: fit === 'cover' ? 'cover' : 'contain', message: message || '' };
  publish(); res.json(config.hdmi);
});
app.post('/api/upload', upload.single('file'), (req, res) => {
  if (!req.file || !/^(image|video)\//.test(req.file.mimetype)) return res.status(400).json({ error: 'Envie uma imagem ou vídeo.' });
  res.json({ url: `/media/${req.file.filename}`, type: req.file.mimetype.startsWith('video/') ? 'video' : 'image', name: req.file.originalname });
});
app.post('/api/holyrics-routes', (req, res) => {
  const { name, url } = req.body;
  if (!name || !validHttpUrl(url)) return res.status(400).json({ error: 'Nome e URL HTTP(S) são obrigatórios.' });
  config.holyricsRoutes.push({ name: String(name).slice(0, 80), url }); publish(); res.status(201).json(config.holyricsRoutes);
});
app.delete('/api/holyrics-routes/:index', (req, res) => {
  const i = Number(req.params.index);
  if (!Number.isInteger(i) || i < 0 || i >= config.holyricsRoutes.length) return res.status(404).end();
  config.holyricsRoutes.splice(i, 1); publish(); res.status(204).end();
});

// O proxy é intencional: o player HDMI carrega o Holyrics pela mesma origem e não cria polling/screenshot.
app.use('/holyrics', (req, res, next) => {
  const raw = req.query.url;
  if (!validHttpUrl(raw)) return res.status(400).send('Informe ?url=<URL HTTP(S)>');
  const target = new URL(raw);
  return createProxyMiddleware({ target: target.origin, changeOrigin: true, ws: true, pathRewrite: () => `${target.pathname}${target.search}`, on: { proxyRes(proxyRes) { delete proxyRes.headers['x-frame-options']; delete proxyRes.headers['content-security-policy']; } } })(req, res, next);
});

io.on('connection', socket => socket.emit('state', publicState()));
const port = Number(process.env.PORT || config.network.port || 8080);
server.listen(port, '0.0.0.0', () => console.log(`Painel disponível em http://0.0.0.0:${port}`));
