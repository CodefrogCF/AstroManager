const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(
  path.resolve(__dirname, '../../assets/atlas/atlas_bridge.js'), 'utf8',
);
const protocol = 'astromanager.aladin';
function fixture() {
  const commands = [];
  const messages = [];
  const handlers = {};
  const images = [];
  const timers = new Map();
  let nextTimer = 1;
  const atlas = {
    gotoRaDec(ra, dec) {commands.push(['goto', ra, dec]);},
    setFoV(fov) {commands.push(['fov', fov]);},
    addCatalog(cat) {commands.push(['catalog', cat]);},
    addOverlay(o) {commands.push(['overlay', o]);},
    removeOverlay(o) {commands.push(['remove-overlay', o]);},
    getRaDec() {return [10.6847, 41.2688];},
    getFov() {return [3];},
    on(name, fn) {handlers[name] = fn;},
  };
  const win = {
    location: {origin:'https://localhost.test'},
    parent: null,
    document: {getElementById() {return {textContent:'', style:{}};}},
    addEventListener(name, fn) {handlers[name] = fn;},
    setTimeout(fn, delay) {
      const id = nextTimer++;
      timers.set(id, {fn, delay});
      return id;
    },
    clearTimeout(id) {timers.delete(id);},
    Image: class {
      constructor() {images.push(this);}
      set src(value) {this.url = value;}
      get src() {return this.url;}
    },
    AstroManagerBridge: {postMessage(message) {messages.push(JSON.parse(message));}},
    A: {
      init: Promise.resolve(), aladin() {return atlas;},
      catalog() {return {addSources(s) {commands.push(['sources', s]);}, remove() {}};},
      marker(ra, dec, options) {return {ra, dec, title:options.popupTitle};},
      graphicOverlay() {return {addFootprints(c) {commands.push(['circle', c]);}};},
      circle(ra, dec, radius) {return {ra, dec, radius};},
    },
  };
  win.parent = win;
  vm.runInNewContext(source, {window: win});
  return {win, atlas, commands, messages, handlers, images, timers};
}
function command(overrides={}) {
  return JSON.stringify({
    protocol, version:1, type:'state', ra:10.6847, dec:41.2688,
    fov:2.3, markers:[{id:'M31', ra:10.6847, dec:41.2688, label:'Andromeda'}],
    overlays:[{ra:10.6847,dec:41.2688,radius:0.3,color:'#3dd5f3'}],
    ...overrides,
  });
}
test('Aladin controls are hidden by default on phones and can be restored', async () => {
  const fx = fixture();
  const classes = new Set();
  fx.win.innerWidth = 390;
  fx.win.document.documentElement = {classList: {
    toggle(name, active) {
      if (active) classes.add(name);
      else classes.delete(name);
    },
  }};
  fx.win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(classes.has('astro-hide-aladin-ui'), true);
  assert.equal(fx.win.AstroManagerAtlas.receive(command({showAladinControls:true})), true);
  assert.equal(classes.has('astro-hide-aladin-ui'), false);
  fx.handlers.resize();
  assert.equal(classes.has('astro-hide-aladin-ui'), false);
  assert.equal(fx.win.AstroManagerAtlas.receive(command({showAladinControls:false})), true);
  assert.equal(classes.has('astro-hide-aladin-ui'), true);
  assert.equal(fx.win.AstroManagerAtlas.receive(command({showAladinControls:'invalid'})), false);
});

