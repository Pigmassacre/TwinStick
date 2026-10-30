class_name Enemies
## What lives in the mine. hp in arrows' worth of ARROW_DAMAGE-less hit points;
## cost is what it takes out of a level's budget; script is how it behaves.

const DEFS := {
	"rat": {"name": "Pit rat", "sheet": "rat", "script": "rat", "hp": 2.0, "speed": 96.0, "radius": 5.0, "damage": 1, "score": 10, "cost": 1.0, "blood": Color("5a5864")},
	"bat": {"name": "Lamp bat", "sheet": "bat", "script": "bat", "hp": 1.0, "speed": 165.0, "radius": 4.5, "damage": 1, "score": 15, "cost": 1.0, "flying": true, "blood": Color("421759")},
	"moth": {"name": "Wick moth", "sheet": "moth", "script": "moth", "hp": 1.5, "speed": 70.0, "radius": 4.5, "damage": 0, "score": 15, "cost": 1.5, "flying": true, "blood": Color("d8b47a")},
	"miner": {"name": "Hollow miner", "sheet": "miner", "script": "miner", "hp": 9.0, "speed": 44.0, "radius": 6.0, "damage": 1, "score": 40, "cost": 3.0, "blood": Color("8a5c36")},
	"blister": {"name": "Blister", "sheet": "blister", "script": "blister", "hp": 7.0, "speed": 22.0, "radius": 6.5, "damage": 1, "score": 40, "cost": 3.0, "blood": Color("6aa03a")},
	"sapper": {"name": "Sapper", "sheet": "sapper", "script": "sapper", "hp": 3.0, "speed": 92.0, "radius": 5.5, "damage": 1, "score": 30, "cost": 2.0, "blood": Color("b01f1f")},
	"foreman": {"name": "Foreman", "sheet": "foreman", "script": "foreman", "hp": 16.0, "speed": 34.0, "radius": 6.5, "damage": 1, "score": 90, "cost": 6.0, "blood": Color("941919")},
	"nest": {"name": "Nest", "sheet": "nest", "script": "nest", "hp": 16.0, "speed": 0.0, "radius": 7.0, "damage": 0, "score": 80, "cost": 5.0, "blood": Color("5c3a24"), "heavy": true},
	"ember": {"name": "Emberling", "sheet": "ember", "script": "ember", "hp": 4.0, "speed": 62.0, "radius": 5.0, "damage": 1, "score": 25, "cost": 2.0, "blood": Color("ff7a24")},
	"coalback": {"name": "Coalback", "sheet": "coalback", "script": "coalback", "hp": 12.0, "speed": 40.0, "radius": 6.5, "damage": 1, "score": 60, "cost": 4.0, "blood": Color("34323c"), "armour": 0.2},
	"drownling": {"name": "Drownling", "sheet": "drownling", "script": "drownling", "hp": 6.0, "speed": 88.0, "radius": 5.5, "damage": 1, "score": 45, "cost": 3.0, "blood": Color("4fb0a8")},
	"shardling": {"name": "Shardling", "sheet": "shardling", "script": "shardling", "hp": 9.0, "speed": 26.0, "radius": 6.0, "damage": 1, "score": 60, "cost": 4.0, "blood": Color("9ff0d8"), "reflects": true},
	"bone": {"name": "Bone archer", "sheet": "bone", "script": "bone", "hp": 6.0, "speed": 48.0, "radius": 5.5, "damage": 1, "score": 55, "cost": 4.0, "blood": Color("dbce90")},
	"wraith": {"name": "Gloam", "sheet": "wraith", "script": "wraith", "hp": 7.0, "speed": 58.0, "radius": 5.5, "damage": 1, "score": 55, "cost": 4.0, "flying": true, "blood": Color("c78cff")},
	"snuffer": {"name": "Snuffer", "sheet": "snuffer", "script": "snuffer", "hp": 2.0, "speed": 96.0, "radius": 4.5, "damage": 0, "score": 25, "cost": 2.0, "blood": Color("34323c")},
	# The bosses: their hp is scaled in Boss.setup.
	"rat_queen": {"name": "Old Bess", "sheet": "boss_rat_queen", "script": "boss_rat_queen", "hp": 220.0, "speed": 62.0, "radius": 15.0, "damage": 1, "score": 1000, "cost": 0.0, "blood": Color("5a5864"), "heavy": true, "boss": true},
	"golem": {"name": "Cinder Jack", "sheet": "boss_golem", "script": "boss_golem", "hp": 300.0, "speed": 30.0, "radius": 15.0, "damage": 1, "score": 2000, "cost": 0.0, "blood": Color("ff7a24"), "heavy": true, "boss": true},
	"drowned": {"name": "The Drowned Shift", "sheet": "boss_drowned", "script": "boss_drowned", "hp": 340.0, "speed": 40.0, "radius": 14.0, "damage": 1, "score": 3000, "cost": 0.0, "blood": Color("4fb0a8"), "heavy": true, "boss": true},
	"lamplighter": {"name": "The Pale Lamplighter", "sheet": "boss_lamplighter", "script": "boss_lamplighter", "hp": 380.0, "speed": 44.0, "radius": 9.0, "damage": 1, "score": 4000, "cost": 0.0, "blood": Color("c78cff"), "heavy": true, "boss": true},
	"heart": {"name": "The Firedamp", "sheet": "boss_heart", "script": "boss_heart", "hp": 520.0, "speed": 0.0, "radius": 30.0, "damage": 1, "score": 10000, "cost": 0.0, "blood": Color("b6ff5a"), "heavy": true, "boss": true},
}
