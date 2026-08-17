# ---------------------------------------------------------------------------
# Voskresenskaya Station, 02:14.
#
# The prologue. You are in the middle of a cathedral that happens to move
# people, and it has just decided that it is not going to move you.
#
# Entry node: station_wake
# ---------------------------------------------------------------------------

:: station_wake
DO    TASK:get_out
SAY   Narrator | The last train goes east without you. You feel it leave through your shoes before you hear it, a long shrug of air up the tunnel, and then the platform is just tiled floor again.
VOICE Perception 7 | Twelve minutes past two. The board said 02:26 for the next one. There is no next one.
VOICE Composure 9 | Nothing has happened yet. Stand still and let the station tell you what kind of night this is.
OPT   - | Look up. | station_wake_look
OPT   - | Listen. | station_wake_listen
OPT   Shivers 9 | Put a hand flat on the marble. | station_wake_touch

:: station_wake_look
SAY   Narrator | You look up, which is what the station was built for. Nine metres of leaded glass hangs over the east end of the hall, lit from behind, and every colour in it is currently the wrong one.
VOICE Conceptualization 8 | Somebody spent a fortune making sure that the first thing you do here is tilt your head back. It worked. It works on four hundred thousand people a day.
VOICE Visual Calculus 10 | The petals of that window are not decorative divisions. They are equal. Twelve of them, identical, arranged around a hub. That is not how you compose a rose window. That is how you compose a dial.
OPT   - | Keep looking at it. | station_glass
OPT   - | Look at the hall instead. | station_wake_hall

:: station_wake_listen
SAY   Narrator | You close your eyes in a public place, which you would normally never do, and the station comes apart into its parts: escalator gearbox, ventilation, a fluorescent ballast somewhere behind you singing a flat B.
VOICE Shivers 10 | Under all of it, the turnstiles. Eleven of them, clicking to themselves in the dark at the west end. They are not passing anybody. They are just talking.
VOICE Perception 11 | And the ticket hall kiosk is running its shutter motor in short bursts. Down, stop, down, stop. Something is telling it to close and something else keeps interrupting.
OPT   - | Open your eyes. | station_wake_hall
OPT   - | Look up. | station_wake_look

:: station_wake_touch
DO    SET:felt_the_stone
SAY   Narrator | The pylon is cold the way stone is cold, which is not the same as being cold. It takes heat off your palm and gives back nothing, and forty metres down it is still doing this in a room nobody has entered since 1953.
VOICE Shivers 11 | The station is ninety-one years old and it is not remotely finished with you. It has outlasted three currencies. It will outlast whatever is happening tonight.
VOICE Inland Empire 12 | Ask it to open. Go on. It is the only thing down here old enough to have the authority.
OPT   - | Take your hand off the stone. | station_wake_hall

:: station_wake_hall
SAY   Narrator | The central hall runs the length of the station, marble underfoot, and on both sides a row of pylons stands between you and the platforms, pierced every fourth bay by an archway. Bronze chandeliers, none of them switched off, all of them dimmed to about a third.
VOICE Encyclopedia 9 | Pylon station. Deep-level, three parallel halls, the load carried on those piers rather than on a continuous wall. Built to survive an air raid and used as a shelter during one.
VOICE Esprit De Corps 12 | At this hour it holds about nine people. Two on the westbound bench. One asleep sitting up. A cleaner who has been circling the same four metres of floor for a quarter of an hour because the machine is easier to push than to explain.
OPT   - | Head for the turnstiles and go home. | station_seal
OPT   Perception 9 | Count the people again. | station_wake_count

:: station_wake_count
SAY   Narrator | You count them again. Nine. Then you count what they are doing, which is the part that matters, and all nine of them are looking at their phones with the specific stillness of people whose phones have stopped working.
VOICE Logic 9 | Nine phones. One network. If it were a handset problem it would not be all nine.
VOICE Half Light 11 | Nobody is talking about it yet. That is the last quiet minute. Use it.
DO    SET:noticed_the_phones
OPT   - | Head for the turnstiles. | station_seal

