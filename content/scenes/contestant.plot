# ---------------------------------------------------------------------------
# Priya Raghunathan, face down on the desk, and the machine she was winning on.
# ---------------------------------------------------------------------------

:: the_body
SAY   Narrator | She is folded forward over the desk with her head on one arm, the way people sleep in libraries and airports and nowhere good.
VOICE Half Light 9 | A body. It is a body. Do not touch it, do not look at it, leave the room, leave the building.
VOICE Composure 10 | It is a person at a desk. Half Light has done this at every desk you have passed for a year.
VOICE Empathy 11 | Nineteen hours. Look at the hand. That is not a collapse, that is what happens when somebody finally lets go of something they were holding very hard.
OPT   - | Check whether she is breathing. | body_breathing
OPT   Half Light 10 | Back away from the desk. | body_backaway

:: body_backaway
DO    MORALE:-1
SAY   Narrator | You take two steps back and the room gets no better from there.
VOICE Half Light 10 | Correct. Safe. Nothing in this room can reach you now.
VOICE Volition 9 | She has been alone at that desk for forty-six minutes because the one other person here was frightened of it. Do not make it forty-seven.
OPT   - | Go back and check. | body_breathing

:: body_breathing
CHECK Perception WHITE 8 | Watch her back for a full ten seconds. | body_alive | body_uncertain

:: body_alive
DO    SET:priya_alive TASKDONE:check_the_contestant XP:20
SAY   Narrator | Ten seconds. Her back rises four times, slow and even, and on the fourth one she makes a small irritated noise at whatever is happening behind her eyes.
VOICE Perception 8 | Asleep. Deeply, medically, nineteen-hours asleep. Not unconscious in the way the word has been sitting in your chest for ten minutes.
VOICE Half Light 9 | ...
VOICE Composure 11 | Note what just happened. For ten minutes you have been investigating a death that was never in the room. That was your equipment, not the evidence.
OPT   - | Take that in. | body_relief
OPT   Empathy 9 | Put your coat over her. | body_coat

:: body_uncertain
SAY   Narrator | You watch. The light is bad and your hands are not steady and after ten seconds you are no more certain than you were at zero.
VOICE Half Light 9 | Inconclusive is the same as bad. Inconclusive is worse than bad.
VOICE Pain Threshold 10 | Then get closer. You do not get to resolve this from two metres away.
OPT   - | Get closer and put two fingers on her wrist. | body_pulse
OPT   - | Call the sysadmin over. | body_call

:: body_pulse
DO    SET:priya_alive TASKDONE:check_the_contestant XP:20
SAY   Narrator | You crouch, and put two fingers against the inside of her wrist, and count.
VOICE Perception 9 | Fifty-eight and steady. She is asleep. She is extremely asleep, and she is fine.
VOICE Electrochemistry 10 | Fifty-eight. Yours has not been under ninety since Tuesday.
OPT   - | Take that in. | body_relief

:: body_call
DO    SET:priya_alive TASKDONE:check_the_contestant
SAY   You | "Come and check her again. With me this time."
SAY   The Sysadmin | They come over immediately, which tells you they have been waiting the whole time to be asked. Together you watch her breathe for a while, like idiots, and it is enormously better than doing it alone.
SAY   The Sysadmin | "Fifty-eight. Same as the last four times. She is asleep, and I have needed somebody else to say that out loud since half past two."
DO    SET:sysadmin_warmer XP:20
VOICE Esprit De Corps 9 | That is the first thing you have done tonight that made this room better instead of worse.
OPT   - | Take that in. | body_relief

:: body_relief
SAY   Narrator | The room reorganises itself again. It is not a scene. It is a competition with a broken scoreboard and a student asleep in it.
VOICE Logic 9 | Then the question changes. Nobody was hurt here. Somebody was robbed here, and the theft is still in progress.
OPT   - | Look at what she was working on. | the_body_desk
OPT   - | Leave her be. | END

:: body_coat
DO    SET:covered_her MORALE:1 XP:15
SAY   Narrator | You take off your coat, which smells of the shift you did not do, and put it over her shoulders.
VOICE Empathy 9 | She will wake up in four hours and have no idea where it came from, and it will be the best part of her night.
VOICE Composure 10 | Also: the flask is now in a coat that is not on your body. That was not why you did it. It is however true.
OPT   - | Look at what she was working on. | the_body_desk

:: the_body_desk
SAY   Narrator | The desk around her is an archaeology of nineteen hours: three energy drink cans, a notebook, a phone face down, and a pair of over-ear headphones with one cup worn through to the foam.
VOICE Perception 9 | The headphones are still warm. She had them on when she went down.
VOICE Interfacing 10 | The jack is still in the machine. Whatever she was listening to, the machine is still holding it.
OPT   - | Take the headphones. | body_headphones
OPT   - | Look at the notebook. | body_notebook
OPT   - | Leave the desk. | END

