# ---------------------------------------------------------------------------
# The rose window, which is a dashboard, and the diagnosis that comes off it.
#
# This is the scene where the player stops seeing a cathedral and starts seeing
# a distributed system with a stuck lock. The glass is the status page; the
# capture is the proof; the conclusion is a held transaction.
#
# Entry node: station_glass  (also reached from the arrival scene)
# ---------------------------------------------------------------------------

:: station_glass
SAY   Narrator | Up close the window is worse and better. Every pane is a real hand-cut piece of glass in a real lead came, and every pane is backlit by a panel that can change its colour on command, and the seam between the century and the wiring is invisible unless you are looking for it. You are looking for it.
VOICE Visual Calculus 9 | Twelve figures around the hub. Read them as a ring, not as a picture. Eleven are the deep blue that this glass is supposed to be. One, at the four-o'clock position, is amber, and it is the only warm thing in nine metres of window.
VOICE Encyclopedia 11 | The iconography is wrong for a saint. No halo, no attribute, no name scroll. Each figure is holding a different object, and the objects are a cup, a wheel, a key, a lamp, a gate, a chain.
OPT   - | Read the amber figure. | station_glass_amber
OPT   Conceptualization 10 | Ask what the window is FOR. | station_glass_purpose
OPT   - | Step back and look at the whole ring. | station_glass_ring

:: station_glass_purpose
DO    THOUGHT:glass_saints
SAY   Narrator | You stop reading it as a window. The composition resolves into something you have seen a thousand times on worse screens: a radial service map, twelve tiles, one per subsystem, colour-coded by health.
VOICE Conceptualization 10 | There it is. It is a status page. Somebody in 1953 laid out a monitoring dashboard in cobalt and gold and hung it where the altar goes, and it has been quietly telling the truth to a public that thinks it is art.
VOICE Rhetoric 12 | And because it is beautiful, no one has ever screenshotted it in anger. The most honest dashboard in the city and it has never once been in an incident review.
OPT   - | So which service is amber? | station_glass_amber
OPT   - | Read the whole ring. | station_glass_ring

:: station_glass_ring
SAY   Narrator | You take the ring one figure at a time. Cup: fare collection. Wheel: rolling stock. Lamp: lighting and ventilation, burning steady. Key: access control. Gate: the platform-edge doors. Chain: the street shutters and the fire seal.
VOICE Visual Calculus 9 | Eleven blue. The trains run, the lights burn, the fans turn, the fares would collect if anyone were paying. The system is almost entirely healthy, which is the confusing part, because you are locked inside it.
VOICE Logic 10 | Almost. The amber one is Key. Access control. Everything that locks is one subsystem and that subsystem is the single thing on this window that is not well.
DO    SET:read_the_ring
OPT   - | Read the amber Key figure closely. | station_glass_amber

:: station_glass_amber
DO    SET:saw_amber_key
SAY   Narrator | The amber figure holds a key and stands in a posture the other eleven do not: mid-turn, caught, as if the glazier wanted to show a lock in the act of being worked rather than a lock at rest.
VOICE Interfacing 9 | Amber is not red. Red would be down. Amber is degraded-but-serving, and for an access-control system degraded-but-serving means it is answering, it is just answering "no" to everything.
VOICE Half Light 10 | It is not broken. Broken fails open or fails shut and either way it fails. This is holding. Something is asking the lock a question and refusing to accept the answer, over and over, and while it holds the question open the lock cannot move.
VOICE Logic 11 | A lock held open mid-turn. You have a word for that and it is not a metalwork word. It is a database word.
OPT   Logic 10 | Say the database word. | station_glass_transaction
OPT   - | You need to see the traffic, not the glass. | station_capture_intro

:: station_glass_transaction
DO    THOUGHT:the_held_state SET:suspects_transaction
SAY   You | "It's a transaction. Somebody opened one against the access-control database and never committed it. Every lock in the station is a row waiting on it."
VOICE Logic 10 | That is the shape. You BEGIN, you take your locks, you do your work, and until you COMMIT or ROLLBACK nobody else can have those rows. The whole station is blocked behind one open transaction that is never going to close on its own.
VOICE Interfacing 11 | Which means it is not a fault to repair. It is a hand to remove. Somewhere there is a session holding that lock, and it is either hung, or it is waiting, or somebody is standing on it deliberately.
VOICE Volition 9 | Three possibilities and you can tell them apart. You just need to look at the wire.
OPT   - | Look at the wire. | station_capture_intro

# ===========================================================================
# The capture -- Wireshark
# ===========================================================================

:: station_capture_intro
DO    SET:opened_the_bag
SAY   Narrator | You crouch against the base of a pylon with the laptop on your knees, which is the least conspicuous way to do a conspicuous thing. The concourse has an open network for the passenger information displays. You have been on it since you walked in, listening, because you cannot help it.
VOICE Interfacing 8 | Eleven minutes of capture already on disk. Nine thousand frames. You did not decide to take it. You opened the lid and the capture was running, the way it always is.
VOICE Volition 10 | Own that. You did not stumble into a packet capture on a network you do not own. You brought the tool, you joined the network, and you pressed record. Call it what it is before you use what it found.
OPT   - | "It's a capture. I took a capture." | station_capture_own
OPT   Composure 9 | Skip the confession. Open Wireshark. | station_capture_open

