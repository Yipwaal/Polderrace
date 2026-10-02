class_name Cars
## TEMPORARY STUB (main session): car data for the gameplay port until the car module (G3) lands.
## The real file comes from the car port and replaces this one completely.

const CARS := {
  "hatch": {"name": "Hot hatch","cls": "B","vmax": 215,"acc": 15,"grip": 1.18,"brake": 33,"mass": 0.9},
  "rally": {"name": "Rallyhatch","cls": "B","vmax": 205,"acc": 16,"grip": 1.22,"brake": 34,"mass": 0.95},
  "coupe": {"name": "Mini-coupé","cls": "B","vmax": 226,"acc": 14.2,"grip": 1.12,"brake": 32,"mass": 0.85},
  "roadster": {"name": "Roadster","cls": "B","vmax": 219,"acc": 14.8,"grip": 1.2,"brake": 33,"mass": 0.8},
  "mini": {"name": "Cityflitser","cls": "B","vmax": 208,"acc": 15.6,"grip": 1.24,"brake": 34,"mass": 0.78},
  "retro": {"name": "Retro-coupé","cls": "B","vmax": 223,"acc": 14.6,"grip": 1.15,"brake": 32,"mass": 0.82},
  "gt": {"name": "GT-coupé","cls": "A","vmax": 250,"acc": 15.5,"grip": 1.0,"brake": 30,"mass": 1.0},
  "muscle": {"name": "Muscle car","cls": "A","vmax": 265,"acc": 18,"grip": 0.85,"brake": 27,"mass": 1.2},
  "fastback": {"name": "Fastback","cls": "A","vmax": 258,"acc": 17,"grip": 0.93,"brake": 29,"mass": 1.1},
  "sedan": {"name": "Sportsedan","cls": "A","vmax": 246,"acc": 16,"grip": 1.04,"brake": 31,"mass": 1.15},
  "wagon": {"name": "Sportwagon","cls": "A","vmax": 254,"acc": 16.8,"grip": 0.98,"brake": 30,"mass": 1.22},
  "evo": {"name": "Turbo-sedan","cls": "A","vmax": 243,"acc": 17.4,"grip": 1.08,"brake": 32,"mass": 1.05},
  "super": {"name": "Supercar","cls": "S","vmax": 305,"acc": 19.5,"grip": 0.95,"brake": 34,"mass": 1.0},
  "hyper": {"name": "Hypercar","cls": "S","vmax": 322,"acc": 20.5,"grip": 0.9,"brake": 35,"mass": 1.05},
  "longtail": {"name": "Longtail","cls": "S","vmax": 314,"acc": 19,"grip": 0.96,"brake": 34,"mass": 1.0},
  "proto": {"name": "Prototype","cls": "S","vmax": 296,"acc": 19.2,"grip": 1.1,"brake": 37,"mass": 0.9},
  "v12": {"name": "Gran Turismo","cls": "S","vmax": 318,"acc": 19.6,"grip": 0.91,"brake": 33,"mass": 1.12},
  "speedster": {"name": "Speedster","cls": "S","vmax": 301,"acc": 20,"grip": 1.02,"brake": 35,"mass": 0.92}
}

const COLORS := ["#f36f21", "#d62a2a", "#f2c200", "#1d4f9e", "#2f8f5b", "#f2f2ee", "#1b1b1b"]

