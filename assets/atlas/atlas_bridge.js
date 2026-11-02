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
  let domeLayers = [];
  let domeCompass = null;
  let projectionMode = 'detail';
  let ready = false;
  let queued = null;
  let lastReported = '';
  let feedbackTimer = null;
  let fatalMessage = null;
  // A successful Aladin initialization does not prove the survey tiles load.
  const surveyBase = 'https://skies.esac.esa.int/DSSColor';
  const probeTimeoutMs = 14000;
  let tileProbeRevision = 0;
  let tileProbeTimer = null;
  let viewProbeTimer = null;
  let imageryStatus = 'unknown';


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

  function clearDome() {
    for (const layer of domeLayers) aladin.removeOverlay(layer);
    domeLayers = [];
    if (domeCompass) {
      domeCompass.remove();
      domeCompass = null;
    }
  }

  function validRing(points) {
    return Array.isArray(points) && points.length === 121 &&
      points.every(p => Array.isArray(p) && p.length === 2 &&
        validPosition(p[0], p[1]));
  }

  function setDome(dome) {
    clearDome();
    if (!dome) return true;
    if (!dome.zenith || !validPosition(dome.zenith.ra, dome.zenith.dec) ||
        !validRing(dome.horizon) || !validRing(dome.altitude30) ||
        !validRing(dome.altitude60) ||
        !Array.isArray(dome.minimumAltitude) ||
        (dome.minimumAltitude.length !== 0 &&
         !validRing(dome.minimumAltitude)) ||
        !Array.isArray(dome.cardinals) || dome.cardinals.length !== 4) {
      return false;
    }
    const layers = [
      {points:dome.horizon, color:'#63d6a5', width:3},
      {points:dome.altitude30, color:'#8aa6bc', width:1},
      {points:dome.altitude60, color:'#8aa6bc', width:1},
    ];
    if (dome.minimumAltitude.length) {
      layers.push({points:dome.minimumAltitude, color:'#f0c45b', width:2});
    }
    for (const item of layers) {
      const layer = root.A.graphicOverlay({
        name:'Local horizon / altitude', color:item.color,
        lineWidth:item.width,
      });
      layer.addFootprints(root.A.polyline(item.points));
      aladin.addOverlay(layer);
      domeLayers.push(layer);
    }
    domeCompass = root.A.catalog({
      name:'Horizon directions', color:'#86e9bf', sourceSize:5,
      displayLabel:true, labelColumn:'name',
      labelColor:'#d8ffeb', labelFont:'bold 14px sans-serif',
    });
    for (const point of dome.cardinals) {
      if (!point || !validPosition(point.ra, point.dec) ||
          !['N','E','S','W'].includes(point.label)) return false;
      domeCompass.addSources(root.A.source(point.ra, point.dec, {
        name:point.label,
      }));
    }
    aladin.addCatalog(domeCompass);
    return true;
  }

  function receive(text) {
    let cmd;
    try { cmd = typeof text === 'string' ? JSON.parse(text) : text; }
    catch (_) { return false; }
    if (!cmd || cmd.protocol !== protocol || cmd.version !== version ||
        cmd.type !== 'state' || !validPosition(cmd.ra, cmd.dec) ||
        !validFov(cmd.fov)) return false;
    const mode = cmd.projection || 'detail';
    if (!['detail', 'dome'].includes(mode)) return false;
    if (!ready) { queued = cmd; return true; }
    try {
      // The projection changes only when switching modes, not on each pan.
      if (mode !== projectionMode) {
        aladin.setProjection(mode === 'dome' ? 'ZEA' : 'TAN');
        projectionMode = mode;
      }
      aladin.gotoRaDec(cmd.ra, cmd.dec);
      aladin.setFoV(cmd.fov);
      setMarkers(cmd.markers);
      setOverlays(cmd.overlays);
      if (!setDome(mode === 'dome' ? cmd.dome : null)) return false;
      if (!setCameraFrame(mode === 'detail' ? cmd.cameraFrame : null)) return false;
    } catch (error) {
      fatal('Sky atlas command failed: ' + (error && error.message || error));
      return false;
    }
    return true;
  }

  // HEALPix nested order-0 face containing the sky center. All 12 DSS2
  // all-sky root tiles are expected to exist at this survey endpoint.
  // This checks one tile near the visible center; it is not a guarantee that
  // every higher-resolution tile across the field of view is available.
  function rootTileIndex(ra, dec) {
    if (!validPosition(ra, dec)) return 0;
    const z = Math.sin(dec * Math.PI / 180);
    const tt = (ra / 90) % 4;
    if (Math.abs(z) <= 2 / 3) {
      const jp = Math.floor(0.5 + tt - 0.75 * z);
      const jm = Math.floor(0.5 + tt + 0.75 * z);
      const fp = ((jp % 4) + 4) % 4;
      const fm = ((jm % 4) + 4) % 4;
      return jp === jm ? fp + 4 : jp < jm ? fp : fm + 8;
    }
    const quadrant = Math.min(3, Math.floor(tt));
    return z > 0 ? quadrant : quadrant + 8;
  }

  function cancelImageryProbe() {
    tileProbeRevision++;
    if (tileProbeTimer !== null) root.clearTimeout(tileProbeTimer);
    if (viewProbeTimer !== null) root.clearTimeout(viewProbeTimer);
    tileProbeTimer = null;
    viewProbeTimer = null;
  }

  function imageryEvent(type, message) {
    if (fatalMessage) return;
    if (imageryStatus === type) return;
    imageryStatus = type;
    report(type, message ? {message} : {});
    const warning = root.document && root.document.getElementById('warning');
    if (warning) {
      if (type === 'imageryError') {
        warning.textContent = message;
        warning.style.display = 'block';
      } else {
        warning.style.display = 'none';
      }
    }
  }

  // Image element loading uses the same cross-origin rules as survey tiles,
  // unlike fetch() which could report a false CORS failure. All callbacks
  // are generation-checked to ignore stale results after navigation/retry.
  function probeImagery() {
    if (!ready || fatalMessage) return;
    cancelImageryProbe();
    const current = tileProbeRevision;
    imageryEvent('imageryLoading');
    if (typeof root.Image !== 'function') {
      imageryEvent('imageryError', 'Survey tile checking is unsupported in this environment.');
      return;
    }
    let settled = false;
    const tile = new root.Image();
    const finish = (ok, detail) => {
      if (settled || current !== tileProbeRevision || fatalMessage) return;
      settled = true;
      if (tileProbeTimer !== null) root.clearTimeout(tileProbeTimer);
      tileProbeTimer = null;
      tile.onload = null;
      tile.onerror = null;
      if (ok) {
        imageryEvent('imageryReady');
      } else {
        imageryEvent('imageryError',
          'DSS2 Color survey imagery is unavailable (' + detail +
          '). Check the network or survey service, then retry.');
      }
    };
    tile.onload = () => finish(true);
    tile.onerror = () => finish(false, 'tile request failed');
    tileProbeTimer = root.setTimeout(() => finish(false, 'tile request timed out'), probeTimeoutMs);
    try {
      const p = aladin.getRaDec();
      const ra = Array.isArray(p) ? p[0] : p.ra;
      const dec = Array.isArray(p) ? p[1] : p.dec;
      tile.src = surveyBase + '/Norder0/Dir0/Npix' + rootTileIndex(ra, dec) + '.jpg';
    } catch (error) {
      finish(false, 'tile check could not start');
    }
  }

  function scheduleImageryProbe() {
    if (!ready || imageryStatus === 'imageryError') return;
    if (viewProbeTimer !== null) root.clearTimeout(viewProbeTimer);
    viewProbeTimer = root.setTimeout(() => {
      viewProbeTimer = null;
      probeImagery();
    }, 1500);
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
      scheduleImageryProbe();
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
          target:'10.6847 41.2688', fov:3, projection:'TAN',
          survey:surveyBase, cooFrame:'ICRS',
          showReticle:true, showFullscreenControl:false,
        });
        aladin.on('positionChanged', scheduleViewReport);
        aladin.on('zoomChanged', scheduleViewReport);
        ready = true;
        report('ready');
        if (queued) { const pending = queued; queued = null; receive(pending); }
        scheduleViewReport();
        probeImagery();
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
  root.AstroManagerAtlas = { boot, receive, fatal, rootTileIndex };
})(window);
