/* Plzeň, náměstí Republiky: hand-built landmarks.
   Katedrála sv. Bartoloměje (OSM w25129860). From cs.wikipedia "Katedrála svatého Bartoloměje": a hall church with
   three naves, four bays, a two-tower bay at the west, and a presbytery of two bays closed by five sides of a
   dodecagon. 58 m long, 30 m wide, vaults 25 m high. The north tower is 102.26 m; the south tower was never finished
   and its piers stop under the cornice that carries the roof. Cut sandstone ashlar, a saddle roof since 1528 (slate per
   OSM roof:material), the Šternberk chapel with a hipped roof south of the presbytery, the sacristy with a lean-to roof
   north of it, a pentagonal south porch and a rectangular north porch with a crenellated attic.
   The parts below are laid out on the OSM outline's own axes (u east, v north). Wall heights other than the vaults,
   the tower's storeys, gallery and spire are drawn by eye: say so in the notes.
   Town Hall (w45195273): Renaissance, 3 storeys, sgraffito by Jan Koula (1910). Gables and turret drawn by eye.
   Marian plague column (w1103555254): 1681, six steps, balustrade, the Madonna facing east.
   Fountains by Ondřej Císler (2010), OSM height 4.5 m, gilded: simplified. */

const CATH_PARTS = ['w1279303735', 'w1279303736', 'w1279303737', 'w1279303738', 'w1279303749', 'w1279303750', 'w1279303751', 'w1279303752', 'w1279303754', 'w1280200592', 'w1280200593', 'w1280200594', 'w1582428626', 'r17552543'];
const PIERS = ['w1279303751', 'w1279303752', 'w1279303754'];   // the tower's corner buttresses, 55 m (OSM)
const CATH = 'w25129860', RADNICE = 'w45195273', SLOUP = 'w1103555254';
const STONE = '#cbbfa6', STONE_D = '#b9ab90', SLATE = '#5d6066', SPIRE = '#6b8a7c', GLASSY = '#4c5559', GOLD = '#d9ae45';

const face4 = (q, col, ink = .5) => { const n = vNewell(q); return n && vis(n) ? shape(q, tone(n, soft(col)), ink) : ''; };
// a pointed (Gothic) opening on a wall face: base point o, along unit d (horizontal), outward n; centre s, width w, z0..z1 (springing)
function lancetPts(o, d, s, w, z0, z1, off = .04, nrm = [0, 0]) {
  const P = (x, z) => [o[0] + d[0] * x + nrm[0] * off, o[1] + d[1] * x + nrm[1] * off, z];
  const pts = [P(s - w / 2, z0), P(s + w / 2, z0), P(s + w / 2, z1)];
  // equilateral arch: each side an arc centred on the opposite springer
  for (let k = 1; k <= 5; k++) { const a = k / 6 * Math.PI / 3; pts.push(P(s - w / 2 + Math.cos(a) * w, z1 + Math.sin(a) * w)); }
  pts.push(P(s, z1 + w * .866));
  for (let k = 5; k >= 1; k--) { const a = k / 6 * Math.PI / 3; pts.push(P(s + w / 2 - Math.cos(a) * w, z1 + Math.sin(a) * w)); }
  pts.push(P(s - w / 2, z1));
  return pts;
}
// stone walls round a ring with pointed windows: opts.win = {w, z0, z1, bay, min}
function gothicWalls(ring, z0, z1, opts = {}) {
  const r = ccw(ring), col = opts.col || STONE;
  return () => {
    const faces = r.map((a, i) => { const b = r[(i + 1) % r.length]; return { a, b, n: vNewell([[...a, z0], [...b, z0], [...b, z1]]) }; })
      .filter(f => f.n && vis(f.n)).sort((p, q) => depthOf([...p.a, 0]) - depthOf([...q.a, 0]));
    let s = '';
    for (const f of faces) {
      const { a, b } = f, len = Math.hypot(b[0] - a[0], b[1] - a[1]); if (len < .05) continue;
      const d = [(b[0] - a[0]) / len, (b[1] - a[1]) / len], nrm = [d[1], -d[0]];
      s += shape([[...a, z0], [...b, z0], [...b, z1], [...a, z1]], tone(f.n, soft(col)), .6);
      s += shape([[...a, z0], [...b, z0], [...b, z0 + .9], [...a, z0 + .9]], tone(f.n, soft(STONE_D)), .3);   // plinth
      const w = opts.win;
      if (w && len >= (w.min || 4)) {
        const n = Math.max(1, Math.round(len / (w.bay || 8)));
        for (let k = 0; k < n; k++) {
          const sc = (k + .5) * len / n, ww = Math.min(w.w, len / n * .55);
          s += shape(lancetPts(a, d, sc, ww + .5, w.z0 - .25, w.z1, .03, nrm), tone(f.n, soft(STONE_D)), .3);
          s += shape(lancetPts(a, d, sc, ww, w.z0, w.z1, .06, nrm), SEASON.night ? '#e9c477' : GLASSY, .3);
          if (UPX < .45) for (let m = 1; m < 3; m++) { const x = sc - ww / 2 + ww * m / 3, P = z => [a[0] + d[0] * x + nrm[0] * .08, a[1] + d[1] * x + nrm[1] * .08, z];
            s += edge(P(w.z0), P(w.z1 + ww * .3), STONE_D, .07); }
        }
      }
      if (opts.cornice) s += shape([[...a, z1 - .5], [...b, z1 - .5], [...b, z1], [...a, z1]], tone(f.n, soft(STONE_D)), .35);
    }
    if (opts.lid !== false) s += shape(atZ(r, z1), opts.lidCol || STONE_D, .4);
    return s;
  };
}