test('queues valid Flutter state until Aladin has initialized', async () => {
  const {win, commands, messages} = fixture();
  assert.equal(win.AstroManagerAtlas.receive(command()), true);
  assert.equal(commands.length, 0);
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.ok(messages.some(m => m.type === 'ready'));
  assert.deepEqual(commands[0], ['goto', 10.6847, 41.2688]);
  assert.deepEqual(commands[1], ['fov', 2.3]);
  assert.equal(commands.find(m => m[0] === 'sources')[1].length, 1);
});
test('invalid coordinates and unknown protocol cannot change atlas', async () => {
  const {win, commands} = fixture();
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(win.AstroManagerAtlas.receive(command({ra:361})), false);
  assert.equal(win.AstroManagerAtlas.receive(command({fov:0})), false);
  assert.equal(win.AstroManagerAtlas.receive(command({version:999})), false);
  assert.equal(commands.length, 0);
});
test('marker labels are HTML escaped before entering popup', async () => {
  const {win, commands} = fixture();
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  win.AstroManagerAtlas.receive(command({markers:[{
    id:'x',ra:11,dec:42,label:'<img onerror="alert(1)">',
  }]}));
  const source = commands.find(item => item[0] === 'sources')[1][0];
  assert.equal(source.title, '&lt;img onerror=&quot;alert(1)&quot;&gt;');
});
test('critical script failure reports an error packet', () => {
  const {win, messages} = fixture();
  win.AstroManagerAtlas.fatal('network offline');
  assert.equal(messages.at(-1).type, 'error');
  assert.match(messages.at(-1).message, /offline/);
});

test('valid astronomical overlays render circular annotation', async () => {
  const {win, commands} = fixture();
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  win.AstroManagerAtlas.receive(command());
  const circle = commands.find(item => item[0] === 'circle')[1];
  assert.equal(circle.radius, 0.3);
  assert.equal(circle.ra, 10.6847);
});

test('script load failure is not overwritten by boot', () => {
  const {win, messages} = fixture();
  win.AstroManagerAtlas.fatal('CDS aladin.js failed to load');
  win.AstroManagerAtlas.boot();
  const errors = messages.filter(m => m.type === 'error');
  assert.equal(errors.length, 1);
  assert.match(errors[0].message, /CDS aladin.js failed/);
});

test('missing Aladin global produces actionable error', () => {
  const {win, messages} = fixture();
  delete win.A;
  win.AstroManagerAtlas.boot();
  const errors = messages.filter(m => m.type === 'error');
  assert.equal(errors.length, 1);
  assert.match(errors[0].message, /window.A/);
  assert.match(errors[0].message, /DevTools/);
});

test('camera footprint uses a dedicated celestial polyline overlay', async () => {
  const {win, commands} = fixture();
  win.A.polyline = points => ({kind:'polyline', points});
  win.A.graphicOverlay = options => ({
    options, addFootprints(shape) {commands.push(['footprint', shape]);},
  });
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  const points = [[10, 41], [11, 41], [11, 42], [10, 42], [10, 41]];
  assert.equal(win.AstroManagerAtlas.receive(command({cameraFrame: {
    width:1, height:1, rotation:45, points,
  }})), true);
  const shape = commands.find(c => c[0] === 'footprint' && c[1].kind === 'polyline')[1];
  assert.equal(shape.kind, 'polyline');
  assert.deepEqual(JSON.stringify(shape.points), JSON.stringify(points));
  assert.equal(commands.filter(c => c[0] === 'overlay').length, 2);
  // Removing the frame never removes circular target overlays.
  assert.equal(win.AstroManagerAtlas.receive(command({cameraFrame:null})), true);
  assert.equal(commands.filter(c => c[0] === 'remove-overlay').length, 2);
});

test('malformed camera outlines never draw a footprint', async () => {
  const {win, commands} = fixture();
  win.A.polyline = points => ({points});
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(win.AstroManagerAtlas.receive(command({cameraFrame:{
    width:1,height:1,rotation:10,
    points:[[999,2],[0,0],[1,1],[1,2],[999,2]],
  }})), false);
  assert.equal(commands.filter(c => c[0] === 'footprint').length, 0);
});

