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
  let frameOverlay = null;
  let ready = false;
  let queued = null;
  let lastReported = '';
  let feedbackTimer = null;
  let fatalMessage = null;

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
    // An onerror handler can run immediately before boot(). Preserve the
    // original, actionable error instead of replacing it with a generic one.
    if (fatalMessage) return;
    fatalMessage = String(message);
    const warning = root.document && root.document.getElementById('warning');
    if (warning) {
      warning.textContent = fatalMessage;
      warning.style.display = 'block';
    }
    report('error', {message: fatalMessage});
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

  function setCameraFrame(frame) {
    // A dedicated sky-coordinate layer: it stays at its celestial position
    // while users pan, zoom or change the Aladin view projection.
    if (frameOverlay) {
      aladin.removeOverlay(frameOverlay);
      frameOverlay = null;
    }
    if (frame === null || frame === undefined) return true;
    if (typeof frame !== 'object' || !Number.isFinite(frame.width) ||
        !Number.isFinite(frame.height) || frame.width <= 0 ||
        frame.height <= 0 || frame.width >= 170 || frame.height >= 170 ||
        !Number.isFinite(frame.rotation) || frame.rotation < 0 ||
        frame.rotation >= 360 || !Array.isArray(frame.points) ||
        frame.points.length < 5 || frame.points.length > 260 ||
        !frame.points.every(p => Array.isArray(p) && p.length === 2 &&
          validPosition(p[0], p[1]))) return false;
    frameOverlay = root.A.graphicOverlay({
      name: 'Camera sensor field of view', color: '#ffb74d',
      lineWidth: 3, lineDash: [8, 4],
    });
    frameOverlay.addFootprints(root.A.polyline(frame.points));
    aladin.addOverlay(frameOverlay);
    return true;
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
      if (!setCameraFrame(cmd.cameraFrame)) return false;
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
    if (fatalMessage) return;
    if (!root.A) {
      fatal('Aladin Lite JavaScript did not initialize window.A. Inspect the aladin.js request in Chrome DevTools > Network and the browser Console.');
      return;
    }
    if (!root.A.init || typeof root.A.init.then !== 'function') {
      fatal('Aladin Lite initialization API is missing (A.init). Check for a blocked or incompatible aladin.js script.');
      return;
    }
    root.A.init.then(function () {
      try {
        aladin = root.A.aladin('#aladin', {
          target:'10.6847 41.2688', fov:3,
          survey:'https://skies.esac.esa.int/DSSColor', cooFrame:'ICRS',
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