function cathedral() {
  const B = findBuilding(CATH); if (!B) return null;
  const { c, ax } = B.obb, nx = [-ax[1], ax[0]];
  const P2 = (u, v) => [c[0] + ax[0] * u + nx[0] * v, c[1] + ax[1] * u + nx[1] * v];
  const P3 = (u, v, z) => [...P2(u, v), z];
  const R = (u0, u1, v0, v1) => [P2(u0, v0), P2(u1, v0), P2(u1, v1), P2(u0, v1)];
  const W0 = -28.8, TW = -18.9, PR = 12.1, VS = -12.0, VN = 14.2, EAVES = 29, RISE = 20;

  // the hall of three naves (bays east of the tower bay)
  const hallR = R(TW, PR, VS, VN);
  const hallW = gothicWalls(hallR, 0, EAVES, { win: { w: 2.8, z0: 5, z1: 17, bay: 8 }, cornice: true });
  const hallRoof = roofOver({ c: P2((TW + PR) / 2, (VS + VN) / 2), ax, L: PR - TW, W: VN - VS }, EAVES,
    { roof: 'gabled', pitch: Math.atan(RISE / ((VN - VS) / 2 + .4)) * 180 / Math.PI, roofColour: SLATE, roofTex: 'slate', eaves: .4, wall: STONE });
  // buttresses along both long sides, drawn with the side they stand on
  const butt = [];
  for (const u of [TW + 8, TW + 16, TW + 24]) for (const [v0, v1] of [[VS - 1.8, VS], [VN, VN + 1.8]]) butt.push({ r: R(u - .75, u + .75, v0, v1), side: v0 < VS ? -1 : 1 });
  const buttDraw = side => () => {
    let s = ''; const ns = [nx[0] * side, nx[1] * side, 0];
    if (!vis(ns)) return '';
    for (const b of butt.filter(b => b.side === side).sort((p, q) => depthOf([...p.r[0], 0]) - depthOf([...q.r[0], 0]))) {
      const rr = ccw(b.r);
      rr.forEach((a, i) => { const e = rr[(i + 1) % 4]; s += face4([[...a, 0], [...e, 0], [...e, 17], [...a, 17]], STONE); });
      // sloped top falling outward
      const inner = side < 0 ? [b.r[2], b.r[3]] : [b.r[0], b.r[1]], outer = side < 0 ? [b.r[1], b.r[0]] : [b.r[3], b.r[2]];
      const top = [[...outer[0], 17], [...outer[1], 17], [...inner[0], 19.5], [...inner[1], 19.5]];
      s += face4(top, STONE_D, .4) + face4(top.slice().reverse(), STONE_D, .4);
    }
    return s;
  };

  // west bay between the towers, with its own gable over the middle nave
  const midR = R(W0, TW, -2.4, 4.6);
  const midW = gothicWalls(midR, 0, EAVES + 2, { win: { w: 3.2, z0: 8, z1: 18, bay: 10, min: 6 }, cornice: true });
  const midRoof = roofOver({ c: P2((W0 + TW) / 2, 1.1), ax, L: TW - W0, W: 7 }, EAVES + 2, { roof: 'gabled', pitch: 55, roofColour: SLATE, roofTex: 'slate', eaves: .3, wall: STONE });
  const portal = () => {   // the pointed west portal with the window above it
    const o = P2(W0 - .02, 4.6), d = [-nx[0], -nx[1]], nrm = [-ax[0], -ax[1]];
    if (!vis([nrm[0], nrm[1], 0])) return '';
    return shape(lancetPts(o, d, 3.5, 4.4, 0, 4.2, .05, nrm), tone([nrm[0], nrm[1], 0], soft(STONE_D)), .4) +
           shape(lancetPts(o, d, 3.5, 3.0, 0, 3.8, .08, nrm), '#4a3a30', .35);
  };

  // the unfinished south tower: piers to the cornice under the roof, closed by a low pyramid cap
  const stR = R(W0, TW, VS, -2.4);
  const stW = gothicWalls(stR, 0, EAVES + 3, { win: { w: 1.6, z0: 12, z1: 17, bay: 9, min: 6 }, cornice: true });
  const stCap = roofOver({ c: P2((W0 + TW) / 2, (VS - 2.4) / 2), ax, L: TW - W0, W: -2.4 - VS }, EAVES + 3, { roof: 'pyramidal', pitch: 30, roofColour: SLATE, roofTex: 'slate', eaves: .2 });

  // the north tower: square shaft with stepped cornices, belfry, clocks, a gallery, then the octagonal spire
  const ntR = R(W0, TW, 4.6, VN), nc = P2((W0 + TW) / 2, (4.6 + VN) / 2), S = 9.8;
  const SHAFT = 60, GAL = 61.2;
  const tower = () => {
    let s = '';
    const sq = (half, z) => ccw([P2((W0 + TW) / 2 - half, (4.6 + VN) / 2 - half), P2((W0 + TW) / 2 + half, (4.6 + VN) / 2 - half), P2((W0 + TW) / 2 + half, (4.6 + VN) / 2 + half), P2((W0 + TW) / 2 - half, (4.6 + VN) / 2 + half)]).map(p => [...p, z]);
    const stage = (half, z0, z1, wins) => {
      const lo = sq(half, z0), hi = sq(half, z1);
      const fs = lo.map((a, i) => ({ q: [a, lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]] })).filter(f => { const m = vNewell(f.q); return m && vis(m); });
      for (const f of fs) {
        s += face4(f.q, STONE, .55);
        const n = vNewell(f.q), L = (z, t) => [f.q[0][0] + (f.q[1][0] - f.q[0][0]) * t + n[0] * .05, f.q[0][1] + (f.q[1][1] - f.q[0][1]) * t + n[1] * .05, z];
        if (wins) for (const t of wins.at) {
          const len = half * 2, o = f.q[0], d = [(f.q[1][0] - o[0]) / len, (f.q[1][1] - o[1]) / len];
          s += shape(lancetPts(o, d, t * len, wins.w, wins.z0, wins.z1, .05, [n[0], n[1]]), SEASON.night ? '#e9c477' : GLASSY, .3);
        }
        if (wins && wins.clock) { const cz = z1 - 1.6, o = L(cz, .5); s += shape(Array.from({ length: 14 }, (_, k) => { const a = k / 14 * 2 * Math.PI, dd = [(f.q[1][0] - f.q[0][0]) / (half * 2), (f.q[1][1] - f.q[0][1]) / (half * 2)]; return [o[0] + dd[0] * Math.cos(a) * 1.2, o[1] + dd[1] * Math.cos(a) * 1.2, cz + Math.sin(a) * 1.2]; }), '#2f3a3a', .3); }
      }
      // a cornice band and a lid on every stage
      const lo2 = sq(half + .35, z1 - .5), hi2 = sq(half + .35, z1);
      lo2.forEach((a, i) => s += face4([a, lo2[(i + 1) % 4], hi2[(i + 1) % 4], hi2[i]], STONE_D, .35));
      s += shape(hi2, STONE_D, .35);
    };
    stage(S / 2, 0, 16, { at: [.5], w: 1.4, z0: 6, z1: 11 });
    stage(S / 2 - .4, 16, 30, { at: [.5], w: 1.2, z0: 21, z1: 25 });
    stage(S / 2 - .7, 30, 44, { at: [.5], w: 1.2, z0: 35, z1: 39 });
    stage(S / 2 - 1.0, 44, SHAFT, { at: [.3, .7], w: 1.5, z0: 46.5, z1: 53, clock: true });
    // gallery: a low parapet on the shaft top, the spire rising inside it
    const g0 = sq(S / 2 - .7, SHAFT), g1 = sq(S / 2 - .7, GAL);
    g0.forEach((a, i) => s += face4([a, g0[(i + 1) % 4], g1[(i + 1) % 4], g1[i]], STONE_D, .35));
    const oct = (r, z) => polygon(nc[0], nc[1], r, 8, Math.PI / 8).map(p => [...p, z]);
    const sp = [[3.6, GAL - 1.2], [3.2, 66], [2.5, 74], [1.9, 80]];
    for (let k = 0; k < sp.length - 1; k++) s += loft(oct(sp[k][0], sp[k][1]), oct(sp[k + 1][0], sp[k + 1][1]), n => tone(n, soft(SPIRE)));
    s += loft(oct(1.9, 80), oct(1.9, 83), n => tone(n, soft('#6d7c76'))) + shape(oct(2.3, 83), '#55625d', .4);   // lantern
    const sp2 = [[2.1, 83], [1.5, 88], [.8, 94], [.25, 99.6]];
    for (let k = 0; k < sp2.length - 1; k++) s += loft(oct(sp2[k][0], sp2[k][1]), oct(sp2[k + 1][0], sp2[k + 1][1]), n => tone(n, soft(SPIRE)));
    s += peak(polygon(nc[0], nc[1], .25, 8, Math.PI / 8), 99.6, [nc[0], nc[1], 100.6], SPIRE);
    s += stick([nc[0], nc[1], 100.6], [nc[0], nc[1], 102.26], .06, GOLD) + stick([nc[0] - .45 * ax[0], nc[1] - .45 * ax[1], 101.6], [nc[0] + .45 * ax[0], nc[1] + .45 * ax[1], 101.6], .05, GOLD) + ball([nc[0], nc[1], 100.7], .2, soft(GOLD), .3);
    return s;
  };

  // the presbytery: two bays and five sides of a dodecagon; hipped roof over it
  const PE = 24.0, PV0 = -4.4, PV1 = 6.6, PR_R = (PV1 - PV0) / 2, PVC = (PV0 + PV1) / 2;
  const apse = [];
  for (let k = 0; k <= 5; k++) { const a = -Math.PI / 2 + k * Math.PI / 5; apse.push(P2(PE + Math.cos(a) * PR_R * 1.05, PVC + Math.sin(a) * PR_R)); }
  const presR = [P2(PR, PV0), ...apse, P2(PR, PV1)];
  const presW = gothicWalls(presR, 0, 28, { win: { w: 1.9, z0: 7, z1: 20, bay: 5, min: 3.5 }, cornice: true });
  const presRoof = roofOver({ c: P2((PR + PE + PR_R * .9) / 2, PVC), ax, L: PE + PR_R * .95 - PR, W: PV1 - PV0 }, 28, { roof: 'hipped', pitch: 63, roofColour: SLATE, roofTex: 'slate', eaves: .3 });

  // Šternberk chapel (south of the presbytery, hipped roof), the sacristy (north, lean-to), the two porches
  const chR = R(PR, 21.9, VS + .3, PV0);
  const chW = gothicWalls(chR, 0, 13, { win: { w: 1.9, z0: 4.5, z1: 9.5, bay: 4.5, min: 3 }, cornice: true });
  const chRoof = roofOver({ c: P2((PR + 22) / 2, (VS + .2 + PV0) / 2), ax, L: 21.9 - PR, W: PV0 - VS - .3 }, 13, { roof: 'hipped', pitch: 60, roofColour: SLATE, roofTex: 'slate', eaves: .3 });
  const saR = R(PR - .4, 21.6, PV1, VN);
  const saW = gothicWalls(saR, 0, 13, { win: { w: 1.1, z0: 3, z1: 6, bay: 4, min: 3 }, lid: false });
  const saRoof = () => {   // lean-to falling north, closed at both ends
    const a = P3(PR - .4, PV1, 20), b = P3(21.6, PV1, 20), cc = P3(21.6, VN + .3, 13), d = P3(PR - .4, VN + .3, 13);
    let s = face4([d, cc, b, a], SLATE, .5) + face4([a, b, cc, d], SLATE, .5);
    s += face4([P3(21.6, PV1, 13), P3(21.6, VN, 13), P3(21.6, PV1, 20)], STONE) + face4([P3(PR - .4, VN, 13), P3(PR - .4, PV1, 13), P3(PR - .4, PV1, 20)], STONE);
    return s;
  };
  const npR = R(-12.5, -3.5, VN, VN + 4);
  const npW = gothicWalls(npR, 0, 7, { win: { w: 1.6, z0: 0, z1: 3, bay: 4.5, min: 6 }, cornice: true, lidCol: SLATE });
  const spR = [P2(-11.3, VS), P2(-3.5, VS), P2(-3.5, -14.6), P2(-7.3, -17.6), P2(-11.3, -14.6)];
  const spW = gothicWalls(spR, 0, 4.5, { win: { w: 1.5, z0: 0, z1: 3, bay: 4, min: 3.5 }, lid: false });
  const spRoof = () => peak(ccw(spR), 4.5, [...P2(-7.4, -14.6), 6.5], '#6b8a7c');

  const hallTop = EAVES + RISE;
  const parts = [
    { fp: hallR, z1: hallTop, draw: () => hallW() + buttDraw(-1)() + buttDraw(1)() + hallRoof() },
    { fp: midR, z1: EAVES + 8, draw: () => midW() + portal() + midRoof() },
    { fp: stR, z1: EAVES + 6, draw: () => stW() + stCap() },
    { fp: ntR, z1: 102.3, draw: tower },
    { fp: presR, z1: 40, draw: () => presW() + presRoof() },
    { fp: chR, z1: 20, draw: () => chW() + chRoof() },
    { fp: saR, z1: 20, draw: () => saW() + saRoof() },
    ...PIERS.map(id => { const pb = findBuilding(id); if (!pb) return null; const pw = gothicWalls(pb.ring, 0, 52, { cornice: true }); return { fp: pb.ring, z1: 52, draw: () => pw() + peak(ccw(pb.ring), 52, [...avg(pb.ring.map(q => [...q, 0])).slice(0, 2), 55], STONE_D) }; }).filter(Boolean),
    { fp: npR, z1: 7.5, draw: npW },
    { fp: spR, z1: 6.5, draw: () => spW() + spRoof() },
  ];
  const all = B.ring;
  return obj(all, 102.3, () => planOrder(parts.map(p => ({ fp: p.fp, z1: p.z1, svg: p.draw() }))));
}

