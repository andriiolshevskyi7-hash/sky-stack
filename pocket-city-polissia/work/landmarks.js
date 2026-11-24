/* Хряськ (Волинь): no famous buildings here. Two hand-made parts:
   - furrows on the ploughed strips traced from the satellite photo (drawn along each strip's long side);
   - the Kupala bonfire in the meadow east of the yard (Kupala Night scene only). Wikipedia "Kupala Night": the
     youths set up a tall pyramid of brushwood with a pole in the middle carrying a wheel or, in Polesia, a horse or
     cow skull; fires were lit late in the evening and burned until morning; couples jumped over the fire.
   Where the fire stands is illustrative. */

function furrows(ring) {
  // the strip's long side gives the furrow direction
  let best = 0, dir = [1, 0];
  ring.forEach((a, i) => { const b = ring[(i + 1) % ring.length], l = Math.hypot(b[0] - a[0], b[1] - a[1]); if (l > best) { best = l; dir = [(b[0] - a[0]) / l, (b[1] - a[1]) / l]; } });
  const nrm = [-dir[1], dir[0]], proj = p => p[0] * nrm[0] + p[1] * nrm[1], along = p => p[0] * dir[0] + p[1] * dir[1];
  const v0 = Math.min(...ring.map(proj)), v1 = Math.max(...ring.map(proj)), u0 = Math.min(...ring.map(along)), u1 = Math.max(...ring.map(along));
  const lines = [];
  for (let v = v0 + .4; v < v1 - .2; v += .75) {
    // clip the line u0..u1 at offset v to the ring (rings here are near-rectangles: test samples)
    const pts = []; let on = false, start = 0;
    for (let u = u0; u <= u1 + .01; u += .5) {
      const p = [dir[0] * u + nrm[0] * v, dir[1] * u + nrm[1] * v], inn = inside(p, ring);
      if (inn && !on) { on = true; start = u; } else if (!inn && on) { on = false; pts.push([start, u - .5]); }
    }
    if (on) pts.push([start, u1]);
    for (const [a, b] of pts) if (b - a > 1) lines.push([[dir[0] * a + nrm[0] * v, dir[1] * a + nrm[1] * v, .03], [dir[0] * b + nrm[0] * v, dir[1] * b + nrm[1] * v, .03]]);
  }
  return obj(ring, .05, () => {
    if (UPX > .9 || SEASON.snow) return '';
    const col = SEASON.id === 'spring' ? '#8a6e52' : SEASON.id === 'summer' || SEASON.id === 'kupala' ? '#7d8f4e' : '#8f7359';
    return lines.map(l => edge(l[0], l[1], col, UPX < .35 ? .16 : .12)).join('');
  });
}

const LANDMARKS = [
  { name: 'Ниви', ids: [], build: () => (SCENE.sand || []).map(rs => rs[0] && rs[0].length > 2 ? furrows(rs[0]) : null).filter(Boolean) },
];