:: station_capture_own
DO    ITEM:wireshark_capture THOUGHT:read_only_hands
SAY   You | "It's a capture. I joined their network and I recorded it. That's a thing I did."
VOICE Half Light 11 | And you would do it again in a heartbeat, which is the actual problem, but not tonight's problem. Tonight's problem is in frame six thousand and something.
VOICE Interfacing 9 | Now filter it. You are not looking for nine thousand frames. You are looking for one.
OPT   - | Open Wireshark and filter. | station_capture_open

:: station_capture_open
DO    ITEM:wireshark_capture
SAY   Narrator | Wireshark fills the screen, monochrome on your dimmed brightness, nine thousand rows of the station talking to itself. Most of it is the departure displays polling a feed. You need the thing that happened once, at 02:14, and then stopped.
VOICE Perception 10 | Do not read it top to bottom, you will die of old age. Filter to the access-control host and sort by time. The interesting packet is the last one before the quiet.
CHECK Interfacing WHITE 10 +1:saw_amber_key +1:suspects_transaction | Write the filter and find the last exchange before 02:14. | station_capture_hit | station_capture_miss
OPT   - | Not yet. Close the laptop. | station_after_glass

:: station_capture_hit
DO    SET:found_the_frame XP:30
SAY   Narrator | The filter cuts nine thousand frames to nineteen, and the nineteenth is the one. 02:13:58. A session opens against the access controller, sends one command, and then the TCP stream just... stays. Window open. Keepalives every thirty seconds, politely, forever.
VOICE Logic 11 | There it is on the wire, exactly the shape you guessed at the glass. A connection that began a transaction, issued a lock, and then stopped sending. Not closed. Not reset. Held.
VOICE Interfacing 10 | And look at the source. Not the operations subnet. The maintenance VLAN. Whoever is holding this lock came in through the service side, not the control room.
VOICE Half Light 9 | The keepalives are the tell. A hung process does not send keepalives. Something is deliberately keeping that session alive so the lock never releases. There is a hand on it and the hand is awake.
DO    SET:knows_maintenance_vlan THOUGHT:layer_two_animal
OPT   Logic 9 | "It's being held on purpose." | station_capture_conclusion
OPT   - | Follow the maintenance VLAN. | station_capture_conclusion

:: station_capture_miss
DO    SET:capture_muddled
SAY   Narrator | You get the filter subtly wrong -- the right host, the wrong port -- and the capture hands you four hundred frames of the departure feed polling itself, which is real, and true, and useless.
VOICE Logic 9 | Wrong port. The access controller does not talk on the web port, it talks on the one nobody remembers. You know this. You are tired.
VOICE Composure 10 | Do not thrash. Widen the filter to the host, drop the port, read the last thirty seconds before the freeze. The tool is not lying to you, you asked it the wrong question.
OPT   - | Fix the filter and look again. | station_capture_retry
OPT   - | Leave it. Work another way out. | station_after_glass

:: station_capture_retry
CHECK Interfacing WHITE 8 +2:capture_muddled | Filter to the host, ignore the port, read the quiet. | station_capture_hit | station_capture_fail_hard
OPT   - | Close the laptop and try a door instead. | station_after_glass

:: station_capture_fail_hard
DO    SET:gave_up_capture MORALE:-1
SAY   Narrator | The second filter is cleaner and the answer still slips past you, somewhere in the gap between what you can see and how tired you are. The frame is in there. You are not going to be the one who reads it tonight.
VOICE Volition 9 | It is on disk. It does not evaporate because you missed it. You can leave by a door that does not require you to have understood this, and there are three of those.
VOICE Encyclopedia 12 | You still know the shape of it from the glass -- a held lock on the access controller, from the maintenance side. You just cannot prove the "on purpose" part. Sometimes the shape is enough to pick a door.
DO    SET:knows_maintenance_vlan
OPT   - | Pick a door. | station_after_glass

:: station_capture_conclusion
DO    SET:understands_the_hold
SAY   Narrator | You sit back against the pylon with the whole thing assembled in front of you, cold and clear and slightly nauseating: a station that seals like a cathedral and thinks like a database, held shut by one open transaction coming off a network a maintenance badge can reach.
VOICE Logic 10 | You cannot commit their transaction for them; you do not have the session. You can do one of two honest things. Reach the machine and kill the session, which releases every lock at once. Or stop needing the locks -- open one door by hand and walk out through the exception.
VOICE Interfacing 11 | The session is on the maintenance VLAN, behind the service door on the eastbound platform. The exceptions are the shutter, the turnstile, and the train. Four doors. You only need one.
OPT   - | Go to work. | station_after_glass

:: station_after_glass
DO    SET:diagnosed
SAY   Narrator | You close the laptop. The glass is still beautiful and still amber at four o'clock and you can no longer see it as anything but a lock caught mid-turn.
VOICE Volition 8 | One door. Any one. Be the person who can open exactly one of them and this is over.
END
