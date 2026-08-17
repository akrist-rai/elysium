# ---------------------------------------------------------------------------
# The four ways out of Voskresenskaya. Each is a real technique with a real
# cost, and each ends the prologue a different way.
#
#   1. The service door       -- reach the machine, kill the session (Burp + a
#                                 cloned maintenance card). The clean fix.
#   2. The turnstile          -- replay a fare handshake. The cheap trick.
#   3. The street shutter      -- the human layer. Nikolai, and a USB that types.
#   4. The stopped train       -- talk the operator into a manual release.
#
# Interactable nodes: service_door, turnstile, shutter, train, kiosk,
# the_sleeper, the_cleaner, vending, your_bag
# ---------------------------------------------------------------------------

# ===========================================================================
# DOOR ONE -- the service door. Burp, a cloned card, and the actual fix.
# ===========================================================================

:: service_door
SAY   Narrator | A grey steel door in the eastbound wall, no handle on this side, a card reader beside it glowing the same amber as the window. Beyond it is the maintenance corridor, and forty metres down that corridor is the rack that is holding the whole station open.
VOICE Interfacing 9 | This is the honest door. Everything else out of here is an escape. This is a fix. Get through here, reach the session that is holding the lock, end it, and every other door in the station opens at the same instant because none of them was ever really locked.
VOICE Half Light 11 | It is also the door with your name closest to it. You cannot open this without becoming, briefly, a maintenance technician who is not one.
OPT   IF:understands_the_hold | Look at the reader. | service_reader
OPT   NOT:understands_the_hold | Look at the reader. | service_reader_blind
OPT   - | Not this door. | station_pick_again

:: service_reader_blind
SAY   Narrator | The reader wants a card you do not have, to open a door onto a problem you have not yet proven exists. You could force all of this. It would be easier if you had read the wire first.
VOICE Logic 10 | You are guessing that the fix is down this corridor. You are probably right. "Probably right" is a bad thing to be while cloning somebody's credentials.
OPT   - | Go and read the capture first. | station_capture_intro
OPT   - | Do it anyway, on the guess. | service_reader
OPT   - | Try a different door. | station_pick_again

:: service_reader
SAY   Narrator | The reader is a modern retrofit screwed into a 1953 frame. It speaks to the access controller over the network -- the same controller that is currently frozen -- but the card handshake happens locally, in your hand, before the controller is ever consulted.
VOICE Interfacing 10 | Two problems, two tools. First, get a card the reader accepts. Second, the reader's little admin app talks to the controller over HTTPS, and if you are going to tell the controller to release its own locks you will need to be inside that conversation, which means Burp, which means the reader has to trust your CA.
OPT   - | Get a card first. | service_clone_intro
OPT   IF:has_maintenance_card | Put your proxy in the middle. | service_burp_intro
OPT   - | Back off. | station_pick_again

:: service_clone_intro
SAY   Narrator | Cards do not appear. Cards are carried by people, and the nearest maintenance card in the building is clipped to Nikolai, the westbound attendant, who is at this moment sitting at his counter not wearing his lanyard because he took it off to rub his eyes.
VOICE Perception 9 | It is on the counter. Nikolai is looking at his dead phone. The Proxmark needs four seconds within a hand's width of that card, and you have a reason to stand at his counter, because everyone in here has a reason to stand at a staff counter tonight.
OPT   Hand Eye Coordination 10 | Palm the reader, lean on the counter, count to four. | service_clone_do
OPT   Suggestion 9 | Ask Nikolai a question that makes him lean away from the card. | service_clone_social
OPT   - | Leave his card alone. | station_pick_again

:: service_clone_do
CHECK Hand Eye Coordination WHITE 11 +1:felt_the_stone | Read the card without reading the room wrong. | service_clone_ok | service_clone_caught
OPT   - | Change your mind, talk to him instead. | service_clone_social

:: service_clone_social
DO    SET:talked_to_nikolai
SAY   You | "Any idea how long, friend? My mother's on the eastbound side and she panics."
SAY   Nikolai | He looks up, and the tiredness reorganises into something kinder. "She is not the only one. Nobody has told me anything either. Twenty-two years and tonight the doors know something I do not." He turns to gesture at the dead board, and his shoulder turns with him, and the lanyard on the counter is now four inches from your hand instead of under his elbow.
VOICE Empathy 10 | He is not lying. He genuinely does not know. Whatever this is, it did not come from the staff, and that costs you something to know while you are about to steal from him.
CHECK Hand Eye Coordination WHITE 8 +2:talked_to_nikolai | Read the card while he is turned away. | service_clone_ok | service_clone_caught
OPT   - | Don't. Not from him. | service_clone_refuse

