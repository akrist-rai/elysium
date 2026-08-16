# ---------------------------------------------------------------------------
# The whiteboard, the fire door, and a coffee cup that belongs to nobody in
# the room.
# ---------------------------------------------------------------------------

# ===========================================================================
# THE WHITEBOARD
# ===========================================================================

:: whiteboard
SAY   Narrator | A whiteboard on the north wall, mostly wiped, wiped by somebody in a hurry with the side of their hand.
VOICE Perception 9 | Wiped left to right by a right-handed person standing close. There is a smear of it on the wall at hip height where they did not stop in time.
VOICE Visual Calculus 11 | And it is a bad wipe. Dry marker ghosts. Half of it is still legible if you stop looking at it directly.
OPT   - | Read what is left. | whiteboard_read
OPT   - | Leave it. | END

:: whiteboard_read
SAY   Narrator | What survives is a column of seven rows, numbered, most of them wiped to nothing. Row seven is intact because whoever wiped it started at the top and got interrupted.
SAY   Narrator | 7 - AUDIO. srt = decoy. DO NOT SHIP srt UNTIL 02:00
DO    SET:read_whiteboard
VOICE Logic 10 | It is a build note. Question seven's hint was designed with the flag in the audio and a decoy transcript, and the decoy was scheduled to go live at two in the morning.
VOICE Encyclopedia 11 | Which is not how you write a challenge. You ship a challenge complete. You do not swap a component of it six hours into the competition unless the swap is the point.
OPT   Visual Calculus 10 | Look at the handwriting. | whiteboard_hand
OPT   - | Step back. | END

:: whiteboard_hand
CHECK Visual Calculus WHITE 10 +1:read_notebook | Compare it to the notebook on the desk. | whiteboard_hand_yes | whiteboard_hand_no

:: whiteboard_hand_yes
DO    SET:knows_handwriting XP:30
SAY   Narrator | You hold the notebook up next to the board. Priya's hand is small, even, and vertical. The board is none of those things.
VOICE Visual Calculus 10 | Different person. Backslope, heavy pressure, capitals throughout. Somebody who writes on whiteboards for a living and has stopped trying to be legible.
VOICE Conceptualization 11 | A person who plans a decoy on a whiteboard in a locked server room is not a competitor sneaking in. That is somebody who works here, planning out loud, in a room they assumed was theirs.
OPT   - | Step back. | END

:: whiteboard_hand_no
SAY   Narrator | You look from one to the other and back. They are both handwriting. Beyond that your eyes decline to commit.
VOICE Visual Calculus 10 | There is a difference. You can see that there is a difference. You cannot presently say what it is, which in front of a room is worse than nothing.
OPT   - | Step back. | END

# ===========================================================================
# THE FIRE DOOR
# ===========================================================================

:: fire_door
SAY   Narrator | A fire door in the east wall, shut, with the green exit sign above it throwing the only warm light in the room across the floor.
VOICE Shivers 10 | Cold air at ankle height. It is coming from under the door, and it is coming steadily.
VOICE Perception 9 | The dust in front of the threshold is disturbed in a fan shape. The door has been open tonight, and not briefly.
OPT   - | Look at the threshold. | door_threshold
OPT   Half Light 9 | Open it. | door_open
OPT   - | Leave it. | END

:: door_threshold
DO    SET:saw_threshold
SAY   Narrator | The fan of disturbed dust has a clean triangular bite taken out of the middle of it, right at the door's edge.
VOICE Visual Calculus 10 | Something wedge-shaped sat there. It sat there long enough to keep the dust off, and then it was removed.
VOICE Perception 11 | And there are two arcs, not one. The door was propped, closed, and propped again. Two separate occasions, both tonight.
OPT   - | Find the wedge. | door_wedge
OPT   Half Light 9 | Open it. | door_open

:: door_wedge
CHECK Perception WHITE 9 +1:saw_threshold | Look for where the wedge went. | door_wedge_found | door_wedge_lost

:: door_wedge_found
DO    ITEM:wedge SET:has_wedge XP:20
SAY   Narrator | Kicked, not placed - it is under the second desk, three metres away, at the end of a scuff mark.
VOICE Visual Calculus 10 | Kicked from the doorway by somebody leaving in a hurry, which is a strange way to leave a door you have been carefully propping.
VOICE Logic 11 | Unless the last time they used this door they were not planning to come back through it.
OPT   Half Light 9 | Open the door. | door_open
OPT   - | Step back. | END

:: door_wedge_lost
SAY   Narrator | You look under things for a while. You find two cable ties, a pen lid, and eleven years of dust.
VOICE Perception 9 | It is here. It is in this room. You are looking with the wrong half of your attention.
OPT   Half Light 9 | Open the door. | door_open
OPT   - | Step back. | END

