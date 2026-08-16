package game

import rl "vendor:raylib"

// The four attributes. Everything a skill can do is rooted in one of them.
Attribute :: enum u8 {
	Intellect,
	Psyche,
	Physique,
	Motorics,
}

attribute_name := [Attribute]string {
	.Intellect = "INTELLECT",
	.Psyche    = "PSYCHE",
	.Physique  = "PHYSIQUE",
	.Motorics  = "MOTORICS",
}

// Twenty-four skills, six to an attribute. These are not stats you read off a
// sheet -- each one is a voice with an agenda, and they argue.
Skill :: enum u8 {
	// Intellect
	Logic,
	Encyclopedia,
	Rhetoric,
	Drama,
	Conceptualization,
	Visual_Calculus,
	// Psyche
	Volition,
	Inland_Empire,
	Empathy,
	Authority,
	Esprit_De_Corps,
	Suggestion,
	// Physique
	Endurance,
	Pain_Threshold,
	Physical_Instrument,
	Electrochemistry,
	Shivers,
	Half_Light,
	// Motorics
	Hand_Eye_Coordination,
	Perception,
	Reaction_Speed,
	Savoir_Faire,
	Interfacing,
	Composure,
}

Skill_Info :: struct {
	name:      string, // display name, as it appears when the skill speaks
	attribute: Attribute,
	color:     rl.Color,
	blurb:     string, // what this voice wants from you
}

// Colours run per attribute family, with each skill shifted a little off its
// siblings so a wall of voices stays legible.
skill_info := [Skill]Skill_Info {
	.Logic = {
		"Logic",
		.Intellect,
		{ 92, 174, 214, 255 },
		"Cross-examine the world. Find the through-line.",
	},
	.Encyclopedia = {
		"Encyclopedia",
		.Intellect,
		{ 116, 190, 205, 255 },
		"Recall everything. Volunteer it whether or not it helps.",
	},
	.Rhetoric = {
		"Rhetoric",
		.Intellect,
		{ 78, 156, 205, 255 },
		"Argue. Win. Notice when you are being argued at.",
	},
	.Drama = {
		"Drama",
		.Intellect,
		{ 129, 162, 220, 255 },
		"Lie beautifully. Catch the lies of others.",
	},
	.Conceptualization = {
		"Conceptualization",
		.Intellect,
		{ 108, 152, 228, 255 },
		"See the shape of the idea nobody has said out loud.",
	},
	.Visual_Calculus = {
		"Visual Calculus",
		.Intellect,
		{ 86, 196, 226, 255 },
		"Reconstruct the scene. Draw the lines in the air.",
	},
	.Volition = {
		"Volition",
		.Psyche,
		{ 176, 118, 212, 255 },
		"Hold the line. Refuse to come apart.",
	},
	.Inland_Empire = {
		"Inland Empire",
		.Psyche,
		{ 196, 108, 208, 255 },
		"Listen to what the inanimate world is trying to tell you.",
	},
	.Empathy = {
		"Empathy",
		.Psyche,
		{ 168, 132, 224, 255 },
		"Feel what they feel. Use it, or be wrecked by it.",
	},
	.Authority = {
		"Authority",
		.Psyche,
		{ 152, 106, 196, 255 },
		"Assert rank. Panic quietly when it does not take.",
	},
	.Esprit_De_Corps = {
		"Esprit de Corps",
		.Psyche,
		{ 186, 140, 232, 255 },
		"Know what the others are doing, elsewhere, right now.",
	},
	.Suggestion = {
		"Suggestion",
		.Psyche,
		{ 206, 128, 226, 255 },
		"Charm. Redirect. Make it their idea.",
	},
	.Endurance = {
		"Endurance",
		.Physique,
		{ 202, 84, 68, 255 },
		"Stay standing. That is the whole job.",
	},
	.Pain_Threshold = {
		"Pain Threshold",
		.Physique,
		{ 214, 96, 84, 255 },
		"It hurts. Keep going anyway.",
	},
	.Physical_Instrument = {
		"Physical Instrument",
		.Physique,
		{ 224, 74, 58, 255 },
		"Your body is a tool. Swing it.",
	},
	.Electrochemistry = {
		"Electrochemistry",
		.Physique,
		{ 232, 100, 148, 255 },
		"More. Of whatever it was. Right now.",
	},
	.Shivers = {
		"Shivers",
		.Physique,
		{ 176, 112, 96, 255 },
		"The building is talking. Hold still and hear it.",
	},
	.Half_Light = {
		"Half Light",
		.Physique,
		{ 238, 78, 62, 255 },
		"Something is wrong. Hit it before it hits you.",
	},
	.Hand_Eye_Coordination = {
		"Hand/Eye Coordination",
		.Motorics,
		{ 214, 168, 52, 255 },
		"Put the thing where you meant to put it.",
	},
	.Perception = {
		"Perception",
		.Motorics,
		{ 226, 186, 76, 255 },
		"The detail nobody photographed.",
	},
	.Reaction_Speed = {
		"Reaction Speed",
		.Motorics,
		{ 234, 200, 92, 255 },
		"Move before you have finished deciding to.",
	},
	.Savoir_Faire = {
		"Savoir Faire",
		.Motorics,
		{ 204, 158, 44, 255 },
		"Be smooth about it. Land on your feet.",
	},
	.Interfacing = {
		"Interfacing",
		.Motorics,
		{ 196, 178, 68, 255 },
		"Machines want to be understood. Ask them nicely.",
	},
	.Composure = {
		"Composure",
		.Motorics,
		{ 218, 194, 118, 255 },
		"Do not let your face say it first.",
	},
}