:: service_clone_refuse
DO    SET:spared_nikolai XP:20
SAY   Narrator | You take your hand back. Nikolai turns round with half a shrug of apology for having no news, and you have no card, and you have one fewer thing to carry out of here.
VOICE Volition 10 | Filed, and this one you get to keep as the good kind. There are three other doors. None of them is his.
OPT   - | Find another door. | station_pick_again

:: service_clone_ok
DO    ITEM:cloned_card SET:has_maintenance_card ITEM:proxmark
SAY   Narrator | Four seconds. The Proxmark warms against your palm and comes away knowing Nikolai's Wednesday: a maintenance credential, twenty-two years of accumulated access, now also living on a blank fob in your pocket.
VOICE Interfacing 9 | You are that card now, as far as any reader in this station is concerned. Every door it opens will open for you and log his name doing it.
VOICE Half Light 10 | Which is the point and also the crime. Go and use it before the guilt catches up, because it is going to, around dawn, with interest.
OPT   - | To the service reader. | service_burp_intro

:: service_clone_caught
DO    SET:clone_noticed MORALE:-1
SAY   Narrator | The Proxmark needs four seconds and you get two before Nikolai's hand comes down flat on the lanyard -- not grabbing, just resting, the way you rest a hand on something that is yours. He does not look at you. He looks at the middle distance and decides not to have seen it.
VOICE Composure 11 | He clocked it. He is being kind about it. Do not make him regret the kindness by pushing.
VOICE Empathy 9 | "Careful," he says, to nobody. "Things go missing on a night like this." And he clips the lanyard back on.
OPT   - | Apologise with your eyes and go. | station_pick_again
OPT   Authority 11 | Try the badge you already have. | service_burp_intro

:: service_burp_intro
SAY   Narrator | The cloned card wakes the reader -- the amber light does not go green, but it stops pulsing, which means it accepted the card and is now waiting on the frozen controller to say what to do about it. That waiting conversation is the one you want to be inside.
VOICE Interfacing 10 | The reader's admin endpoint is HTTPS. You point it through Burp running on the laptop. Right now Burp sees ciphertext, because the reader has no reason on earth to trust a CA you generated this morning in a station toilet.
OPT   - | Make the reader trust your CA. | service_burp_ca
OPT   - | This is too much. Simpler door. | station_pick_again

:: service_burp_ca
DO    ITEM:burp_ca
SAY   Narrator | The reader is a retrofit, which means it was configured in a hurry, which means its trust store is the factory default plus whatever the installer pasted in. The installer left the enrolment page up. It always is.
VOICE Interfacing 11 | Push your CA into the reader's trust store through the enrolment page and every TLS session it opens is suddenly an open book to the proxy on your knees. Then you are not watching the conversation with the controller. You are in it.
CHECK Interfacing RED 12 +1:understands_the_hold +1:has_maintenance_card | Install the CA, proxy the session, and send the controller a clean ROLLBACK. | service_door_open | service_burp_fail
OPT   - | Back out before you commit to this. | station_pick_again

:: service_door_open
DO    SET:killed_the_session SET:station_open TASK:make_a_way TASKDONE:why_it_sealed
SAY   Narrator | Inside the TLS session the controller is exactly as pathetic as you hoped: it is waiting, politely, for the held transaction to tell it something. You tell it something. One ROLLBACK, correctly framed, in Nikolai's name.
SAY   Narrator | The lock releases. Not this door -- every door. Eleven turnstile arms unlock in the same soft clack they locked with, the street shutter climbs its throat, the service door beside you clicks and drifts open on the maintenance corridor, and nine metres of glass goes cobalt all the way round the ring.
VOICE Logic 9 | That is what closing a transaction looks like from the outside. Everything that was waiting on it simply stops waiting, all at once, as if nothing had ever been wrong.
VOICE Half Light 10 | The held session did not fight you. It just stopped. Which means whoever had their hand on that lock let go the moment you reached for it -- or was never going to be there when you arrived. That is tomorrow's problem. Tonight the doors are open.
OPT   - | Walk out through any door you like. | station_resolved_clean

:: service_burp_fail
DO    SET:burp_tripped MORALE:-1
SAY   Narrator | The CA installs. The proxy stands up. And the controller, frozen as it is, still has one reflex left: an unexpected admin session from the maintenance VLAN trips a rule somebody did write correctly, and the reader in front of you goes dark and stops accepting cards at all.
VOICE Composure 10 | You did not open the door. You did close off this door, cleanly, for the rest of the night. The corridor is out.
VOICE Volition 9 | Three doors left and none of them cares about your certificate. Go and be low-tech at one of them.
DO    SET:service_door_dead
OPT   - | Try another door. | station_pick_again