:: body_headphones
DO    ITEM:headphones SET:has_headphones XP:15
SAY   Narrator | You lift them off the desk. They are warm and they smell faintly of somebody else's shampoo and there is still a whisper coming out of the left cup.
VOICE Shivers 10 | A voice. Recorded. Male, flat, reading something aloud in a room with a hard floor.
VOICE Perception 11 | It is looping. It has been looping since she stopped it being a foreground concern.
OPT   - | Look at the notebook. | body_notebook
OPT   - | Go to her monitor. | her_monitor

:: body_notebook
SAY   Narrator | A cheap gridded notebook, open, most of it covered in the working-out of somebody methodical.
VOICE Encyclopedia 9 | Standard CTF notes. Endpoints, header dumps, three different attempts at a base64 that was never base64.
VOICE Visual Calculus 11 | The handwriting is even for eighteen pages and then, on the last one, it changes. Bigger. Pressed harder. Two words underlined twice.
OPT   - | Read the last page. | body_lastpage

:: body_lastpage
DO    SET:read_notebook
SAY   Narrator | The last page says, in letters gouged half through the paper:
SAY   Narrator | IT IS IN THE AUDIO. NOT THE TRANSCRIPT.
SAY   Narrator | Under it, the time: 02:12.
VOICE Logic 10 | Two minutes before the board froze she worked out that the flag was hidden in the audio file and not in the transcript that goes with it.
VOICE Conceptualization 12 | She did not write that to remember it. She wrote it that hard because she had just understood that somebody had done it on purpose.
DO    TASK:find_the_intruder
OPT   - | Go to her monitor. | her_monitor
OPT   - | Step back from the desk. | END

# ===========================================================================
# HER MONITOR
# ===========================================================================

:: her_monitor
SAY   Narrator | Her monitor is awake, showing the competition site, showing a submission box with a cursor still blinking in it.
VOICE Interfacing 9 | Session is live. She never logged out; she just stopped being conscious at it.
VOICE Perception 10 | There is text in the submission box. Eleven characters, typed, never sent.
OPT   ONCE | Read what is in the box. | monitor_box
OPT   IF:read_the_box | Look at the submission history. | monitor_history
OPT   IF:read_the_box NOT:opened_audio | Open the audio hint for question seven. | monitor_audio_gate
OPT   - | Step away. | END

:: monitor_box
DO    SET:read_the_box
SAY   Narrator | The box contains: THN{c0ld_st}
SAY   Narrator | Half a flag. She was typing it when she stopped.
VOICE Visual Calculus 10 | She got eight characters in. The clock on the page says the session went idle at 02:13.
VOICE Logic 11 | She had it. At 02:12 she wrote down where it was. At 02:13 she started typing it. At 02:14 the board froze. Those are not three events.
DO    SET:knows_timeline XP:25
OPT   - | Look at the submission history. | monitor_history
OPT   - | Step away. | END

:: monitor_history
SAY   Narrator | You scroll her submission history. Six questions, six accepted flags, six first-solves in a row. She has not been beaten to a single one all night.
VOICE Encyclopedia 10 | Six first-solves. On the harmonic pool that is not a lead, that is a landslide.
VOICE Logic 9 | And question seven is the largest pool of the night. Whoever takes it first takes more than the previous three combined.
OPT   - | Ask how the scoring actually works. | monitor_scoring
OPT   IF:read_the_box | Look at question seven's status. | monitor_q7

:: monitor_scoring
DO    THOUGHT:harmonic_greed
SAY   Narrator | There is a link at the bottom of every page: HOW SCORING WORKS. Somebody wrote it in good faith, at the start, before any of this.
SAY   Narrator | Score equals p divided by k times the sum of one over i, for i from one to n.
VOICE Logic 10 | Plain English: the pool is fixed, and it is split on a harmonic curve. First solver takes the biggest share. Second takes half of that. Third a third.
VOICE Conceptualization 12 | It was written to reward speed. Read it the other way and it is a document explaining exactly how much it is worth to make sure somebody else is not first.
OPT   - | Look at question seven's status. | monitor_q7

:: monitor_q7
DO    SET:knows_guest0 TASK:find_the_intruder
SAY   Narrator | Question seven. Status: SOLVED. First solve recorded at 02:49, forty-one minutes ago, by a user called guest_0.
VOICE Interfacing 11 | guest_0. That is not a name somebody picks. That is a placeholder, and placeholders come from scripts.
VOICE Half Light 12 | It is not on the scoreboard. The board has been frozen since 02:14, so the submission went in AFTER the freeze, into a system that is refusing everybody else.
OPT   Logic 10 | "The board is frozen. How did anything get in at all?" | monitor_paradox
OPT   - | Sit with that for a moment. | monitor_paradox

:: monitor_paradox
DO    SET:knows_paradox XP:30
SAY   Narrator | The scoreboard has accepted nothing since 02:14. At 02:49 it accepted exactly one thing.
VOICE Logic 10 | A lock that is held by somebody does not stop that somebody. It stops everybody else.
VOICE Interfacing 12 | Whoever froze the board froze it from the inside, and then walked through the door they were holding shut.
VOICE Conceptualization 13 | That is not a hack. Nothing was broken into. Somebody with a key stood in the doorway so that nobody else could get past, and then took their time.
OPT   IF:has_headphones | Open the audio hint for question seven. | monitor_audio
OPT   NOT:has_headphones | You will need the headphones for the audio. | monitor_need_phones
OPT   - | Step away and think. | END