# ===========================================================================
# The seal
# ===========================================================================

:: station_seal
DO    SET:station_sealed TASK:why_it_sealed
SAY   Narrator | You get eleven steps toward the west end before the station closes.
SAY   Narrator | It does not slam. Eleven turnstile arms lock in the same instant with one soft composite clack, the street shutter comes down the escalator throat in a smooth four seconds, and the departure glass above you changes colour all at once, like a face.
VOICE Reaction Speed 10 | You are already stopped. You stopped before you decided to. Your body heard eleven solenoids agree with each other and read it correctly as a decision.
VOICE Half Light 9 | That was not a malfunction. Malfunctions are ragged. That was synchronised, and the thing about synchronised is that it means somebody wrote it down in advance.
VOICE Authority 11 | No announcement. No siren, no rolling shutter alarm, no voice. A station that seals without telling anybody is a station that was not sealed for the benefit of the people inside it.
OPT   - | Check the time. | station_seal_time
OPT   Composure 10 | Do not react. Watch everyone else react. | station_seal_watch
OPT   Half Light 8 | Get your back to a pylon. | station_seal_back

:: station_seal_time
DO    SET:knows_0214
SAY   Narrator | 02:14. The clock over the archway is a real clock, mechanical, wound weekly by a man with a key, and it does not care what the network thinks.
VOICE Logic 8 | Note the number. Not because it is interesting yet. Because in about four hours somebody is going to ask you when, and you are going to be the only person who looked.
VOICE Encyclopedia 12 | Two fourteen. Nothing scheduled runs at 02:14. No batch, no rollover, no maintenance window. Whatever this is, it is not the calendar.
OPT   - | Look at what everyone else is doing. | station_seal_watch
OPT   - | Get to the glass. You need to read the glass. | station_after

:: station_seal_watch
SAY   Narrator | You hold still and let the hall do it for you. The cleaner stops the machine. The sleeper does not wake. The two on the bench stand up in the same second and then, having stood, have nowhere to put it.
VOICE Empathy 10 | Nobody screams. That is not calm. That is nine people independently deciding they must have misunderstood, because the alternative is that they are locked in.
VOICE Esprit De Corps 11 | It will hold for about six minutes. Then one of them will try a gate, and it will not open, and then it will be a different room.
VOICE Suggestion 12 | Whoever speaks first in the next six minutes gets to decide what this is. It could be you. It has been you before and it went badly.
OPT   - | Check the time. | station_seal_time
OPT   - | Stop watching people. Start working. | station_after

:: station_seal_back
DO    SET:took_cover MORALE:-1
SAY   Narrator | You put a pylon between yourself and most of the room before you have finished thinking about why. The marble is against your shoulder blades and your bag is already round to the front.
VOICE Half Light 8 | Good. Good. Sightlines. One archway left, one right, the whole west end covered.
VOICE Volition 11 | Look at what you just did. Nine ordinary people are standing in the open being confused and you have taken cover, and neither of those is a reasonable response to a shutter.
VOICE Composure 12 | Come out from behind the pylon before somebody clocks that you went behind it.
OPT   - | Come out. | station_after
OPT   - | Stay here a moment longer. | station_seal_stay

:: station_seal_stay
DO    MORALE:-1
SAY   Narrator | You stay. Thirty seconds behind a piece of Soviet granite, breathing, while a room full of commuters works out that it is a room.
VOICE Inland Empire 11 | This is the safest you will feel tonight and it is behind a rock, in a basement, hiding from a building.
VOICE Pain Threshold 10 | Fine. It is filed. Move.
OPT   - | Move. | station_after

:: station_after
DO    SET:ready_to_work TASK:make_a_way
SAY   Narrator | Somewhere above you is a street with taxis on it. Between you and it there is one shutter, eleven locked arms, a service door, and a train that has not been told it can go.
VOICE Interfacing 8 | All four of those are the same problem wearing four different pieces of hardware. Every one of them is downstream of something that said no.
VOICE Volition 9 | So go and find the thing that said no.
END