# ===========================================================================
# DOOR TWO -- the turnstile. A replay attack.
# ===========================================================================

:: turnstile
SAY   Narrator | Eleven turnstiles in a bank, all locked, all lit amber. They are the newest thing in the station and the stupidest. Contactless fare gates, tap-and-go, and tonight they will not go for anyone.
VOICE Interfacing 8 | The gate does not phone home for every tap; at this volume it cannot afford to. It validates the fare token locally and settles the account later. Which means the token is checked by the gate, and the gate is right here, and the gate is not very bright.
VOICE Half Light 10 | It locked with everything else, but a fare gate has a failure mode the shutters do not: it is designed to open. Its entire life is opening. You just have to hand it something it recognises.
OPT   - | Capture a tap. | turnstile_capture
OPT   IF:has_gate_token | Replay the tap you captured. | turnstile_replay
OPT   - | Leave the gates. | station_pick_again

:: turnstile_capture
SAY   Narrator | You need a real tap to copy. The problem is that nobody is tapping, because the gates are locked, because tapping does not work. A closed loop, unless you make one.
VOICE Suggestion 10 | The man on the bench still has a valid card and the reflex of twenty years of commuting. Ask him to try the gate "in case it's just yours that's broken." He will tap. He cannot help it. The gate will refuse him and you will have the forty-one bytes.
OPT   Suggestion 9 | Get him to tap while your reader listens. | turnstile_capture_do
OPT   Hand Eye Coordination 10 | Skim a card straight from a pocket instead. | turnstile_skim
OPT   - | Not worth it. | station_pick_again

:: turnstile_capture_do
CHECK Suggestion WHITE 9 +1:noticed_the_phones | Get the tap without getting remembered. | turnstile_token_ok | turnstile_capture_fail
OPT   - | Skim a card yourself instead. | turnstile_skim

:: turnstile_skim
CHECK Hand Eye Coordination WHITE 11 | Lift the handshake off a card in a coat pocket. | turnstile_token_ok | turnstile_capture_fail
OPT   - | Ask the commuter instead. | turnstile_capture_do

:: turnstile_token_ok
DO    ITEM:gate_token SET:has_gate_token XP:20
SAY   Narrator | Forty-one bytes. The reader catches the whole handshake between card and gate and writes it down. It is not encrypted in any way that matters, because the designers assumed the only thing that could produce this exchange was a real card at a real gate, and they were wrong in the specific way that keeps you employed.
VOICE Interfacing 9 | You have a valid tap frozen in amber. The gate has no memory of having seen it. Hand it back and it will believe it is happening for the first time.
OPT   - | Replay it at the gate. | turnstile_replay

:: turnstile_capture_fail
DO    SET:gate_capture_seen MORALE:-1
SAY   Narrator | The commuter taps, the gate refuses him, and he turns to you with the beginnings of a question about why you asked him to do that. You have nothing off the reader worth keeping and one more person in the station who will remember your face.
VOICE Composure 10 | Smile, agree it is all very strange, and be somewhere else. The gate was a long shot and it is not the only shot.
OPT   - | Try another door. | station_pick_again

:: turnstile_replay
DO    ITEM:gate_token
SAY   Narrator | You hold the reader to the gate and play the tap back into it, byte for byte, at the moment you step forward.
VOICE Half Light 9 | This is the oldest trick there is. It is not clever. It works because the gate cannot tell "a card is here" from "the exact electrical ghost of a card that was here nine minutes ago," and nobody ever made it able to.
CHECK Interfacing WHITE 9 +2:has_gate_token | Replay the token and walk through. | turnstile_open | turnstile_replay_fail
OPT   - | Back off the gate. | station_pick_again

:: turnstile_open
DO    SET:beat_the_gate SET:left_by_gate
SAY   Narrator | The arm gives. Just one gate, just the one you are standing at, unlocking for a single phantom fare and swinging back the moment you are through -- but you are through, on the paid side, at the foot of the escalator throat with the shutter above you.
VOICE Interfacing 8 | The gate opened and told the frozen controller nothing, because as far as the gate is concerned a valid customer paid and passed and that is the end of its curiosity. The station is still sealed behind you. But you are on the right side of one gate.
VOICE Half Light 11 | The shutter is still down over the escalator. You beat the fare gate. You did not beat the building. There is still a slab of steel between you and the street.
OPT   - | Deal with the shutter. | shutter
OPT   - | Wait -- is this actually out? | turnstile_reflect