/* Town Hall: front range on the square with a gable attic and a roof turret; the rear wing plain. */
function radnice() {
  const B = findBuilding(RADNICE); if (!B) return null;
  const front = [[-25.35, 64.1], [-4.46, 63.09], [-1.75, 95.04], [-13.37, 95.87], [-22.87, 89.04], [-26.24, 89.32]];
  const back = [[-22.87, 89.04], [-13.37, 95.87], [-11.01, 124.17], [-20.12, 124.99], [-20.94, 110.7]];
  const WALL = 15.5, WALLC = '#ece6d9', SGR = '#8c8a86';
  const st = { facade: 'civic', wall: [WALLC], trim: '#f7f3ea', floor: 5.1, bay: 3.4, shop: 'none' };
  const fb = block(front, 0, WALL, st), bb = block(back, 0, 12, { ...st, floor: 4, top: '#c8bfb0' });
  // ridge parallel to the square front (front edge runs from [-25.35,64.1] to [-4.46,63.09])
  const fx = [-4.46 + 25.35, 63.09 - 64.1], fl = Math.hypot(...fx), ux = [fx[0] / fl, fx[1] / fl], uy = [-ux[1], ux[0]];
  const depth = 25, cx = (-25.35 - 4.46) / 2 + uy[0] * depth / 2, cy = (64.1 + 63.09) / 2 + uy[1] * depth / 2;
  const roof = roofOver({ c: [cx, cy], ax: ux, L: fl, W: depth }, WALL, { roof: 'hipped', pitch: 42, roofColour: ['#9c4f3b'], roofTex: 'tiles', eaves: .4 });
  const o = [-25.35, 64.1], n = [-uy[0], -uy[1]];
  const F = (x, z, off = .05) => [o[0] + ux[0] * x + n[0] * off, o[1] + ux[1] * x + n[1] * off, z];
  const attic = () => {   // the front attic: a wall above the cornice crowned by four semicircular gables with obelisks
    if (!vis([n[0], n[1], 0])) return '';
    const tn = tone([n[0], n[1], 0], soft(WALLC)), tg = tone([n[0], n[1], 0], soft('#e2dbcc'));
    let s = shape([F(0, WALL), F(fl, WALL), F(fl, WALL + 2.6), F(0, WALL + 2.6)], tn, .5);
    const g = 4, gw = fl / g;
    for (let k = 0; k < g; k++) {
      const x0 = k * gw + .6, x1 = (k + 1) * gw - .6, mid = (x0 + x1) / 2, r = (x1 - x0) / 2;
      const pts = [F(x0, WALL + 2.6), F(x1, WALL + 2.6), F(x1, WALL + 4.6)];
      for (let j = 1; j < 12; j++) { const a = j / 12 * Math.PI; pts.push(F(mid + Math.cos(a) * r, WALL + 4.6 + Math.sin(a) * r * .9)); }
      pts.push(F(x0, WALL + 4.6));
      s += shape(pts, tg, .45);
      if (UPX < .6) s += shape(Array.from({ length: 12 }, (_, j) => { const a = j / 12 * 2 * Math.PI; return F(mid + Math.cos(a) * .7, WALL + 5.0 + Math.sin(a) * .7, .08); }), '#7e7a72', .25);
    }
    for (let k = 0; k <= g; k++) { const x = Math.min(fl - .3, Math.max(.3, k * gw)), b = F(x, WALL + 2.6, .3);
      s += stick(b, [b[0], b[1], WALL + 6.4], .22, '#d9d2c2') + ball([b[0], b[1], WALL + 6.6], .25, soft('#d9d2c2'), .3); }
    // sgraffito: a band of grey panels between the storeys, and the portal
    if (UPX < .5) for (let z = 4.6; z < WALL - 1; z += 5.1) for (let x = .5; x < fl - .5; x += 1.1) s += shape([F(x, z), F(x + .8, z), F(x + .8, z + .45), F(x, z + .45)], SGR, 0);
    s += shape([F(fl / 2 - 1.4, 0), F(fl / 2 + 1.4, 0), F(fl / 2 + 1.4, 3.8), F(fl / 2 - 1.4, 3.8)], '#4f4038', .35);
    return s;
  };
  const turret = () => {   // a slim clock turret on the ridge
    const t = [cx, cy], top = WALL + Math.tan(42 * Math.PI / 180) * (depth / 2 + .4);
    let s = '';
    const sq = (h, z) => [[-h, -h], [h, -h], [h, h], [-h, h]].map(([a, b]) => [t[0] + ux[0] * a + uy[0] * b, t[1] + ux[1] * a + uy[1] * b, z]);
    const lo = sq(1.3, top - 3), hi = sq(1.3, top + 3.5);
    lo.forEach((a, i) => s += face4([a, lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]], WALLC, .4));
    s += shape(hi, '#d9d2c2', .3);
    const oc = (r, z) => polygon(t[0], t[1], r, 8, Math.PI / 8).map(p => [...p, z]);
    s += loft(oc(1.1, top + 3.5), oc(1.1, top + 5.5), m => tone(m, soft(WALLC))) + shape(oc(1.1, top + 5.5), '#4f6058', .3);
    s += loft(oc(1.1, top + 5.5), oc(.55, top + 7), m => tone(m, soft('#4f6058'))) + peak(polygon(t[0], t[1], .55, 8, Math.PI / 8), top + 7, [t[0], t[1], top + 9.5], '#4f6058');
    s += stick([t[0], t[1], top + 9.5], [t[0], t[1], top + 10.6], .05, GOLD);
    return s;
  };
  const parts = [
    { fp: back, z1: 12.5, svg: null, draw: bb.draw },
    { fp: front, z1: WALL + 18, svg: null, draw: () => fb.draw() + roof() + turret() + attic() },
  ];
  return obj(B.ring, WALL + 18, () => planOrder(parts.map(p => ({ fp: p.fp, z1: p.z1, svg: p.draw() }))));
}