// Regression: The npm bundle contains ES module exports and cannot run
// as a classic <script src="..."> without a SyntaxError.
test('atlas HTML loads the pinned Aladin bundle as an ES module before boot', () => {
  const html = fs.readFileSync(
    path.resolve(__dirname, '../../assets/atlas/atlas.html'), 'utf8',
  );
  assert.match(html, /<script type="module">/);
  assert.match(html, /await import\(/);
  assert.match(html, /aladin-lite@3\.8\.1\/dist\/aladin\.min\.js/);
  assert.match(html, /window\.A = api;[\s\S]*?window\.AstroManagerAtlas\.boot\(\)/);
  assert.doesNotMatch(html, /<script\s+src="[^"]*aladin\.min\.js"/);
});


test('initial survey uses an external full-sky HiPS mirror', async () => {
  const {win, atlas} = fixture();
  let options;
  win.A.aladin = (_selector, config) => {
    options = config;
    return atlas;
  };
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(options.survey, 'https://skies.esac.esa.int/DSSColor');
  assert.equal(options.cooFrame, 'ICRS');
});

test('dome mode changes projection and draws real sky-coordinate horizon rings', async () => {
  const {win, atlas, commands} = fixture();
  atlas.setProjection = value => commands.push(['projection', value]);
  win.A.polyline = points => ({kind:'polyline', points});
  win.A.source = (ra, dec, data) => ({ra, dec, data});
  win.A.graphicOverlay = options => ({
    options,
    addFootprints(shape) { commands.push(['dome-footprint', shape]); },
  });
  win.A.catalog = options => ({
    options,
    addSources(source) { commands.push(['dome-source', source]); },
    remove() { commands.push(['remove-compass']); },
  });
  const ring = Array.from({length:121}, (_, i) => [i * 0.5, 20]);
  const dome = {
    zenith:{ra:40,dec:47}, horizon:ring, altitude30:ring,
    altitude60:ring, minimumAltitude:ring,
    minimumAltitudeDegrees:25,
    cardinals: ['N','E','S','W'].map((label, index) => ({
      id:`horizon-${label}`, label, ra:10 + index * 45, dec:10,
    })),
  };
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(win.AstroManagerAtlas.receive(command({
    projection:'dome', dome, ra:40, dec:47, fov:180,
    cameraFrame:null,
  })), true);
  assert.deepEqual(commands.find(c => c[0] === 'projection'), ['projection', 'ZEA']);
  assert.equal(commands.filter(c => c[0] === 'dome-footprint' && c[1].kind === 'polyline').length, 4);
  assert.deepEqual(commands.filter(c => c[0] === 'dome-source' && !Array.isArray(c[1]))
    .map(c => c[1].data.name), ['N', 'E', 'S', 'W']);
  assert.equal(win.AstroManagerAtlas.receive(command({
    projection:'detail', dome:null, cameraFrame:null,
  })), true);
  assert.deepEqual(commands.filter(c => c[0] === 'projection').at(-1),
    ['projection', 'TAN']);
  assert.ok(commands.some(c => c[0] === 'remove-compass'));
});

test('dome rejects malformed horizon geometry', async () => {
  const {win, atlas} = fixture();
  atlas.setProjection = () => {};
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(win.AstroManagerAtlas.receive(command({
    projection:'dome', fov:180,
    dome: {zenith:{ra:10,dec:30}, horizon:[[10,30]],
      altitude30:[], altitude60:[], minimumAltitude:[], cardinals:[]},
  })), false);
});

// Smoke tests use the same atlas bridge file as Web and Android/iOS/macOS.
test('HiPS tile probe reports loading then available after image succeeds', async () => {
  const {win, images, messages} = fixture();
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.ok(messages.some(m => m.type === 'ready'));
  assert.ok(messages.some(m => m.type === 'imageryLoading'));
  assert.equal(images.length, 1);
  assert.match(images[0].src, /^https:\/\/skies\.esac\.esa\.int\/DSSColor\/Norder0\/Dir0\/Npix\d+\.jpg$/);
  images[0].onload();
  assert.equal(messages.at(-1).type, 'imageryReady');
  assert.equal(messages.some(m => m.type === 'imageryError'), false);
});

test('tile request failure creates a recoverable error message', async () => {
  const {win, images, messages} = fixture();
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  images[0].onerror();
  assert.equal(messages.at(-1).type, 'imageryError');
  assert.match(messages.at(-1).message, /tile request failed/);
  assert.equal(messages.some(m => m.type === 'error'), false);
});

test('tile request timeout reports an error instead of waiting forever', async () => {
  const {win, messages, timers} = fixture();
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  const timeout = [...timers.values()].find(t => t.delay === 14000);
  assert.ok(timeout);
  timeout.fn();
  assert.equal(messages.at(-1).type, 'imageryError');
  assert.match(messages.at(-1).message, /timed out/);
});

test('survey probe is centered on the current sky region', () => {
  const {win} = fixture();
  for (const [ra, dec] of [[0,0],[45,75],[45,-75],[179,0],[359,0]]) {
    const index = win.AstroManagerAtlas.rootTileIndex(ra, dec);
    assert.ok(Number.isInteger(index) && index >= 0 && index <= 11);
  }
  assert.notEqual(win.AstroManagerAtlas.rootTileIndex(45, 75),
    win.AstroManagerAtlas.rootTileIndex(45, -75));
});

test('HTML retains Aladin logo and inline survey attribution is always visible', () => {
  const html = fs.readFileSync(path.resolve(__dirname, '../../assets/atlas/atlas.html'), 'utf8');
  assert.match(html, /<div id="aladin"><\/div>/);
  assert.doesNotMatch(html, /showSimbadPointerControl:\s*false|showLogo:\s*false/);
  const screen = fs.readFileSync(path.resolve(__dirname,
    '../../lib/features/atlas/presentation/sky_atlas_screen.dart'), 'utf8');
  assert.match(screen, /STScI\/NASA/);
  assert.match(screen, /OpenNGC \(CC BY-SA 4\.0\)/);
});

test('late failures from a previous sky center cannot replace a successful tile probe', async () => {
  const {win, atlas, messages, images, timers} = fixture();
  let pointing = [10.6847, 41.2688];
  atlas.getRaDec = () => pointing;
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  const oldImage = images[0];
  pointing = [185, -40];
  const report = [...timers.values()].find(item => item.delay === 120);
  assert.ok(report);
  report.fn();
  const nextProbe = [...timers.values()].find(item => item.delay === 1500);
  assert.ok(nextProbe);
  nextProbe.fn();
  assert.equal(images.length, 2);
  assert.notEqual(images[0].src, images[1].src);
  oldImage.onerror();
  assert.equal(messages.some(item => item.type === 'imageryError'), false);
  images[1].onload();
  assert.equal(messages.at(-1).type, 'imageryReady');
});

test('mosaic footprint renders independently and clears on sky dome switch', async () => {
  const {win, commands, atlas} = fixture();
  atlas.setProjection = () => {};
  win.A.polyline = points => ({kind:'polyline', points});
  win.A.source = (ra, dec, data) => ({ra, dec, data});
  win.A.graphicOverlay = options => ({options, addFootprints(shape) {
    commands.push(['mosaic-shape', shape]);
  }});
  win.A.catalog = () => ({addSources(s) {
    commands.push(['mosaic-label', s]);
  }, remove() {commands.push(['remove-labels']);}});
  const points = [[10,40],[11,40],[11,41],[10,41],[10,40]];
  const mosaic = {outline: points, panels: [{
    label:'R1C1', row:1, column:1, ra:10.5, dec:40.5, points,
  }]};
  win.AstroManagerAtlas.boot();
  await new Promise(setImmediate);
  assert.equal(win.AstroManagerAtlas.receive(command({mosaic})), true);
  assert.equal(commands.filter(c => c[0] === 'mosaic-shape').length, 3);
  assert.equal(commands.filter(c => c[0] === 'mosaic-label').length, 2);
  assert.equal(win.AstroManagerAtlas.receive(command({mosaic:null})), true);
  assert.ok(commands.some(c => c[0] === 'remove-labels'));
  assert.equal(win.AstroManagerAtlas.receive(command({mosaic: {
    outline:points, panels:[{label:'bad',ra:10,dec:40,points}],
  }})), false);
});