:: turnstile_reflect
SAY   Narrator | You stand on the paid side of a gate in a sealed station and understand that you have solved a checkpoint, not the problem. Behind you: everyone else, still locked in. Above you: the shutter.
VOICE Volition 9 | You could open the shutter and go, alone, and leave eight people and one open transaction behind you. Or you could go back and end the thing that is holding all of it. The gate did not make that choice for you. It just moved you one square.
OPT   - | Take the shutter and go. | shutter
OPT   - | Go back and do it properly. | service_door

:: turnstile_replay_fail
DO    SET:gate_locked_out MORALE:-1
SAY   Narrator | You play the token back and the gate does something the designers did get right: two identical fares nine minutes apart from the same card is impossible, so it assumes a fault, and it hard-locks, and now this gate is not opening for anyone tonight.
VOICE Logic 10 | Duplicate detection. Somebody, somewhere in the spec, was awake. Fair enough.
VOICE Volition 9 | Ten other gates and three other doors. Move.
OPT   - | Try another door. | station_pick_again

# ===========================================================================
# DOOR THREE -- the shutter. The human layer, and a keyboard on a stick.
# ===========================================================================

:: shutter
SAY   Narrator | The street shutter is a wall of interlocking steel slats filling the escalator throat, and set into the wall beside it is a manual override: a keyswitch and, behind a scuffed perspex flap, a maintenance laptop bolted to a shelf, screen on, logged in, because it is always logged in.
VOICE Perception 9 | The override is keyed and Nikolai has the key, and Nikolai does not know why the doors are shut, so Nikolai is not going to turn that key for a stranger tonight.
VOICE Interfacing 10 | But the bolted laptop is logged in as maintenance, and it drives the shutter directly, below the frozen controller. It does not need the network. It needs somebody at that keyboard, and there is a keyboard, and it is unattended.
OPT   IF:talked_to_nikolai | Ask Nikolai to turn the key. | shutter_nikolai
OPT   NOT:talked_to_nikolai | Talk to Nikolai about the key. | shutter_nikolai_cold
OPT   - | Use the bolted laptop. | shutter_ducky_intro
OPT   - | Leave the shutter. | station_pick_again

:: shutter_nikolai_cold
DO    SET:talked_to_nikolai
SAY   You | "The override by the escalator. You've got the key. You could lift the shutter right now."
SAY   Nikolai | "I could. And then it is me who opened a fire shutter that the system closed on purpose, on a night when the system is doing things I do not understand." He shakes his head, not unkindly. "If I knew why it shut I would open it. I do not. That is exactly why I will not."
VOICE Empathy 10 | He is not being obstructive. He is being the one careful person in the building. He will move if you can replace "I do not know why" with "I know why, and it is safe."
OPT   IF:understands_the_hold | Tell him what you found. | shutter_nikolai
OPT   NOT:understands_the_hold | You don't know why either. Go find out. | station_capture_intro
OPT   - | Use the laptop instead of the man. | shutter_ducky_intro

:: shutter_nikolai
SAY   Narrator | Nikolai stands at the keyswitch with the key already in his hand, waiting for a reason he can live with.
VOICE Rhetoric 10 | He does not need the whole database lecture. He needs one true sentence that puts the fault somewhere other than his hands.
OPT   Rhetoric 11 IF:understands_the_hold | "It's a stuck lock on the maintenance side. The shutter's fine -- it's just waiting on a machine that hung. Opening it by hand is the safe move, not the risky one." | shutter_persuade
OPT   Authority 12 | "Turn the key. I'll put my name on it." | shutter_authority
OPT   - | Use the laptop instead. | shutter_ducky_intro

:: shutter_persuade
CHECK Rhetoric WHITE 10 +2:understands_the_hold +1:spared_nikolai | Give him the sentence he can act on. | shutter_open_human | shutter_nikolai_no
OPT   - | Drop it and use the laptop. | shutter_ducky_intro

:: shutter_authority
CHECK Authority RED 13 | Make it his manager's problem, not his. | shutter_open_human | shutter_nikolai_no
OPT   - | Not like that. Reason with him instead. | shutter_persuade

:: shutter_nikolai_no
DO    SET:nikolai_refused
SAY   Nikolai | "No. I am sorry. Not tonight, not from someone whose face I did not know an hour ago." He puts the key back in his pocket, and his hand stays over the pocket. "There is a laptop right there if you are the sort of person who does not need me. I think we both know you might be."
VOICE Empathy 9 | That last part was a gift and a warning in one sentence. He has guessed what you are and is telling you he would rather not watch.
OPT   - | Use the laptop, then. | shutter_ducky_intro
OPT   - | Leave it. | station_pick_again