/* The Marian plague column: six steps, a balustrade with a gate on the east, a pedestal, the shaft and the Madonna. */
function sloup() {
  const B = findBuilding(SLOUP); if (!B) return null;
  const c = avg(B.ring.map(p => [...p, 0])).slice(0, 2), r = ccw(B.ring);
  const sq = (h, z) => [[-h, -h], [h, -h], [h, h], [-h, h]].map(([a, b]) => [c[0] + a, c[1] + b, z]);
  const box = (h, z0, z1, col) => { const lo = sq(h, z0), hi = sq(h, z1); let s = ''; lo.forEach((a, i) => s += face4([a, lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]], col, .4)); return s + shape(hi, tone([0, 0, 1], soft(col)), .35); };
  const SAND = '#d2c6ad';
  return obj(r, 17, () => {
    let s = '';
    for (let k = 0; k < 6; k++) s += box(4.3 - k * .3, k * .2, (k + 1) * .2, '#bdb4a2');
    const z = 1.2;
    // balustrade: little posts round the platform
    for (let i = 0; i < 4; i++) for (let t = 0; t <= 1; t += 1 / 8) {
      const cs = sq(2.6, 0), a = cs[i], b = cs[(i + 1) % 4], p = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
      s += stick([p[0], p[1], z], [p[0], p[1], z + .95], .07, SAND);
    }
    s += box(1.15, z, z + 3.4, SAND) + box(1.35, z + 3.4, z + 3.8, '#c4b79c');
    s += loft(polygon(c[0], c[1], .5, 10).map(p => [...p, z + 3.8]), polygon(c[0], c[1], .42, 10).map(p => [...p, z + 12.5]), m => tone(m, soft(SAND)));
    s += box(.75, z + 12.5, z + 13.1, '#c4b79c');
    // the Madonna: a robed figure with a halo of gilded stars
    s += loft(polygon(c[0], c[1], .55, 10).map(p => [...p, z + 13.1]), polygon(c[0], c[1], .25, 10).map(p => [...p, z + 15]), m => tone(m, soft('#d8cdb6')));
    s += ball([c[0], c[1], z + 15.3], .28, soft('#d8cdb6'), .3) + ball([c[0], c[1], z + 15.9], .12, soft(GOLD), .2);
    return s;
  });
}

