"""Features traced from the user's Google Maps satellite screenshot (8533.jpg, 1008x2244 px).
Scale bar: 20 m = 146 px. Pin tip at (505, 1060) = 51.281688, 25.884056. The map is turned so that screen-up points to
bearing 22 deg (compass needle, and OSM's village road through the bend at the north-east matches at that angle).
Writes osm-traced.json in the Overpass 'out geom' form that plot.py and prep.py read."""
import json, math, time
LAT0, LON0, S, PIN, ROT = 51.281688, 25.884056, 20 / 146, (505, 1060), math.radians(22)
KX, KY = 111320 * math.cos(math.radians(LAT0)), 110574
def ll(px, py):
    r, u = (px - PIN[0]) * S, (PIN[1] - py) * S
    e, n = r * math.cos(ROT) + u * math.sin(ROT), -r * math.sin(ROT) + u * math.cos(ROT)
    return {'lat': LAT0 + n / KY, 'lon': LON0 + e / KX}
els, nid = [], [1]
def nextid(): nid[0] += 1; return -nid[0]
def way(pts, tags, closed=False):
    g = [ll(*p) for p in pts] + ([ll(*pts[0])] if closed else [])
    els.append({'type': 'way', 'id': nextid(), 'nodes': [], 'geometry': g, 'tags': tags})
def box(x0, y0, x1, y1, tags): way([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], tags, True)
def node(px, py, tags): els.append({'type': 'node', 'id': nextid(), **ll(px, py), 'tags': tags})

# buildings: (x0, y0, x1, y1, kind, roof colour as seen, roof shape)
B = [
 (285, 780, 380, 878, 'house', 'brown', 'hipped', 'H1 brown-roof house'),
 (318, 878, 348, 915, 'shed', 'lightgrey', 'flat', 'H1 porch'),
 (413, 870, 477, 958, 'house', 'lightgrey', 'gabled', 'H2 grey-roof house'),
 (220, 810, 250, 923, 'shed', 'grey', 'gabled', 'S1 long shed by the road'),
 (232, 722, 292, 748, 'shed', 'grey', 'gabled', 'S2 shed'),
 (277, 1097, 380, 1173, 'house', 'lightgrey', 'gabled', 'H3 house, west'),
 (380, 1120, 400, 1160, 'shed', 'grey', 'flat', 'H3 lean-to'),
 (650, 970, 740, 1057, 'house', 'darkgrey', 'gabled', 'H4 house, east'),
 (650, 1103, 700, 1133, 'shed', 'darkgrey', 'gabled', 'S3 shed, east'),
 (225, 1285, 370, 1336, 'barn', 'lightgrey', 'gabled', 'B1 barn, south-west'),
 (561, 1291, 683, 1341, 'barn', 'lightgrey', 'gabled', 'B2 barn, south'),
 (398, 1291, 460, 1330, 'shed', 'darkgrey', 'gabled', 'S4 shed, south'),
 (200, 1133, 223, 1167, 'shed', 'lightgrey', 'flat', 'S5 small shed'),
 (278, 1639, 370, 1712, 'house', 'grey', 'gabled', 'H5 house, south (outside)'),
]
for x0, y0, x1, y1, k, col, roof, note in B:
    box(x0, y0, x1, y1, {'building': k, 'roof:shape': roof, 'roof:colour': col, 'building:levels': '1', 'note': note})
# roads and tracks (centre lines)
way([(247, 250), (217, 550), (202, 900), (177, 1330), (152, 1650), (127, 1950)], {'highway': 'unclassified', 'surface': 'asphalt', 'width': '4.5', 'name': 'village road (west)'})
way([(845, 250), (868, 550), (864, 660), (885, 725), (935, 760), (1008, 785), (1100, 810)], {'highway': 'track', 'surface': 'gravel', 'width': '3.8', 'name': 'village road (east)'})
way([(651, 330), (640, 500), (633, 670), (627, 770), (607, 850), (567, 923), (513, 963)], {'highway': 'track', 'surface': 'ground', 'note': 'worn track into the yard'})
# ploughed and planted strips (brown earth in the photo), as 'sand' so the earth colour shows
for r in [(241, 393, 629, 539), (273, 668, 633, 695), (112, 1347, 427, 1414), (157, 1482, 814, 1577)] + [(-80, y, 150, y + 70) for y in range(420, 1300, 150)]:
    box(*r, {'natural': 'sand', 'note': 'ploughed field strip'})
# vegetable beds east of the yard
for x in range(943, 1100, 24): box(x, 876, x + 14, 1426, {'natural': 'sand', 'note': 'vegetable bed'})
# mown grass and meadow everywhere else is the ground colour
# trees seen in the photo (crowns): x, y, crown size class
T = [(167, 923, 's'), (227, 750, 'm'), (260, 710, 'm'), (320, 717, 'm'), (367, 717, 'm'), (393, 770, 'm'), (413, 823, 's'),
     (447, 717, 'm'), (520, 717, 'l'), (513, 903, 'm'), (473, 923, 's'), (333, 923, 'm'), (300, 930, 's'), (247, 1030, 'l'),
     (300, 1030, 'm'), (340, 1037, 'm'), (380, 1043, 's'), (300, 1177, 'l'), (580, 1137, 'm'), (607, 1170, 'm'), (580, 1217, 'm'),
     (620, 1223, 's'), (767, 1083, 'l'), (787, 1137, 'l'), (740, 1177, 'm'), (767, 1237, 'm'), (700, 1203, 'm'), (680, 1063, 's'),
     (813, 1083, 'm'), (673, 303, 'l'), (168, 752, 'm'), (595, 1560, 'm'), (650, 1550, 'l'), (700, 1570, 'm'), (760, 1560, 'm'),
     (840, 1580, 'm'), (202, 1616, 'm'), (965, 696, 'm'), (150, 800, 's'), (140, 880, 's'), (690, 1270, 's'), (720, 1300, 's')]
for x, y, sz in T: node(x, y, {'natural': 'tree', 'height': {'s': '6', 'm': '9', 'l': '12'}[sz], 'note': 'from satellite photo'})
data = {'version': 0.6, 'elements': els, 'pocket_city': {'lat': LAT0, 'lon': LON0, 'size': 150, 'place': 'Хряськ, Волинська область',
        'bbox': '', 'fetched': time.strftime('%Y-%m-%d'), 'osm_base': None}}
json.dump(data, open('osm-traced.json', 'w'), ensure_ascii=False)
print(len(els), 'elements')