:: shutter_open_human
DO    SET:shutter_open SET:left_by_shutter SET:nikolai_helped
SAY   Narrator | Nikolai turns the key. The shutter climbs its throat in the same smooth four seconds it came down, and cold street air comes down the escalator to meet you -- exhaust, rain, a city that never knew the station had a bad night.
SAY   Nikolai | "Go on, then. And if anyone asks --" he considers the open shutter "-- I opened it because it was the safe thing, and a person I trusted told me so." He looks at you. "Do not make a liar of me."
VOICE Empathy 11 | Do not make a liar of him. Of everything you are carrying out of here, that is the one to actually keep.
OPT   - | Go up. | station_resolved_human

:: shutter_ducky_intro
SAY   Narrator | The bolted laptop, logged in, screen dimmed, one USB port facing the concourse where nobody would think to look at it. In your bag is a grey stick that is not storage.
VOICE Interfacing 9 | It presents as a keyboard. The machine cannot tell it from the one already attached. Plug it in and it types the shutter-open command faster than anyone could read it doing so, and the laptop obeys, because a keyboard is the one input a computer never learned to distrust.
VOICE Half Light 10 | Four seconds of typing you did not do, on a machine you are not signed in to, in front of a shutter you are not cleared to open. Clean, fast, and entirely yours if it goes wrong.
OPT   Hand Eye Coordination 10 | Plug it in and shield the port with your body. | shutter_ducky_do
OPT   - | This is a lot. Try the man instead. | shutter_nikolai
OPT   - | Leave the shutter. | station_pick_again

:: shutter_ducky_do
DO    ITEM:ducky
CHECK Hand Eye Coordination RED 11 +1:took_cover | Plug the stick, block the sightline, let it type. | shutter_open_ducky | shutter_ducky_fail
OPT   - | Pull out. Ask Nikolai. | shutter_nikolai

:: shutter_open_ducky
DO    SET:shutter_open SET:left_by_shutter SET:used_the_ducky
SAY   Narrator | The stick introduces itself as a keyboard and empties its one sentence into the machine at nine hundred words a minute. The shutter unlocks and begins to climb before the cursor has finished blinking. You pocket the stick. Nobody at the counter looked up.
VOICE Interfacing 8 | The laptop logged a shutter-open command typed at a physically impossible speed by the maintenance account. Someone reading that log tomorrow will know exactly what happened and exactly nothing about who did it.
VOICE Half Light 9 | Which is the whole design. Go, before the four seconds of luck runs out and becomes four seconds of somebody remembering.
OPT   - | Go up the escalator. | station_resolved_ducky

:: shutter_ducky_fail
DO    SET:ducky_jammed MORALE:-1
SAY   Narrator | The stick types its sentence and the laptop, half a second in, throws a credential prompt over the top of it -- somebody set the shutter command to re-authenticate, and the stick is a keyboard, not a mind-reader, and it types the rest of its script harmlessly into a password box that eats it.
VOICE Composure 10 | It did not open. It also did not lock you out; it just sits there with a failed prompt. But your window at that keyboard is gone -- the counter is looking over now.
VOICE Volition 9 | Walk away like you dropped something. Other doors.
OPT   - | Try another door. | station_pick_again

# ===========================================================================
# DOOR FOUR -- the stopped train. Talk the operator out.
# ===========================================================================

:: train
SAY   Narrator | The 04:41 sits at the northbound platform with its doors shut and its cab lit. Through the front glass a driver sits with both hands off the controls, staring at a signal that has been red since 02:14, doing the one thing thirty years of training tells him to do at a red signal, which is nothing.
VOICE Encyclopedia 10 | Rolling stock is blue on the glass. The train is healthy. The line is healthy. The only thing wrong with this train is that the signalling system that is supposed to say go is the same access-control layer that is currently holding every lock in the station.
VOICE Authority 11 | He can release the doors from the cab. He will not, because a driver who opens doors against a red signal is a driver who is looking for another job, and he knows that better than you do.
OPT   - | Get his attention. | train_knock
OPT   - | Leave the train. | station_pick_again

:: train_knock
SAY   Narrator | You rap on the cab glass. He looks at you the way drivers look at people on platforms who want something a driver cannot give, which is most people, most of the time.
SAY   The Driver | He cracks the small window. "Signal's red. I know it's red. There's nothing I can do about it being red, and there's a lot I can do wrong trying." He is already closing the window.
VOICE Empathy 10 | He is not stubborn. He is frightened of exactly the right thing. He has watched a station seal around him and his instinct is to touch nothing, and that instinct is correct, and it is in your way.
OPT   Rhetoric 11 IF:understands_the_hold | "The signal's not protecting you. It's stuck. Read it as failed, not as danger." | train_persuade
OPT   Drama 12 | "There's a medical emergency on the eastbound side. I need these doors." | train_lie
OPT   Empathy 10 | "You've been sitting with a red signal and no explanation for forty minutes. That's its own kind of awful." | train_empathy

