class_name Perks
## What the ranger finds in the cage between levels. Icon: its frame in the
## perk_icons sheet. max: how many of it can be held. needs: not offered until
## another is held.

const ALL := {
	"twin": {"name": "Twin Nock", "text": "One more arrow to a shot.", "icon": 0, "max": 2},
	"quick": {"name": "Quick Hands", "text": "Loose arrows a fifth faster.", "icon": 1, "max": 3},
	"pierce": {"name": "Bodkin Points", "text": "Arrows go through one more.", "icon": 2, "max": 2},
	"heavy": {"name": "Heavy Heads", "text": "Arrows hit half again as hard.", "icon": 3, "max": 2},
	"bounce": {"name": "Springwood", "text": "Arrows glance off the walls.", "icon": 4, "max": 2},
	"homing": {"name": "Moth Fletching", "text": "Arrows bend toward what is alive.", "icon": 5, "max": 1},
	"fire": {"name": "Pitch Arrows", "text": "Arrows burn what they hit, and light gas.", "icon": 6, "max": 1},
	"back": {"name": "Over the Shoulder", "text": "One arrow goes the other way.", "icon": 7, "max": 1},
	"blast": {"name": "Bigger Charge", "text": "Blasts reach further and hit harder.", "icon": 8, "max": 3},
	"cluster": {"name": "Cluster Charge", "text": "Every blast throws three small ones.", "icon": 9, "max": 1},
	"keg": {"name": "Powder Keg", "text": "Carry 3 more powder. Take it now.", "icon": 10, "max": 2},
	"scrounge": {"name": "Scrounger", "text": "Powder turns up twice as often.", "icon": 11, "max": 1},
	"wick": {"name": "Long Wick", "text": "One more wick in the lamp, lit.", "icon": 12, "max": 2},
	"wide": {"name": "Wide Reflector", "text": "The lamp reaches further.", "icon": 13, "max": 2},
	"oil": {"name": "Lamp Oil Habit", "text": "Light a wick every level you clear.", "icon": 14, "max": 1},
	"flare": {"name": "Flash Powder", "text": "Rolling stuns all that's close.", "icon": 15, "max": 1},
	"roll": {"name": "Tumbler", "text": "Roll again a third sooner.", "icon": 16, "max": 2},
	"second": {"name": "Second Wind", "text": "Once a depth, the lamp flares back.", "icon": 17, "max": 1},
	"nerve": {"name": "Nerve", "text": "Double damage on your last wick.", "icon": 18, "max": 1},
	"swap": {"name": "Quickdraw", "text": "The first shot after a swap is triple.", "icon": 19, "max": 1},
	"greed": {"name": "Prospector", "text": "Nuggets are worth more, and find you.", "icon": 20, "max": 1},
	"ghost": {"name": "Will-o'-Wisp", "text": "A wisp follows you, and shoots.", "icon": 21, "max": 2},
	"miner": {"name": "Hard Hat", "text": "Shrugs off the first hit each level.", "icon": 22, "max": 1},
	"chain": {"name": "Chain Reaction", "text": "What a blast kills goes off too.", "icon": 23, "max": 1},
}


## Three to choose from: not at their max, and not the same one twice.
static func offer(held: Dictionary, rng: RandomNumberGenerator, count := 3) -> Array:
	var open := []
	for id: String in ALL:
		if int(held.get(id, 0)) < int(ALL[id].max):
			open.append(id)
	var out := []
	while out.size() < count and not open.is_empty():
		var i := rng.randi() % open.size()
		out.append(open[i])
		open.remove_at(i)
	return out