:: door_open
SAY   Narrator | You push the bar. The door gives onto a concrete stairwell, cold, lit by one bulb, going down.
VOICE Shivers 12 | Nothing on the stairs. Nobody has been on those stairs for twenty minutes. Whatever came through here has been gone longer than you have been awake.
VOICE Half Light 10 | Then you can stop bracing. There is nobody to hit.
OPT   - | Check the top step. | door_step
OPT   - | Close it. | END

:: door_step
CHECK Perception WHITE 10 +1:saw_threshold +1:has_wedge | Search the top step and the landing. | door_badge | door_nothing

:: door_badge
DO    ITEM:snapped_badge SET:found_the_badge XP:40
SAY   Narrator | On the landing, half under the lip of the top step, there is a staff ID badge snapped cleanly across the chip.
SAY   Narrator | The photograph is intact. The printed name has been scraped off with a key, badly, by somebody who did not have long.
VOICE Perception 10 | Snapped, not broken. Somebody put it against an edge and applied force on purpose.
VOICE Empathy 11 | And then scraped the name off and left it on a stairwell. That is not caution. That is somebody who has just done something they were not planning to do and is improvising very badly.
VOICE Half Light 12 | It is not his badge. He is four kilometres away. This is the badge that was in your lanyard.
OPT   IF:badge_missing | "This is mine." | door_mine
OPT   - | Pocket it. | door_pocket

:: door_mine
DO    SET:knows_badge_is_mine MORALE:-1 XP:20
SAY   Narrator | You hold the photograph up to nothing in particular. It is a picture of a man who has had more sleep than you and fewer reasons to need it. It is, unmistakably, your face.
VOICE Volition 11 | Your badge. Snapped, scraped, and abandoned in a stairwell by somebody who needed you not to be a person tonight.
VOICE Inland Empire 12 | Somebody took your name off you and left it on a step. You have been walking around for an hour trying to find it and it was out here the whole time.
OPT   - | Pocket it. | door_pocket

:: door_pocket
SAY   Narrator | You put it in your pocket, where a badge is supposed to go, more or less.
VOICE Composure 10 | You will have to explain it later. Have a version ready before then.
OPT   - | Close the door. | END

:: door_nothing
SAY   Narrator | Concrete, a cigarette end that predates the competition, and the specific cold of a stairwell at three in the morning.
VOICE Perception 10 | There is something out here. The light is one bulb and your eyes are tonight's eyes.
OPT   - | Close the door. | END

# ===========================================================================
# THE COFFEE CUP
# ===========================================================================

:: coffee_cup
SAY   Narrator | On the second desk, a paper cup from the machine in the foyer, empty, ring-stained, sat in a small brown halo of its own making.
VOICE Perception 8 | Cold. Been there hours. The sysadmin is holding a mug - ceramic, theirs, brought from home.
VOICE Logic 9 | Two people drank in this room tonight, and only one of them is still in it.
OPT   - | Look at the cup properly. | cup_examine
OPT   - | Leave it. | END

:: cup_examine
CHECK Perception WHITE 8 | Read the cup. | cup_read | cup_missed

:: cup_read
DO    SET:knows_second_person THOUGHT:the_second_cup XP:25
SAY   Narrator | There is a bite mark in the rim. Not lipstick - a nervous chew, all the way round one arc of it, the way a person destroys a cup over ninety minutes of sitting still.
VOICE Perception 8 | Ninety minutes. Somebody sat at this desk, in this room, for an hour and a half, doing nothing with their hands.
VOICE Empathy 11 | Waiting. Not working - there is no notebook, no cables, no chair pulled up to a machine. Somebody sat in here and waited for something to happen elsewhere.
VOICE Half Light 12 | And then left through a fire door, twice, having propped it twice.
OPT   Logic 10 | "So there were three people in this room tonight." | cup_three
OPT   - | Step back. | END

:: cup_three
DO    SET:knows_three XP:20
SAY   Narrator | Priya at her desk. The sysadmin in and out. You, at some point, on the floor. And somebody at this desk with a cup, for ninety minutes, waiting.
VOICE Logic 10 | Four. There were four, and one of them has not been accounted for by anybody.
VOICE Composure 11 | Do not say this to the sysadmin as an accusation. They will hear it as one, because from where they are standing it is one.
OPT   - | Step back. | END

:: cup_missed
SAY   Narrator | It is a paper cup. It has been a paper cup for some hours. Your powers of observation return the word "cup" and then stop, satisfied.
VOICE Perception 8 | There is something on the rim. You have looked at it twice now without seeing it.
OPT   - | Step back. | END