:: train_empathy
DO    SET:driver_warmed
SAY   You | "Forty minutes at a dead red with nobody telling you why. That's a horrible way to spend a shift."
SAY   The Driver | The window stops closing. "It is. You have no idea. The book says hold at red and the book does not have a chapter for the whole station going quiet at once." He rubs his face. "What do you actually know?"
VOICE Empathy 11 | That is the door opening. Not the train door. Him. He wants to be given permission by someone who sounds like they understand the machine better than he does tonight.
OPT   Rhetoric 10 IF:understands_the_hold | Explain the stuck lock, plainly. | train_persuade
OPT   NOT:understands_the_hold | You don't actually know yet. Admit it. | train_honest
OPT   - | Push the medical-emergency line. | train_lie

:: train_honest
SAY   You | "Honestly? Not enough yet. I think it's stuck, not dangerous, but I haven't proven it. I won't ask you to open doors on a guess."
SAY   The Driver | "...Thank you. You're the first person tonight who didn't try to sell me something." He nods at the concourse. "Go find out. If you can tell me it's stuck and not danger, and mean it, I'll open them. Come back when you know."
VOICE Volition 10 | He just told you the price of this door: certainty. Go and earn it at the glass, then come back.
OPT   - | Go read the wire. | station_capture_intro
OPT   - | Try a different door for now. | station_pick_again

:: train_persuade
CHECK Rhetoric WHITE 11 +2:understands_the_hold +1:driver_warmed | Convince him the red is a held lock, not a hazard. | train_open | train_refuse
OPT   - | Leave him be. | station_pick_again

:: train_lie
CHECK Drama RED 12 | Sell the medical emergency hard enough to move him. | train_open_lie | train_lie_fail
OPT   - | Don't lie to him. Reason instead. | train_persuade

:: train_open
DO    SET:train_open SET:left_by_train SET:driver_helped
SAY   Narrator | He looks at the red signal for a long moment, and then he does the thing his whole career told him not to: he reads it as failed instead of as forbidding, and he releases the doors under manual authority, his name and his judgement, no one else's.
SAY   The Driver | "Doors are open. You walk down the running tunnel to the crossover and up the emergency stair, and you do it now, before I think about it too hard." A beat. "You were right about it being stuck. You'd better have been right."
VOICE Authority 10 | He took the risk on your word. That is the most anyone has trusted you all night and you did it with a true sentence, which is rarer for you than it should be.
OPT   - | Down onto the track. | station_resolved_train

:: train_open_lie
DO    SET:train_open SET:left_by_train SET:lied_to_driver
SAY   Narrator | The word "medical" does what it always does to a person trained to keep people alive: it overrides the book. He releases the doors before he has finished deciding to, already reaching for the radio to call ahead for help that is not coming.
VOICE Empathy 9 | He is calling an ambulance to the eastbound platform for a person who does not exist. In a minute he is going to find that out, alone, in a cab, having broken a rule for you.
VOICE Volition 8 | The doors are open. Walk. Do not look at the radio. This one does not file clean and you know it.
OPT   - | Go, and don't look back. | station_resolved_lie

:: train_refuse
DO    SET:driver_refused
SAY   The Driver | "No. I hear you, and it makes sense, and I am still not opening doors against a red on a stranger's theory. If control calls and says the word, I open them. Until then I sit here." He means it, and it is the right call, and it does not help you.
VOICE Composure 10 | He is not wrong. Do not resent the one man in here doing his job correctly.
OPT   - | Find another way out. | station_pick_again

:: train_lie_fail
DO    SET:driver_refused MORALE:-1
SAY   The Driver | Something in the delivery is a beat too smooth. His eyes go from you to the empty eastbound platform, where there is visibly no emergency, and back. "There's no one over there," he says quietly, and the window closes, and this time it stays closed.
VOICE Drama 9 | Overcooked it. A real panic does not have that clean a sentence structure and he has heard enough real panic to know.
OPT   - | Try another door. | station_pick_again

# ===========================================================================
# The room's smaller pieces -- people and props worth walking up to.
# ===========================================================================

:: kiosk
SAY   Narrator | The ticket kiosk, shutter halfway down, caught between opening and closing when the station stopped. Inside, a card reader on a stalk still glows, and a small screen shows a spinning wait-cursor that will spin until the power fails.
VOICE Interfacing 9 | Same controller, same freeze. The kiosk tried to close with everything else and something interrupted the shutter motor mid-travel. It has been trying to finish the movement for forty minutes.
VOICE Perception 10 | The reader on the stalk is live. If you needed to test a captured token somewhere quiet, away from Nikolai and the crowd at the gates, this is where you would do it.
OPT   IF:has_gate_token | Test your token on the quiet reader. | kiosk_test
OPT   - | Leave the kiosk. | station_pick_again

