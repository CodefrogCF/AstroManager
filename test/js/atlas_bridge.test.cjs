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
    setTimeout() {return 1;},
    clearTimeout() {},
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
  return {win, commands, messages, handlers};
}
function command(overrides={}) {
  return JSON.stringify({
    protocol, version:1, type:'state', ra:10.6847, dec:41.2688,
    fov:2.3, markers:[{id:'M31', ra:10.6847, dec:41.2688, label:'Andromeda'}],
    overlays:[{ra:10.6847,dec:41.2688,radius:0.3,color:'#3dd5f3'}],
    ...overrides,
  });
}
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