:: monitor_audio_gate
OPT   ITEM:headphones | Put the headphones on and play it. | monitor_audio
OPT   NOT:has_headphones | Try to play it out loud. | monitor_need_phones
OPT   - | Not yet. | END

:: monitor_need_phones
SAY   Narrator | You click play. The machine's speakers have been disabled at the OS level, the way every machine in every lab in the building has been since a previous generation of students discovered airhorns.
VOICE Interfacing 9 | You need the headphones. They are eighty centimetres away, on the desk, still plugged in.
OPT   - | Get the headphones. | body_headphones
OPT   - | Later. | END

:: monitor_audio
DO    SET:opened_audio
SAY   Narrator | The hint for question seven is an audio file with a transcript beside it, synchronised, the words highlighting one by one as the recording plays. Somebody built that feature carefully. Somebody was proud of it.
VOICE Encyclopedia 10 | Accessibility feature. Audio hints with synced captions, so that a question is not unsolvable for anyone who cannot use the audio.
OPT   - | Read the transcript. | monitor_transcript
OPT   ITEM:headphones | Listen to the audio. | monitor_listen

:: monitor_transcript
DO    SET:read_transcript
SAY   Narrator | The transcript is four hundred words of a man reading a made-up incident report in a flat voice. At 02:11 into the recording, the transcript says: [inaudible - 6s]
VOICE Perception 10 | Six seconds marked inaudible in the middle of an otherwise perfect transcript. Everything either side of it is transcribed down to the ums.
VOICE Logic 11 | A transcript that careful does not lose six seconds by accident.
OPT   ITEM:headphones | Listen to that six seconds. | monitor_listen
OPT   NOT:has_headphones | You need the headphones. | monitor_need_phones

:: monitor_listen
DO    SET:heard_audio
SAY   Narrator | You put the headphones on. The room goes away and is replaced by a man in a room with a hard floor, reading.
SAY   Narrator | You drag the playhead to 02:11.
VOICE Shivers 9 | The same voice. Flat, patient, slightly pleased with itself. It has been looping in Priya's ears for an hour.
SAY   Narrator | The voice says, clearly and without hurrying: "The flag is tee-aitch-en, brace, cee-zero-ell-dee, underscore, ess-tee-ay-ar-tee, brace."
SAY   Narrator | THN{c0ld_st4rt}
OPT   - | Take the headphones off. | monitor_mismatch

:: monitor_mismatch
DO    SET:knows_mismatch XP:40
SAY   Narrator | The transcript, still on screen, still says: [inaudible - 6s]
VOICE Logic 10 | The flag is in the audio. The transcript, which is supposed to be the same information, has it removed and marked as noise.
VOICE Conceptualization 12 | Every solver who used the transcript - which is the fast way, and the accessible way, and the way most people would - was reading a document with the answer surgically taken out of it.
VOICE Half Light 11 | That is not a puzzle. That is a trap laid for the people who needed the transcript most.
OPT   - | Who made the transcript? | monitor_whomade
OPT   Empathy 10 | Think about who that trap was actually for. | monitor_trapfor

:: monitor_trapfor
DO    MORALE:-1 SET:understands_trap
SAY   Narrator | The transcript exists so that somebody who cannot use the audio can still play. It is the one file in the whole competition aimed at a specific person's need.
VOICE Empathy 10 | And it is the only file that was edited. Whoever did this did not just want to be first. They wanted to be first past a particular group of people, and they knew exactly which file to reach into.
VOICE Volition 11 | Do not go anywhere with that yet. You will want to, and you are three hours from being able to carry it.
OPT   - | Who made the transcript? | monitor_whomade

:: monitor_whomade
SAY   Narrator | You right-click the transcript asset. The platform stores who uploaded each file and when.
CHECK Interfacing WHITE 11 +1:has_headphones +2:found_the_badge | Pull the asset metadata. | monitor_metadata | monitor_metadata_fail

:: monitor_metadata
DO    SET:knows_uploader XP:35
SAY   Narrator | Asset: q7_hint.srt. Uploaded 01:58 tonight. Uploaded by: staff account, technical lead.
SAY   Narrator | The audio file next to it was uploaded eleven days ago.
VOICE Logic 10 | The audio is eleven days old. The transcript that goes with it was replaced sixteen minutes before Priya found the discrepancy.
VOICE Visual Calculus 12 | Draw it. 01:58 the transcript is swapped. 02:12 she notices. 02:13 she starts typing. 02:14 the board locks. 02:49 guest_0 is first.
VOICE Conceptualization 13 | That is not a series of coincidences. That is a person, working, in order.
OPT   - | Step away from the desk. | END

:: monitor_metadata_fail
SAY   Narrator | The metadata panel is admin-gated. It asks for credentials you cannot produce, from a person you cannot name, using a badge you no longer have.
VOICE Interfacing 11 | You need either the badge, or somebody with admin, or a better hour of your life than this one.
VOICE Composure 10 | The sysadmin has admin. The sysadmin also has every reason to want to know the answer.
OPT   - | Step away from the desk. | END