:: kiosk_test
DO    SET:token_tested
SAY   Narrator | You hold the token to the kiosk reader and it blinks green, once, before remembering it is supposed to be frozen. Green. It took it.
VOICE Interfacing 8 | Confirmation. The token is good and the readers cannot tell it from a live card. Now you know the gate will take it too, before you bet a locked-out turnstile on it.
DO    SET:has_gate_token
OPT   - | Back to the gates, then. | turnstile_replay
OPT   - | Somewhere else. | station_pick_again

:: the_sleeper
SAY   Narrator | A man asleep sitting up on the westbound bench, chin on his chest, a paper cup of something cold going colder in his hand. He did not wake when the station sealed. He is not going to wake for you.
VOICE Half Light 11 | Check he is asleep. "Asleep sitting up in an empty station at two in the morning" is a sentence with more than one ending.
VOICE Perception 9 | He is breathing. Slow, even, the sleep of a man at the end of a double shift, not the other thing. His lanyard says he cleans the eastbound platform. He is fine. He is just done.
OPT   Empathy 8 | Put his cup on the bench so it doesn't spill on him. | sleeper_cup
OPT   - | Let him sleep. | station_pick_again

:: sleeper_cup
DO    SET:helped_sleeper XP:10
SAY   Narrator | You take the cold cup out of his hand and set it on the bench beside him. He shifts, mutters something with the cadence of a name, and sleeps on, one degree more comfortably, in a station that is not going to let either of you out just yet.
VOICE Empathy 10 | Nobody saw you do that and it changed nothing about the doors. Do it anyway. Especially do it when it changes nothing.
OPT   - | Leave him to it. | station_pick_again

:: the_cleaner
SAY   Narrator | The cleaner has been pushing her machine over the same four metres of marble since before the doors shut, headphones on, in a private country of her own. She has noticed the seal and decided it is not in her job description.
VOICE Esprit De Corps 11 | Twenty years of the station telling her exactly which four metres are hers. It sealed and she thought: still my four metres. There is a kind of freedom in that you will never have.
VOICE Suggestion 9 | She knows this floor better than the man who designed it. If there is a maintenance panel or a service cut nobody documented, it is under her machine right now.
OPT   Suggestion 10 | Ask her what's under the floor. | cleaner_ask
OPT   - | Let her work. | station_pick_again

:: cleaner_ask
DO    SET:asked_cleaner
SAY   Narrator | She lifts one headphone. You ask. She looks at you, then at the amber window, then points her chin at the eastbound wall without breaking the rhythm of the machine.
SAY   The Cleaner | "Service door. Behind it, the room with all the humming. Man goes in, man comes out, doors work. Man went in tonight and I did not see him come out." The headphone goes back on.
VOICE Perception 10 | She just put a person in the maintenance corridor tonight and did not see them leave. The held session has a body attached to it after all, and it is behind that grey door.
DO    SET:knows_someone_inside
OPT   - | The service door, then. | service_door
OPT   - | Sit with that a moment. | station_pick_again

:: vending
SAY   Narrator | A vending machine, still lit, still humming, offering warm cans of coffee and cold cans of something violently blue to a concourse that cannot leave. It takes the same contactless payment the gates do. It, too, is waiting on the frozen controller and does not know it.
VOICE Electrochemistry 8 | Warm coffee. You could murder a warm coffee. The machine would love to sell you one and cannot, because even buying a drink in here now requires the permission of a lock that is stuck.
VOICE Encyclopedia 12 | Even the vending is downstream of access control. Somebody built a station where you cannot buy a coffee without the same subsystem that opens the doors agreeing to it. Tonight that decision has a whole concourse thirsty.
OPT   - | Leave the machine. | station_pick_again

:: your_bag
SAY   Narrator | You take stock of what you are carrying, because you are about to use some of it against a public building and it is worth knowing exactly what "some of it" means.
VOICE Interfacing 8 | A laptop that is nobody's. A capture you should not have. A CA you made this morning. A card reader that reads backwards. A stick that types. None of it is illegal to own. All of it is illegal to have used by the time tonight is over.
VOICE Volition 10 | You packed this bag knowing you would be somewhere you should not be. Do not act surprised by your own preparation.
OPT   Composure 9 | "It's a toolkit. Tools are neutral." | bag_cope
OPT   Volition 10 | "It's a toolkit and I chose every tool for reaching, not for listening." | bag_honest

