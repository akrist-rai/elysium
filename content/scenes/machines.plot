# ---------------------------------------------------------------------------
# The frozen board, and the row of cabinets that is holding it frozen.
# ---------------------------------------------------------------------------

# ===========================================================================
# THE SCOREBOARD
# ===========================================================================

:: scoreboard
SAY   Narrator | A wall-mounted display, two metres of it, showing the TechHunt live board. Sixty names. A bar chart. A clock in the corner reading 02:14 and refusing all further opinions on the subject.
VOICE Perception 8 | The clock in the corner is not the time. It is the timestamp of the last accepted submission, and it has not moved in forty-six minutes.
VOICE Visual Calculus 10 | Top of the board: RAGHUNATHAN, P. The bar is nearly twice the length of second place.
OPT   - | Read the board properly. | scoreboard_read
OPT   Encyclopedia 9 | Work out what the numbers actually mean. | scoreboard_maths

:: scoreboard_read
SAY   Narrator | Sixty names, six questions solved between them in wildly unequal amounts. Priya at the top by a distance. Below her, a cluster of eleven people within four points of each other, all of whom have solved exactly the same five questions.
VOICE Logic 9 | The cluster solved the same things at nearly the same times. That is what a fair competition looks like from above.
VOICE Perception 11 | And the top of the board does not look like that at all. She is not in a cluster. She is somewhere else entirely, and she got there by being first, repeatedly.
OPT   Encyclopedia 9 | Work out what the numbers actually mean. | scoreboard_maths
OPT   - | Step back. | END

:: scoreboard_maths
DO    THOUGHT:harmonic_greed SET:knows_scoring
SAY   Narrator | The formula is printed, small, at the bottom of the display, the way an honest system prints the thing it is doing.
SAY   Narrator | score = p / ( k * sum(1/i) )
VOICE Encyclopedia 9 | A harmonic pool. Fixed points per question, divided among solvers on a one-over-n curve. First takes the largest slice, second takes half of it, third a third, and so on down to nothing.
VOICE Logic 10 | So being first is worth more than being right. Being right is table stakes. Being first is the entire game.
VOICE Conceptualization 12 | And it means the marginal value of stopping somebody else from being first is exactly as large as the value of being first yourself. The formula does not distinguish between those two strategies.
OPT   Half Light 10 | "That is a motive with an equation attached." | scoreboard_motive
OPT   - | File it and move on. | END

:: scoreboard_motive
DO    SET:knows_motive XP:25
SAY   Narrator | You say it out loud, to a wall display, in an empty part of the room.
VOICE Half Light 10 | Somebody read that formula, tonight, and understood it as an instruction.
VOICE Rhetoric 11 | Careful. Everybody in this competition read that formula. Sixty people read it and fifty-nine of them just went and did the questions.
VOICE Logic 12 | Correct. The formula is a motive, not a suspect. It narrows nothing on its own. What narrows it is who could hold the door shut.
OPT   - | Go and look at the machines. | the_racks
OPT   - | Step back. | END

# ===========================================================================
# THE RACK ROW
# ===========================================================================

:: the_racks
SAY   Narrator | Six cabinets along the north wall, five of them lit, one dark. The lit ones show green down the front in a rhythm that has nothing to do with anything happening in this room.
VOICE Shivers 9 | This is where the hum lives. Everything in the building that is still working is working in here.
VOICE Interfacing 10 | Cabinet four is dark. Not dead - the fans are still turning. Somebody has pulled the front panel LEDs, which is what you do to a machine you do not want people looking at.
OPT   - | Look at cabinet four. | racks_four
OPT   Perception 10 | Look at the floor in front of the cabinets. | racks_floor
OPT   - | Leave the racks alone. | END

:: racks_floor
DO    SET:saw_floor_tile
SAY   Narrator | The raised floor tile in front of cabinet four has been lifted and put back wrong. The corner sits two millimetres proud.
VOICE Visual Calculus 11 | Lifted from the left, by somebody kneeling on the right. There is a knee print in the dust and it is a lot fresher than the dust.
VOICE Perception 12 | And there is a second, older set of marks in the same place. Whoever did this had done it before, at least once, on a night when nobody was writing it down.
OPT   - | Look at cabinet four. | racks_four

:: racks_four
SAY   Narrator | Cabinet four is the database. There is a monitor on a swing arm beside it, screen dark, and a keyboard with the shine worn off four keys.
VOICE Interfacing 11 | Wake it up. Everything about tonight is in there and it has been in there the whole time.
OPT   - | Wake the console. | racks_console
OPT   - | Not yet. | END

:: racks_console
SAY   Narrator | The console wakes to a login prompt that has been sitting logged in the whole time, because of course it has.
VOICE Interfacing 10 | You are looking at the live production database of a competition with sixty people in it. Whatever you type next, type it carefully.
VOICE Half Light 12 | Or do not touch it. If you break the competition trying to fix the competition, that is the night over.
CHECK Interfacing WHITE 12 +1:suspects_lock +1:knows_paradox +2:found_the_badge | Look for what is holding the lock. | racks_lock_found | racks_lock_failed