/* Ondřej Císler's three gilded fountains (2010): a dark basin and a golden animal form, 4.5 m high (OSM). Simplified. */
const FOUNTAINS = [
  { name: 'Chrtice (greyhound)', x: -58.4, y: -89.5, w: 4.1, d: 2.9, form: 'dog' },
  { name: 'Velbloud (camel)', x: 19.2, y: -96.1, w: 5.7, d: 5.7, form: 'camel', mappedWater: true },
  { name: 'Anděl (angel)', x: 30.6, y: 30.1, w: 7.5, d: 3.1, form: 'angel' },
];
function fountain(F) {
  const ring = rect(F.x, F.y, F.w + .6, F.d + .6);
  return obj(ring, 4.8, () => {
    let s = '';
    if (!F.mappedWater) {
      const rr = ccw(rect(F.x, F.y, F.w, F.d));
      rr.forEach((a, i) => s += face4([[...a, 0], [...rr[(i + 1) % 4], 0], [...rr[(i + 1) % 4], .45], [...a, .45]], '#3a3c40', .4));
      s += shape(atZ(rr, .45), SEASON.snow ? '#e9eef2' : '#5e8f98', .3);
    }
    // a golden form on a dark plinth: body, neck and head, gilded
    const g = soft(GOLD), x = F.x, y = F.y;
    s += box3(x, y, .5, 0, 1.2, '#2f3134');
    if (F.form === 'angel') {
      s += loft(polygon(x, y, .55, 10).map(p => [...p, 1.2]), polygon(x, y, .25, 10).map(p => [...p, 3.6]), m => tone(m, g));
      for (const sd of [-1, 1]) s += shape([[x, y, 3.3], [x + sd * 1.6, y + .2, 4.4], [x + sd * 1.2, y + .1, 2.6]], tone([0, -1, .3], g), .3);
      s += ball([x, y, 3.95], .32, g, .3);
    } else {
      const long = F.form === 'camel' ? 1.1 : .9;
      s += loft(polygon(x, y, .35, 8).map(p => [...p, 1.2]), polygon(x, y, .3, 8).map(p => [...p, 2.4]), m => tone(m, g));
      s += loft(polygon(x - long * .2, y, .55, 10).map(p => [...p, 2.4]), polygon(x + long * .2, y, .45, 10).map(p => [...p, 3.2]), m => tone(m, g));
      if (F.form === 'camel') s += ball([x, y, 3.3], .45, g, .3);
      s += stick([x + long * .2, y, 3.2], [x + long * .55, y, 4.2], .18, GOLD) + ball([x + long * .7, y, 4.35], .26, g, .3);
    }
    return s;
  });
}
function box3(x, y, h, z0, z1, col) { const r = ccw(rect(x, y, h * 2, h * 2)); let s = ''; r.forEach((a, i) => s += face4([[...a, z0], [...r[(i + 1) % 4], z0], [...r[(i + 1) % 4], z1], [...a, z1]], col, .35)); return s + shape(atZ(r, z1), col, .3); }

