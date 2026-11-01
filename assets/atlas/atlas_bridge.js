/* AstroManager <-> Aladin Lite v3 protocol (version 1).
 * Keep this file pure JS to permit Node-based bridge tests without Flutter.
 */
(function (root) {
  'use strict';
  const protocol = 'astromanager.aladin';
  const version = 1;
  let aladin = null;
  let markers = null;
  let overlay = null;
  let ready = false;
  let queued = null;
  let lastReported = '';
  let feedbackTimer = null;

  function report(type, fields) {
    const packet = JSON.stringify({protocol, version, type, ...(fields || {})});
    try {
      if (root.AstroManagerBridge &&
          typeof root.AstroManagerBridge.postMessage === 'function') {
        root.AstroManagerBridge.postMessage(packet);
      }
      if (root.parent && root.parent !== root) {
        root.parent.postMessage(packet, root.location.origin);
      }
    } catch (_) { /* The caller can still use its load timeout. */ }
  }

  function fatal(message) {
    const warning = root.document && root.document.getElementById('warning');
    if (warning) {
      warning.textContent = String(message);
      warning.style.display = 'block';
    }
    report('error', {message: String(message)});
  }

  function validPosition(ra, dec) {
    return Number.isFinite(ra) && ra >= 0 && ra < 360 &&
        Number.isFinite(dec) && dec >= -90 && dec <= 90;
  }

  function validFov(value) {
    return Number.isFinite(value) && value >= 0.01 && value <= 180;
  }

  function escapeText(value) {
    return String(value).replace(/[&<>"']/g, function (c) {
      return ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'})[c];
    });
  }

  function setMarkers(next) {
    if (!Array.isArray(next)) return;
    if (markers) markers.remove();
    markers = root.A.catalog({name:'AstroManager targets', color:'#ffd84a', sourceSize:14});
    const sources = [];
    for (const item of next.slice(0, 250)) {
      if (!item || !validPosition(item.ra, item.dec)) continue;
      if (typeof item.label !== 'string') continue;
      sources.push(root.A.marker(item.ra, item.dec, {
        popupTitle: escapeText(item.label.slice(0, 180)),
      }));
    }
    markers.addSources(sources);
    aladin.addCatalog(markers);
  }

  function setOverlays(next) {
    if (!Array.isArray(next)) return;
    if (overlay) aladin.removeOverlay(overlay);
    overlay = root.A.graphicOverlay({color:'#3dd5f3', lineWidth:2});
    for (const item of next.slice(0, 100)) {
      if (!item || !validPosition(item.ra, item.dec) ||
          !Number.isFinite(item.radius) || item.radius <= 0 || item.radius > 90 ||
          typeof item.color !== 'string' ||
          !/^#[0-9a-fA-F]{6}$/.test(item.color)) continue;
      overlay.addFootprints(root.A.circle(
        item.ra, item.dec, item.radius, {color:item.color},
      ));
    }
    aladin.addOverlay(overlay);
  }

  function receive(text) {
    let cmd;
    try { cmd = typeof text === 'string' ? JSON.parse(text) : text; }
    catch (_) { return false; }
    if (!cmd || cmd.protocol !== protocol || cmd.version !== version ||
        cmd.type !== 'state' || !validPosition(cmd.ra, cmd.dec) ||
        !validFov(cmd.fov)) return false;
    if (!ready) { queued = cmd; return true; }
    try {
      aladin.gotoRaDec(cmd.ra, cmd.dec);
      aladin.setFoV(cmd.fov);
      setMarkers(cmd.markers);
      setOverlays(cmd.overlays);
    } catch (error) {
      fatal('Sky atlas command failed: ' + (error && error.message || error));
      return false;
    }
    return true;
  }

  function reportView() {
    if (!ready) return;
    try {
      const p = aladin.getRaDec();
      const f = aladin.getFov();
      const ra = Array.isArray(p) ? p[0] : p.ra;
      const dec = Array.isArray(p) ? p[1] : p.dec;
      const fov = Array.isArray(f) ? f[0] : f;
      if (!validPosition(ra, dec) || !validFov(fov)) return;
      const key = [ra.toFixed(5), dec.toFixed(5), fov.toFixed(5)].join(':');
      if (key === lastReported) return;
      lastReported = key;
      report('viewChanged', {ra, dec, fov});
    } catch (_) { /* Invalid intermediate map position while dragging. */ }
  }

  function scheduleViewReport() {
    if (feedbackTimer) root.clearTimeout(feedbackTimer);
    feedbackTimer = root.setTimeout(reportView, 120);
  }

  function boot() {
    if (!root.A || !root.A.init || !root.A.init.then) {
      fatal('Aladin Lite is unavailable (network or WebGL issue).');
      return;
    }
    root.A.init.then(function () {
      try {
        aladin = root.A.aladin('#aladin', {
          target:'10.6847 41.2688', fov:3,
          survey:'P/DSS2/color', cooFrame:'ICRS',
          showReticle:true, showFullscreenControl:false,
        });
        aladin.on('positionChanged', scheduleViewReport);
        aladin.on('zoomChanged', scheduleViewReport);
        ready = true;
        report('ready');
        if (queued) { const pending = queued; queued = null; receive(pending); }
        scheduleViewReport();
      } catch (error) {
        fatal('Sky atlas initialization failed: ' + (error && error.message || error));
      }
    }).catch(function (error) {
      fatal('Sky atlas initialization failed: ' + (error && error.message || error));
    });
  }

  root.addEventListener('message', function (event) {
    if (event.source !== root.parent || event.origin !== root.location.origin) return;
    receive(event.data);
  });
  root.AstroManagerAtlas = { boot, receive, fatal };
})(window);