const FIRE = [40, 22];
let KUPALA = null;
function kupalaBuild() {
  const [x, y] = FIRE, out = [];
  const logs = [];
  for (let i = 0; i < 22; i++) { const a = i * 2 * Math.PI / 22 + .1; logs.push({ a: [x + Math.cos(a) * 2.2, y + Math.sin(a) * 2.2, 0], b: [x + Math.cos(a) * .3, y + Math.sin(a) * .3, 4.2], r: .1, c: i % 3 ? '#7d6a4f' : '#94805f' }); }
  for (let i = 0; i < 14; i++) { const a = i * 2 * Math.PI / 14 + .35; logs.push({ a: [x + Math.cos(a) * 1.4, y + Math.sin(a) * 1.4, 0], b: [x + Math.cos(a) * .2, y + Math.sin(a) * .2, 5], r: .09, c: '#6e5c44' }); }
  const tongue = (cx, cy, z0, H, R, col, t, k) => {
    const sway = Math.sin(t * .0035 + k * 1.9) * .35, rings = [];
    for (let j = 0; j <= 6; j++) { const u = j / 6, r = Math.max(.02, R * Math.pow(Math.sin(Math.PI * Math.min(.98, u * .92 + .04)), .8) * (1 - u * .55));
      rings.push(polygon(cx + sway * u * u, cy + sway * .6 * u * u, r, 7, k).map(p => [...p, z0 + H * u])); }
    let s = ''; for (let j = 0; j < 6; j++) s += loft(rings[j], rings[j + 1], () => col);
    return s;
  };
  out.push({ fp: rect(x, y, 6, 6), h: 12, draw: t => {
    let s = SEASON.night ? lightPool(x, y, 13, '#ffb85c', .75) : '';
    s += shape(atZ(polygon(x, y, 2.5, 16), .02), '#5a4a3e', .2);
    const parts = logs.map(l => ({ d: depthOf([(l.a[0] + l.b[0]) / 2, (l.a[1] + l.b[1]) / 2, 1.5]), svg: stick(l.a, l.b, l.r, l.c) }));
    // the pole with a cartwheel on top
    parts.push({ d: depthOf([x, y, 4]), svg: stick([x, y, 0], [x, y, 8], .09, '#3a2e26') +
      loft(polygon(x, y, .75, 14).map(p => [p[0], p[1], 8]), polygon(x, y, .75, 14).map(p => [p[0], p[1], 8.18]), () => '#4a3a2e') +
      Array.from({ length: 6 }, (_, k) => { const a = k * Math.PI / 3; return stick([x, y, 8.1], [x + Math.cos(a) * .72, y + Math.sin(a) * .72, 8.1], .035, '#4a3a2e'); }).join('') });
    s += parts.sort((p, q) => p.d - q.d).map(p => p.svg).join('');
    const fl = [[0, 0, 4.4, 1.5, '#f26a2e'], [.7, .3, 3.3, 1.1, '#ff8a3d'], [-.7, .5, 3.6, 1.1, '#f26a2e'], [.2, -.8, 3.0, 1.0, '#ff8a3d'], [0, 0, 3.0, .9, '#ffc069'], [.3, .3, 2.2, .6, '#fde9b0']];
    s += fl.map(([dx, dy, H, R, c], k) => ({ dx, dy, H, R, c, k })).sort((p, q) => depthOf([x + p.dx, y + p.dy, 3]) - depthOf([x + q.dx, y + q.dy, 3]) + (p.k > 3) - (q.k > 3))
      .map(f => tongue(x + f.dx * .7, y + f.dy * .7, 2.2 + (f.k % 3) * .4, f.H * 1.2 * (.85 + .2 * Math.abs(Math.sin(t * .004 + f.k * 1.3))), f.R * 1.1, f.c, t, f.k)).join('');
    for (let k = 0; k < 5; k++) { const u = ((t * .0001 + k / 5) % 1), r = 1 + u * 2.6; s += lightPool(x + u * 3, y + u * 1.6, r, '#d9d3c8', .5 * (1 - u), 8 + u * 10); }
    return s;
  } });
  // villagers in a ring round the fire, facing it; a few pairs stand right at the edge, ready to jump
  for (let k = 0; k < 24; k++) {
    const a = k * 2 * Math.PI / 24 + (k % 3) * .15, r = 5.8 + (k % 3) * 1.2, px = x + Math.cos(a) * r, py = y + Math.sin(a) * r;
    if (!standable(px, py)) continue;
    const pd = { ...pedDressed(900 + k), p: [px, py], d: [-Math.cos(a), -Math.sin(a)], walked: 0, kind: 'ped', alpha: 1 };
    out.push({ fp: rect(px, py, .6, .6), h: 1.9, draw: t => pedestrian(pd, t).svg || '' });
  }
  // wreaths of flowers laid on the grass near the fire
  for (let k = 0; k < 6; k++) {
    const a = k * 1.1 + .4, px = x + Math.cos(a) * 4.2, py = y + Math.sin(a) * 4.2;
    out.push({ fp: rect(px, py, .5, .5), h: .2, draw: () => loft(polygon(px, py, .22, 10).map(p => [...p, .05]), polygon(px, py, .22, 10).map(p => [...p, .15]), () => k % 2 ? '#d64b3a' : '#f2d04b') + shape(atZ(polygon(px, py, .22, 10), .15), '#6f9f4c', .2) });
  }
  return out;
}
function CITY_EXTRA(t) {
  if (SEASON.id !== 'kupala') return [];
  if (!KUPALA) KUPALA = kupalaBuild();
  return KUPALA;
}