:: bag_cope
SAY   You | "It's a toolkit. A hammer doesn't have opinions."
VOICE Rhetoric 10 | Nice. You almost believe it. A hammer does not have opinions, but the person who brings a hammer to a locked building at two in the morning has several.
OPT   - | Close the bag. | station_pick_again

:: bag_honest
DO    SET:bag_honest XP:20
SAY   You | "It's a reaching toolkit. Every tool in here is for getting into something. I didn't bring a single thing that only listens."
VOICE Volition 9 | Correct, and rare, and filed. You are not a person who wandered into tonight. You are a person who packed for it.
VOICE Half Light 11 | Which is either the most damning thing about you or the only reason nine people get to go home. You do not get to know which yet.
OPT   - | Close the bag and get to work. | station_pick_again

# ===========================================================================
# Hub -- returned to after backing out of any door.
# ===========================================================================

:: station_pick_again
SAY   Narrator | You stand in the middle of the sealed hall and take the four doors in turn, the way you would read four options off a screen.
VOICE Logic 8 | The service door is the fix and the felony. The turnstile is a cheap trick that only moves you one square. The shutter is a person or a keyboard. The train is a man you have to be honest with. One door. Pick.
OPT   - | The service door. | service_door
OPT   - | The turnstiles. | turnstile
OPT   - | The street shutter. | shutter
OPT   - | The stopped train. | train
OPT   - | Read the glass again first. | station_glass

# ===========================================================================
# Endings -- five ways the prologue closes.
# ===========================================================================

:: station_resolved_clean
DO    SET:prologue_done SET:ending_clean
SAY   Narrator | You could take any door now. You take the service door, because it is the one that leads to the room with all the humming, and because the cleaner watched a man go in there tonight and not come out, and you find you cannot walk up a nice warm escalator without knowing about that.
VOICE Half Light 10 | You released every lock in the station and the first thing you did with your freedom was walk toward the one dark room. That is either the job or a warning about you. Both. It is both.
VOICE Volition 9 | Whatever is down that corridor, you go to it as the person who fixed the station rather than the person who fled it. Hold onto that. It does not come cheap and it does not last.
SAY   Narrator | The maintenance corridor swallows the concourse light behind you. Ahead, the humming. This is where the night actually starts.
END

:: station_resolved_human
DO    SET:prologue_done SET:ending_human
SAY   Narrator | You go up the dead escalator two steps at a time, into cold rain and the ordinary indifference of the street. Behind you the station stays sealed for everyone who is not standing next to Nikolai, and you carry that up into the night with the rain.
VOICE Empathy 10 | You got out because one tired man decided to trust you, and the transaction is still open behind you, still holding eight people in a beautiful room. Getting yourself out was never the whole problem. You knew that going up the stairs.
VOICE Volition 8 | Do not make a liar of him. That is the thread you pull tomorrow, and it leads straight back down here.
END

:: station_resolved_ducky
DO    SET:prologue_done SET:ending_ducky
SAY   Narrator | You go up under the half-raised shutter while it is still climbing, ducking a wall of steel that a stick pretending to be a keyboard talked into moving. Rain. Street. A taxi with its light on, not caring.
VOICE Half Light 9 | Clean exit, no name on it but the maintenance account's. You left the station sealed behind you and a laptop with an impossible command in its logs. That is a loose thread and it is wearing your method even if it is not wearing your name.
VOICE Volition 9 | You are out. The station is not open. Those are different sentences and tonight you only wrote the first one.
END

:: station_resolved_train
DO    SET:prologue_done SET:ending_train
SAY   Narrator | You drop down onto the ballast and walk the running tunnel toward the crossover, the stopped train warm at your back, the driver's trust warmer and heavier than you expected to be carrying.
VOICE Authority 9 | A man broke a thirty-year rule because you told him a true thing with enough certainty to lean on. You had better keep being able to tell him it was true.
VOICE Shivers 11 | The tunnel is the oldest air in the city. Ninety-one years of it. It moves against your face as you walk, coming from somewhere ahead, which means somewhere ahead is open. Follow the air.
END

:: station_resolved_lie
DO    SET:prologue_done SET:ending_lie
SAY   Narrator | You drop onto the track and walk fast, and behind you the driver is on the radio calling for an ambulance to a platform where nobody is dying, and you keep walking, because stopping now means explaining, and you do not have an explanation that survives being said out loud.
VOICE Empathy 8 | He is going to sit in that cab feeling like he did the right thing for exactly as long as it takes the paramedics to find no one. Then he is going to feel like a fool who broke a rule for a liar. You did that. It got you out.
VOICE Volition 9 | It got you out. Write that in the honest column: it worked. Then look at what is under it, because you are going to have to.
END
