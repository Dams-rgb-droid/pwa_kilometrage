/* Repérage de la ligne de chiffres d'un compteur sur une photo.
 * Entrée : image en niveaux de gris (Uint8Array, w x h). Sortie : zone recadrée prête
 * pour la reconnaissance (noir sur blanc), ou null. Sans dépendance. */
(function (root) {
  'use strict';

  // Filtre min (erosion) ou max (dilatation) rectangulaire k x k, séparable.
  function rectFilter(src, w, h, k, isMax) {
    var r = k >> 1, tmp = new Uint8Array(w * h), out = new Uint8Array(w * h);
    var x, y, i, v, a, b;
    for (y = 0; y < h; y++) {
      for (x = 0; x < w; x++) {
        a = Math.max(0, x - r); b = Math.min(w - 1, x + r);
        v = src[y * w + a];
        for (i = a + 1; i <= b; i++) { var s = src[y * w + i]; if (isMax ? s > v : s < v) v = s; }
        tmp[y * w + x] = v;
      }
    }
    for (x = 0; x < w; x++) {
      for (y = 0; y < h; y++) {
        a = Math.max(0, y - r); b = Math.min(h - 1, y + r);
        v = tmp[a * w + x];
        for (i = a + 1; i <= b; i++) { var t = tmp[i * w + x]; if (isMax ? t > v : t < v) v = t; }
        out[y * w + x] = v;
      }
    }
    return out;
  }

  function otsu(data) {
    var hist = new Array(256).fill(0), i, total = data.length;
    for (i = 0; i < total; i++) hist[data[i]]++;
    var sum = 0; for (i = 0; i < 256; i++) sum += i * hist[i];
    var sumB = 0, wB = 0, best = 0, thr = 0;
    for (i = 0; i < 256; i++) {
      wB += hist[i]; if (!wB) continue;
      var wF = total - wB; if (!wF) break;
      sumB += i * hist[i];
      var mB = sumB / wB, mF = (sum - sumB) / wF, between = wB * wF * (mB - mF) * (mB - mF);
      if (between > best) { best = between; thr = i; }
    }
    return thr;
  }

  // Composantes connexes (8 voisins) : retourne [{x,y,w,h,a}]
  function components(mask, w, h) {
    var seen = new Uint8Array(w * h), comps = [], stack = [], p, q;
    for (p = 0; p < w * h; p++) {
      if (!mask[p] || seen[p]) continue;
      var minx = w, maxx = 0, miny = h, maxy = 0, area = 0;
      stack.length = 0; stack.push(p); seen[p] = 1;
      while (stack.length) {
        q = stack.pop(); area++;
        var qx = q % w, qy = (q / w) | 0;
        if (qx < minx) minx = qx; if (qx > maxx) maxx = qx;
        if (qy < miny) miny = qy; if (qy > maxy) maxy = qy;
        for (var dy = -1; dy <= 1; dy++) {
          var ny = qy + dy; if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            var nx = qx + dx; if (nx < 0 || nx >= w) continue;
            var n = ny * w + nx;
            if (mask[n] && !seen[n]) { seen[n] = 1; stack.push(n); }
          }
        }
      }
      comps.push({ x: minx, y: miny, w: maxx - minx + 1, h: maxy - miny + 1, a: area });
    }
    return comps;
  }

  /* gray : niveaux de gris ; maxSide : plus grand côté de l'image (px).
   * Réglé pour des chiffres hauts d'environ 6 % du plus grand côté ; f adapte l'échelle. */
  function findDigitRow(gray, w, h, polarity) {
    var f = Math.max(w, h) / 1000;
    var odd = function (n) { n = Math.max(3, Math.round(n)); return n % 2 ? n : n + 1; };
    var g = gray;
    if (polarity === 'dark') { g = new Uint8Array(gray.length); for (var i = 0; i < g.length; i++) g[i] = 255 - gray[i]; }

    // Top-hat blanc : image - ouverture  (supprime reflets et dégradés, garde les traits fins clairs)
    var opened = rectFilter(rectFilter(g, w, h, odd(31 * f), false), w, h, odd(31 * f), true);
    var th = new Uint8Array(g.length);
    for (i = 0; i < th.length; i++) th[i] = Math.max(0, g[i] - opened[i]);
    var thr = otsu(th), bw = new Uint8Array(th.length);
    for (i = 0; i < th.length; i++) bw[i] = th[i] > thr ? 255 : 0;

    // Fermeture : relie les segments d'un même chiffre
    var k = odd(9 * f);
    var closed = rectFilter(rectFilter(bw, w, h, k, true), w, h, k, false);

    var mask = new Uint8Array(closed.length);
    for (i = 0; i < mask.length; i++) mask[i] = closed[i] ? 1 : 0;
    var all = components(mask, w, h);
    var comps = all.filter(function (c) {
      return c.h >= 25 * f && c.h <= 300 * f && c.w <= c.h * 1.3 && c.w >= c.h * 0.12 && c.a > 150 * f * f;
    });

    var best = [];
    comps.forEach(function (c) {
      var cy = c.y + c.h / 2;
      var grp = comps.filter(function (d) {
        return Math.abs(d.h - c.h) <= 0.25 * c.h && Math.abs(d.y + d.h / 2 - cy) <= 0.35 * c.h;
      });
      if (grp.length > best.length) best = grp;
    });
    if (best.length < 3) return null;

    var x0 = Infinity, y0 = Infinity, x1 = 0, y1 = 0;
    best.forEach(function (c) {
      x0 = Math.min(x0, c.x); y0 = Math.min(y0, c.y);
      x1 = Math.max(x1, c.x + c.w); y1 = Math.max(y1, c.y + c.h);
    });
    var pad = Math.round((y1 - y0) * 0.35);
    x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad);
    x1 = Math.min(w, x1 + pad); y1 = Math.min(h, y1 + pad);

    // Découpe, inversion (noir sur blanc) + marge blanche
    var cw = x1 - x0, ch = y1 - y0, m = 20, ow = cw + 2 * m, oh = ch + 2 * m;
    var out = new Uint8Array(ow * oh).fill(255);
    for (var y = 0; y < ch; y++) for (var x = 0; x < cw; x++) {
      out[(y + m) * ow + x + m] = 255 - closed[(y0 + y) * w + (x0 + x)];
    }
    return { data: out, width: ow, height: oh, digits: best.length };
  }

  root.kmOcrPrep = { findDigitRow: findDigitRow };
})(window);