attribute_color := [Attribute]rl.Color {
	.Intellect = { 92, 174, 214, 255 },
	.Psyche    = { 176, 118, 212, 255 },
	.Physique  = { 214, 88, 72, 255 },
	.Motorics  = { 220, 178, 64, 255 },
}

// Writers should not have to remember whether it is "Esprit de Corps" or
// "Esprit De Corps" or "Esprit_de_Corps". Match on a normalised form so all
// three resolve, and a typo in the actual letters still fails loudly.
skill_from_name :: proc(name: string) -> (Skill, bool) {
	for info, s in skill_info {
		if skill_names_match(info.name, name) {
			return s, true
		}
	}
	return .Logic, false
}

skill_names_match :: proc(a, b: string) -> bool {
	ai, bi := 0, 0
	for ai < len(a) && bi < len(b) {
		if normalize_skill_byte(a[ai]) != normalize_skill_byte(b[bi]) {
			return false
		}
		ai += 1
		bi += 1
	}
	return ai == len(a) && bi == len(b)
}

// Case-folded, with space, underscore and slash all treated as the same
// separator.
normalize_skill_byte :: proc(c: byte) -> byte {
	if c == ' ' || c == '/' || c == '_' {
		return '_'
	}
	return to_lower_byte(c)
}

to_lower_byte :: proc(c: byte) -> byte {
	if c >= 'A' && c <= 'Z' {
		return c + 32
	}
	return c
}

// A modifier is always carried with the reason for it, because the check popup
// has to itemise every line. A bare integer would lose the only part the
// player actually reads.
Modifier :: struct {
	label: string,
	value: int,
}

Character :: struct {
	attributes:   [Attribute]int,
	// Points invested into an individual skill, on top of its attribute.
	skill_points: [Skill]int,
	health:       int,
	morale:       int,
	xp:           int,
	level:        int,
	skill_caps:   int, // unused hook for later progression tuning
}

MAX_ATTRIBUTE :: 6
XP_PER_LEVEL :: 100

character_init :: proc(c: ^Character, intellect, psyche, physique, motorics: int) {
	c.attributes[.Intellect] = intellect
	c.attributes[.Psyche] = psyche
	c.attributes[.Physique] = physique
	c.attributes[.Motorics] = motorics
	c.level = 1
	c.health = health_max(c^)
	c.morale = morale_max(c^)
}

// Health is what your body can absorb, Morale is what your self-image can.
// Neither is a hit point bar; both are ways to lose.
health_max :: proc(c: Character) -> int {
	return c.attributes[.Physique] + 1
}

morale_max :: proc(c: Character) -> int {
	return c.attributes[.Psyche] + 1
}

// The base value of a skill before any situational modifiers: its attribute
// plus whatever has been invested directly.
skill_base :: proc(c: Character, s: Skill) -> int {
	return c.attributes[skill_info[s].attribute] + c.skill_points[s]
}

award_xp :: proc(c: ^Character, amount: int) -> (levelled: bool) {
	c.xp += amount
	for c.xp >= XP_PER_LEVEL {
		c.xp -= XP_PER_LEVEL
		c.level += 1
		levelled = true
	}
	return
}