:: racks_lock_failed
SAY   Narrator | You type things. The things you type are plausible and adjacent and none of them is the right thing, and after ninety seconds you are looking at a screen full of your own guesses.
VOICE Interfacing 12 | You know the shape of the answer. You do not currently know the syntax of the answer, which is a different and more humiliating problem.
VOICE Composure 10 | The sysadmin is eight metres away and does this professionally. That is not a defeat, that is a resource.
OPT   IF:sysadmin_present | Go and ask the sysadmin. | sysadmin_hub
OPT   - | Step back from the console. | END

:: racks_lock_found
DO    SET:knows_lock TASKDONE:explain_the_freeze XP:45
SAY   Narrator | One query. It comes back with a single row and the row has been sitting there for forty-six minutes.
SAY   Narrator | An open transaction. Begun at 02:14:07. Never committed. It holds a lock on the submissions table, and the submission code path opens a transaction to count, insert and update progress all together.
VOICE Interfacing 11 | So every other submission in the building queues behind it forever. Not an error. Not a crash. A queue with nobody at the front.
VOICE Logic 10 | The board did not break. Somebody opened a door, stood in it, and has been standing in it since 02:14.
OPT   - | Find out whose session it is. | racks_whose
OPT   - | Step back. | END

:: racks_whose
SAY   Narrator | The row has a client address and an application name attached to it, the way every connection does.
VOICE Interfacing 10 | Application name: the platform's own admin tooling. The bulk user upload endpoint. It opens a transaction and it is supposed to close it.
VOICE Encyclopedia 11 | Bulk upload is a staff feature. It exists so that sixty accounts can be created from a spreadsheet at the start of the night instead of one at a time.
VOICE Logic 12 | And an account created by bulk upload has never registered and never logged in. It just appears, fully formed, in the users table.
OPT   IF:knows_guest0 | "guest_0 was never registered." | racks_guest0
OPT   - | Keep reading. | racks_address

:: racks_guest0
DO    SET:knows_method XP:40
SAY   Narrator | guest_0 was never registered because guest_0 was never a person. It was inserted by the bulk upload tool, in the same transaction that is currently holding the entire competition still.
VOICE Logic 10 | One transaction. Create the account, hold the lock so nobody else can submit, submit the flag you already knew, and take question seven's largest slice with no competition on the curve.
VOICE Conceptualization 13 | It is elegant. That is the unpleasant part. Whoever built this understood their own system well enough to use its correctness against it.
OPT   - | Whose connection is it? | racks_address

:: racks_address
SAY   Narrator | The client address is not in this room. It is not in this building.
VOICE Interfacing 11 | A residential range across the city. Somebody has been doing this from a sofa.
VOICE Half Light 12 | Which means the person who did this is not here, and has not been here, and everything in this room that looks like evidence of a person was left earlier in the evening.
OPT   IF:knows_uploader | "The transcript was swapped at 01:58 by the technical lead." | racks_converge
OPT   - | Step back and think. | END

:: racks_converge
DO    SET:knows_arjun TASK:name_them XP:50
SAY   Narrator | Two facts arrive at the same place from opposite directions and it is not comfortable.
SAY   Narrator | The transcript was replaced at 01:58 by the technical lead's staff account. The transaction holding the board still was opened at 02:14 by the technical lead's admin tooling, from a flat across the city.
VOICE Logic 10 | Same account. Same night. Fourteen minutes apart. He edited the hint so that the transcript readers could not find it, then locked the door behind the one person who found it anyway.
VOICE Conceptualization 13 | He wrote question seven. He always knew the flag. He was never solving anything - he was waiting for the board to be worth stealing, and it became worth stealing the moment she was about to take it.
VOICE Empathy 12 | And he is asleep on a sofa four kilometres away with a scoreboard frozen in his name.
OPT   - | Go and say it to the sysadmin. | sysadmin_hub
OPT   - | Stand here a moment longer. | racks_stand

:: racks_stand
SAY   Narrator | You stand in front of a cabinet with its lights pulled out, in a room with one person asleep in it, holding the whole shape of the night in your hands for the first time.
VOICE Volition 9 | Now. While you have got it. Before you find a reason not to.
VOICE Inland Empire 12 | You have not asked yourself the last question yet. You have been carefully not asking it since you sat up.
OPT   Inland Empire 11 | Ask the last question. | racks_lastquestion
OPT   - | Go and say it to the sysadmin. | sysadmin_hub

:: racks_lastquestion
DO    SET:asked_last_question MORALE:-1
SAY   Narrator | The question is: why was the invigilator on the floor.
VOICE Inland Empire 11 | Not drunk. You have been drunk and it does not do this. Twenty minutes gone and a lanyard with the card torn out of it.
VOICE Logic 12 | He needed a staff badge to be in the building tonight, and he was not in the building tonight, and the badge in his hand is the reason the badge is not in yours.
VOICE Half Light 13 | Somebody came through this room while you were in it. That is not a theory. That is what happened to your face.
OPT   - | Go and say it to the sysadmin. | sysadmin_hub