## per model: len, wid, hitR (corner radius of the hitbox), off, wheels [[x, y, z, r], ...] (measured from the HTML game)
const CAR_SPECS := {"hatch": {"len": 4, "wid": 1.9, "hitR": 0.32, "off": 0, "wheels": [[-0.803, 0.34, 1.3, 0.34], [0.803, 0.34, 1.3, 0.34], [-0.803, 0.34, -1.25, 0.34], [0.803, 0.34, -1.25, 0.34]]}, "rally": {"len": 4, "wid": 1.92, "hitR": 0.32, "off": 0, "wheels": [[-0.793, 0.36, 1.3, 0.36], [0.793, 0.36, 1.3, 0.36], [-0.793, 0.36, -1.25, 0.36], [0.793, 0.36, -1.25, 0.36]]}, "coupe": {"len": 3.95, "wid": 1.85, "hitR": 0.34, "off": 0, "wheels": [[-0.783, 0.33, 1.28, 0.33], [0.783, 0.33, 1.28, 0.33], [-0.783, 0.33, -1.28, 0.33], [0.783, 0.33, -1.28, 0.33]]}, "roadster": {"len": 4.05, "wid": 1.86, "hitR": 0.34, "off": 0, "wheels": [[-0.783, 0.34, 1.3, 0.34], [0.783, 0.34, 1.3, 0.34], [-0.783, 0.34, -1.3, 0.34], [0.783, 0.34, -1.3, 0.34]]}, "mini": {"len": 3.75, "wid": 1.86, "hitR": 0.3, "off": 0, "wheels": [[-0.788, 0.33, 1.24, 0.33], [0.788, 0.33, 1.24, 0.33], [-0.788, 0.33, -1.2, 0.33], [0.788, 0.33, -1.2, 0.33]]}, "retro": {"len": 4.1, "wid": 1.8, "hitR": 0.4, "off": 0, "wheels": [[-0.763, 0.33, 1.22, 0.33], [0.763, 0.33, 1.22, 0.33], [-0.763, 0.33, -1.18, 0.33], [0.763, 0.33, -1.18, 0.33]]}, "gt": {"len": 4.4, "wid": 2, "hitR": 0.38, "off": 0, "wheels": [[-0.833, 0.36, 1.4, 0.36], [0.833, 0.36, 1.4, 0.36], [-0.833, 0.36, -1.4, 0.36], [0.833, 0.36, -1.4, 0.36]]}, "muscle": {"len": 4.9, "wid": 2.05, "hitR": 0.34, "off": 0, "wheels": [[-0.838, 0.4, 1.55, 0.4], [0.838, 0.4, 1.55, 0.4], [-0.838, 0.4, -1.5, 0.4], [0.838, 0.4, -1.5, 0.4]]}, "fastback": {"len": 4.8, "wid": 2.03, "hitR": 0.36, "off": 0, "wheels": [[-0.833, 0.39, 1.5, 0.39], [0.833, 0.39, 1.5, 0.39], [-0.833, 0.39, -1.5, 0.39], [0.833, 0.39, -1.5, 0.39]]}, "sedan": {"len": 4.85, "wid": 1.95, "hitR": 0.38, "off": 0, "wheels": [[-0.808, 0.37, 1.55, 0.37], [0.808, 0.37, 1.55, 0.37], [-0.808, 0.37, -1.55, 0.37], [0.808, 0.37, -1.55, 0.37]]}, "wagon": {"len": 4.95, "wid": 1.98, "hitR": 0.38, "off": 0, "wheels": [[-0.818, 0.37, 1.55, 0.37], [0.818, 0.37, 1.55, 0.37], [-0.818, 0.37, -1.5, 0.37], [0.818, 0.37, -1.5, 0.37]]}, "evo": {"len": 4.5, "wid": 1.9, "hitR": 0.36, "off": 0, "wheels": [[-0.783, 0.36, 1.35, 0.36], [0.783, 0.36, 1.35, 0.36], [-0.783, 0.36, -1.3, 0.36], [0.783, 0.36, -1.3, 0.36]]}, "super": {"len": 4.5, "wid": 2.05, "hitR": 0.4, "off": 0, "wheels": [[-0.838, 0.36, 1.45, 0.36], [0.838, 0.36, 1.45, 0.36], [-0.838, 0.36, -1.4, 0.36], [0.838, 0.36, -1.4, 0.36]]}, "hyper": {"len": 4.8, "wid": 2.02, "hitR": 0.42, "off": 0, "wheels": [[-0.813, 0.36, 1.5, 0.36], [0.813, 0.36, 1.5, 0.36], [-0.813, 0.36, -1.5, 0.36], [0.813, 0.36, -1.5, 0.36]]}, "longtail": {"len": 5.33, "wid": 2.05, "hitR": 0.6, "off": -0.165, "wheels": [[-0.828, 0.36, 1.6, 0.36], [0.828, 0.36, 1.6, 0.36], [-0.828, 0.36, -1.35, 0.36], [0.828, 0.36, -1.35, 0.36]]}, "proto": {"len": 4.8, "wid": 2.05, "hitR": 0.48, "off": 0, "wheels": [[-0.828, 0.37, 1.45, 0.37], [0.828, 0.37, 1.45, 0.37], [-0.828, 0.37, -1.45, 0.37], [0.828, 0.37, -1.45, 0.37]]}, "v12": {"len": 4.75, "wid": 2.02, "hitR": 0.42, "off": 0, "wheels": [[-0.823, 0.37, 1.5, 0.37], [0.823, 0.37, 1.5, 0.37], [-0.823, 0.37, -1.42, 0.37], [0.823, 0.37, -1.42, 0.37]]}, "speedster": {"len": 4.6, "wid": 2, "hitR": 0.42, "off": 0, "wheels": [[-0.813, 0.36, 1.45, 0.36], [0.813, 0.36, 1.45, 0.36], [-0.813, 0.36, -1.45, 0.36], [0.813, 0.36, -1.45, 0.36]]}}

static func carsOf(cls: String) -> Array:
	return CARS.keys().filter(func(k): return CARS[k].cls == cls)