const LANDMARKS = [
  { name: 'Katedrála sv. Bartoloměje', ids: [CATH, ...CATH_PARTS], build: cathedral },
  { name: 'Radnice', ids: [RADNICE], build: radnice },
  { name: 'Morový sloup', ids: [SLOUP], build: sloup },
  { name: 'Kašny', ids: [], build: () => FOUNTAINS.map(fountain) },
];

/* Christmas market: wooden huts round the square, a tall spruce with lights, a crowd. Layout and sizes illustrative. */
let XMAS = null;
function xmasBuild() {
  const huts = [], TREE = [2, 38];
  const add = (x, y, rotA) => {
    if (!standable(x, y, 1.5) || !standable(x + 1.6, y + 1.2, 1) || !standable(x - 1.6, y - 1.2, 1)) return;
    const r = rect(x, y, 3.2, 2.2);
    const b = block(r, 0, 2.3, { facade: 'plain', wall: ['#8a6446', '#7b5a40'], shop: 'none', top: '#6a4b35' });
    const roof = roofOver({ c: [x, y], ax: [1, 0], L: 3.2, W: 2.2 }, 2.3, { roof: 'gabled', pitch: 32, roofColour: ['#5f4330'], eaves: .25 });
    huts.push({ x, y, fp: r, h: 3.2, draw: t => {
      let s = b.draw() + roof();
      if (SEASON.night) for (let k = 0; k < 9; k++) { const p = [x - 1.6 + k * .4, y - 1.35, 2.25]; if (Math.sin(t * .003 + k * 1.7 + x) > -.5) s += stick(p, [p[0], p[1], p[2] + .02], .07, k % 2 ? '#fff3c4' : '#ffe7a8'); }
      return s;
    } });
  };
  for (let x = -38; x <= 40; x += 4.4) if (Math.abs(x - TREE[0]) > 7) add(x, 27, 0);
  for (let x = -38; x <= 40; x += 4.4) add(x, -32, 0);
  const crowd = [];
  for (let k = 0; k < 26; k++) {
    const a = k * 2 * Math.PI / 26, rr = 6.5 + (k % 3) * 1.3, px = TREE[0] + Math.cos(a) * rr, py = TREE[1] + Math.sin(a) * rr;
    if (!standable(px, py)) continue;
    const pd = { ...pedDressed(600 + k), p: [px, py], d: [-Math.cos(a), -Math.sin(a)], walked: 0, kind: 'ped', alpha: 1 };
    crowd.push({ fp: rect(px, py, .6, .6), h: 1.9, draw: t => pedestrian(pd, t).svg || '' });
  }
  for (const h of huts) for (const dy of [-2.2, 2.4]) {   // shoppers at the hut counters
    const px = h.x + ((h.x * 7) % 1.5), py = h.y + dy; if (!standable(px, py)) continue;
    const pd = { ...pedDressed(800 + Math.round(h.x * 3 + dy)), p: [px, py], d: [0, -Math.sign(dy)], walked: 0, kind: 'ped', alpha: 1 };
    crowd.push({ fp: rect(px, py, .6, .6), h: 1.9, draw: t => pedestrian(pd, t).svg || '' });
  }
  const [x, y] = TREE, H = 16, tiers = [[4.2, 1.2, 6.5], [3.4, 4.6, 9.8], [2.6, 8, 12.6], [1.8, 11.2, 14.8], [1, 13.6, H]];
  const lights = [];
  for (let i = 0; i < 320; i++) { const u = i / 320, z = 1.4 + u * (H - 2), r = 4.3 * (1 - (z - 1.2) / (H - .5)) + .12, a = i * 2.39; lights.push([x + Math.cos(a) * r, y + Math.sin(a) * r, z]); }
  const tree = { fp: rect(x, y, 8.6, 8.6), h: H + 1, draw: t => {
    let s = SEASON.night ? lightPool(x, y, 11, '#ffcf7a', .6) : '';
    s += stick([x, y, 0], [x, y, 1.4], .3, '#6e5440');
    for (const [r, z0, z1] of tiers) s += peak(polygon(x, y, r, 12), z0, [x, y, z1], '#3c6447');
    lights.forEach((p, i) => { if (!vis([p[0] - x, p[1] - y, .4])) return; if (Math.sin(t * .0025 + i * 2.1) > -.6) s += stick(p, [p[0], p[1], p[2] + .02], .12, i % 3 ? '#fff3c4' : '#ffe7a8'); });
    const sz = H + .8, star = (ux, uy) => Array.from({ length: 10 }, (_, k) => { const a = Math.PI / 2 + k * Math.PI / 5, r = k % 2 ? .35 : .85; return [x + ux * Math.cos(a) * r, y + uy * Math.cos(a) * r, sz + Math.sin(a) * r]; });
    return s + shape(star(1, 0), '#f6c445', .3) + shape(star(0, 1), '#f2c94c', .3);
  } };
  return [tree, ...huts, ...crowd];
}
function CITY_EXTRA(t) {
  if (SEASON.id !== 'advent') return [];
  if (!XMAS) XMAS = xmasBuild();
  return XMAS;
}
