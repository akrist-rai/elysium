# ---------------------------------------------------------------------------
# The sysadmin. The one person in the building who will tell you the truth
# whether or not you have earned it.
# ---------------------------------------------------------------------------

:: sysadmin_hub
SAY   The Sysadmin | They are leaning against cabinet six with a mug of something that stopped being hot a while ago. "Go on then."
VOICE Empathy 9 | They want you to have found something. They are braced for you not to have.
OPT   NOT:asked_name ONCE | "What is your name?" | sysadmin_name
OPT   IF:knows_frozen NOT:asked_freeze | "Tell me about the freeze." | sysadmin_freeze
OPT   IF:priya_alive NOT:asked_priya | "Tell me about Priya." | sysadmin_priya
OPT   NOT:asked_staff | "Who else has staff access tonight?" | sysadmin_staff
OPT   IF:knows_mismatch NOT:told_mismatch | "The transcript for question seven is a decoy." | sysadmin_mismatch
OPT   IF:knows_lock NOT:told_lock | "The board is not broken. Somebody is holding it." | sysadmin_lock
OPT   IF:found_the_badge NOT:asked_badge | Show them the snapped badge. | sysadmin_badge
OPT   IF:knows_arjun | "I know who did it." | finale_open
OPT   - | "Nothing yet." | sysadmin_nothing

:: sysadmin_nothing
SAY   You | "Nothing yet."
SAY   The Sysadmin | "Right." They drink the cold thing. "Well. It is quarter past three and the competition ends at six, so."
VOICE Composure 10 | Not a rebuke. Just a clock, read out loud, by somebody who has been watching it longer than you have.
OPT   - | Go back to it. | END

:: sysadmin_name
DO    SET:asked_name
SAY   The Sysadmin | "Deshmukh. I have been introduced to you twice." A pause that is almost kind. "Once tonight."
VOICE Composure 11 | Do not apologise. They did not bring it up to collect an apology.
VOICE Empathy 10 | They told you anyway. Twice-forgotten and they told you anyway, flatly, without making you pay for it.
OPT   - | Continue. | sysadmin_hub

:: sysadmin_freeze
DO    SET:asked_freeze
SAY   The Sysadmin | "02:14:07, last accepted submission. After that the site serves fine, logins work, the questions load. Submissions go in and never come back."
SAY   The Sysadmin | "No errors in the log. Nothing in the error log at all, which is the part I do not like. A thing that is failing writes something down. This is not failing."
VOICE Interfacing 11 | Not failing. Waiting. There is a very short list of things a database does silently and forever, and almost all of them are locks.
OPT   Interfacing 8 | "It is waiting on a lock, not failing." | sysadmin_lockidea
OPT   - | Continue. | sysadmin_hub

:: sysadmin_lockidea
DO    SET:suspects_lock XP:20
SAY   You | "It's not failing. It's waiting. Something's got a lock and never let go."
SAY   The Sysadmin | They put the mug down for the first time since you woke up. "That is what I have thought since about half two and I have not been willing to say it, because if I am right then somebody did it on purpose."
VOICE Esprit De Corps 10 | Two people who were each holding the same unwelcome idea alone, now holding it together. That is worth more than the idea.
DO    SET:sysadmin_warmer
OPT   - | Continue. | sysadmin_hub

:: sysadmin_priya
DO    SET:asked_priya
SAY   The Sysadmin | "Third year. Does the security society thing on Wednesdays. She has been in here since eight in the morning, which is ten hours before the competition started, because she wanted the desk by the racks."
SAY   The Sysadmin | "She is the best of them by a distance and everybody including her knows it."
VOICE Empathy 10 | Said with something you would call pride if the person saying it would ever admit to it.
OPT   Empathy 9 | "You have been sitting with her since half two." | sysadmin_sitting
OPT   - | Continue. | sysadmin_hub

:: sysadmin_sitting
SAY   The Sysadmin | "I checked her four times. The fourth time I sat down and did not get up for a while." They look at the floor. "It is not in my job description, checking whether the students are alive."
VOICE Empathy 9 | It is not. They did it anyway, alone, four times, while the only other adult in the room was face down eight metres away.
DO    SET:sysadmin_warmer MORALE:1
OPT   - | Continue. | sysadmin_hub

:: sysadmin_staff
DO    SET:asked_staff
SAY   The Sysadmin | "Tonight? Me. You, notionally. And the technical lead, who wrote four of the seven questions and who is not here."
VOICE Perception 10 | Not here. Said neutrally. Too neutrally, from somebody who has been unable to keep an opinion off their face all night.
OPT   Empathy 10 | "You do not like him." | sysadmin_dislike
OPT   Rhetoric 9 | "Where is he supposed to be?" | sysadmin_where
OPT   - | Continue. | sysadmin_hub

:: sysadmin_dislike
SAY   The Sysadmin | "I do not have to like him. He is good. Everyone says he is good, mostly him." A shrug that costs them something. "He built the bulk upload tool. He built the asset pipeline. He built most of what is holding this evening up."
VOICE Rhetoric 11 | Every sentence is a compliment and every one of them is being carried at arm's length.
VOICE Logic 10 | Also: he built the bulk upload tool, and he built the asset pipeline, and both of those have come up tonight.
DO    SET:knows_he_built_it
OPT   Rhetoric 9 | "Where is he supposed to be?" | sysadmin_where
OPT   - | Continue. | sysadmin_hub

:: sysadmin_where
DO    SET:knows_hes_remote
SAY   The Sysadmin | "Home. He signed off at half nine and said he would be on call. He has admin on everything from wherever he happens to be sitting, because that was the arrangement everyone agreed to in July."
VOICE Half Light 11 | On call. From a sofa. With admin on everything, on the one night of the year when the numbers are worth something.
OPT   - | Continue. | sysadmin_hub

:: sysadmin_mismatch
DO    SET:told_mismatch
SAY   You | "The transcript for question seven is a decoy. The flag is in the audio and the transcript has it cut out and marked inaudible."
SAY   The Sysadmin | They go very still. "The transcript is the accessible version. That is the whole reason it exists. We had a whole meeting about it in July."
VOICE Empathy 10 | That is the thing that got them. Not the theft. The specific shape of it.
SAY   The Sysadmin | "Who uploaded it."
OPT   IF:knows_uploader | "The technical lead. At 01:58 tonight." | sysadmin_uploader_known
OPT   NOT:knows_uploader | "I cannot get at the metadata. It is admin-gated." | sysadmin_offers_admin

:: sysadmin_offers_admin
DO    SET:found_the_badge SET:sysadmin_gave_admin XP:25
SAY   The Sysadmin | They are already walking to the console. "I have admin. I have had admin this entire time and it has not occurred to either of us to say so."
SAY   Narrator | They pull up the asset record, turn the monitor towards you, and step back with their hands visibly off the keyboard, which is a courtesy you did not know you needed.
VOICE Interfacing 10 | The metadata panel is open. Go and read it properly.
OPT   - | Go and read it. | monitor_whomade
OPT   - | Continue. | sysadmin_hub

:: sysadmin_uploader_known
SAY   The Sysadmin | They do not say anything for four seconds. "At 01:58. Six hours into a ten-hour competition."
VOICE Rhetoric 10 | They are not arguing. That is not the same as agreeing, and you should not spend it as though it were.
OPT   - | Continue. | sysadmin_hub

:: sysadmin_lock
DO    SET:told_lock
SAY   You | "The board is not broken. There is an open transaction from 02:14 that never committed, and everything else is queued behind it."
SAY   The Sysadmin | "Show me."
SAY   Narrator | You show them. They read it twice, and on the second pass their jaw does something.
SAY   The Sysadmin | "That is our own admin tooling. That is the bulk upload path. It opens a transaction and it is supposed to close it in about forty milliseconds."
DO    SET:sysadmin_warmer XP:25
OPT   - | Continue. | sysadmin_hub

:: sysadmin_badge
DO    SET:asked_badge
SAY   Narrator | You hold out the snapped badge with the scraped name and the intact photograph.
SAY   The Sysadmin | They look at the photograph, and then at you, and then back. "That is you."
OPT   - | "I know." | sysadmin_badge_know
OPT   Drama 10 | "It was on the stairwell. I have no idea how it got there." | sysadmin_badge_lie

:: sysadmin_badge_know
SAY   You | "I know."
SAY   The Sysadmin | "It is snapped. Somebody snapped your badge and took the name off it and put it on a fire escape." A long pause. "You did not fall over, did you."
VOICE Volition 11 | No. You did not fall over.
DO    SET:sysadmin_knows_assault
OPT   - | "No. I do not think I did." | sysadmin_badge_truth
OPT   Volition 10 | "I do not know yet. Ask me at six." | sysadmin_badge_defer

:: sysadmin_badge_truth
DO    SET:sysadmin_warmer MORALE:1 XP:30
SAY   The Sysadmin | "Right." They pick their mug back up, mostly for something to do with their hands. "Then we are not investigating a scoreboard, are we."
VOICE Esprit De Corps 9 | For the first time tonight somebody else is carrying half of it.
OPT   - | Continue. | sysadmin_hub

:: sysadmin_badge_defer
SAY   The Sysadmin | "Fine." They accept it without pushing, which is more generous than you deserve and you both know it.
VOICE Composure 10 | Bought. Three hours. Spend them.
OPT   - | Continue. | sysadmin_hub

:: sysadmin_badge_lie
DO    MORALE:-1
SAY   The Sysadmin | "You have no idea." They let that sit in the room until it is uncomfortable for everybody. "All right."
VOICE Drama 10 | They did not buy it. Worse - they have decided not to make you defend it, which means they have quietly moved you into a different category.
VOICE Volition 11 | You had one honest thing available tonight and you spent it on that.
OPT   - | Continue. | sysadmin_hub

# ===========================================================================
# THE ACCUSATION
# ===========================================================================

:: finale_open
SAY   You | "I know who did it."
SAY   The Sysadmin | They put the mug down. Properly, this time, on a flat surface, at a distance from the edge. "Then say it. Out loud, to me, so that one of us has heard it."
VOICE Composure 11 | Whatever you say next goes in a report, and the report goes to a disciplinary panel, and you will be asked to stand behind every word of it in a room with a table in it.
VOICE Volition 10 | You have the shape. Say the shape.
VOICE Half Light 13 | Or do not. You could hand them the facts and let them draw it. Nobody would ever know you flinched except you.
OPT   - | Lay out the whole case. | finale_case
OPT   - | "Actually - give me a few more minutes." | sysadmin_hub

:: finale_case
SAY   Narrator | You lay it out. The whiteboard note scheduling a decoy transcript for two in the morning. The upload at 01:58. Priya's last page at 02:12. The half-typed flag at 02:13. The transaction opened at 02:14 from an address across the city, holding the door shut. guest_0, created inside that same transaction, first-solving question seven at 02:49 on the largest pool of the night.
SAY   The Sysadmin | "And the name."
CHECK Rhetoric RED 14 +1:knows_mismatch +1:knows_lock +1:knows_method +2:knows_uploader +1:knows_motive +1:found_the_badge +1:knows_handwriting | Name the technical lead. | finale_pass | finale_fail

:: finale_pass
DO    SET:solved TASKDONE:name_them TASKDONE:find_the_intruder XP:60
SAY   Narrator | You put it together in the right order, and you do not hedge, and you do not soften the part that implicates a colleague of theirs.
SAY   The Sysadmin | They listen all the way to the end without interrupting once, which is the hardest thing anybody has done in this room tonight.
SAY   The Sysadmin | "Yes." Just that. Then, after a moment: "I will kill the transaction. The board comes back and every submission behind it lands in the order it arrived, which means her 02:13 goes in before his 02:49."
VOICE Logic 9 | The queue preserved the order. He held the door for thirty-five minutes and the queue remembered who was in front the entire time.
VOICE Conceptualization 12 | He understood the system well enough to abuse it and not well enough to beat it. Those turn out to be different amounts of understanding.
OPT   - | "Do it." | finale_resolve

:: finale_fail
DO    SET:accused_badly MORALE:-2 TASKFAIL:name_them XP:15
SAY   Narrator | You have all of it and you put it in the wrong order. You lead with the badge, which is about you, and by the time you reach the transaction you are arguing instead of explaining.
SAY   The Sysadmin | "Stop." Not unkindly. "You are telling me a story about your night. I need the thing that goes in a report."
VOICE Rhetoric 10 | You had it. It was in your hands and you dropped it doing the presentation.
VOICE Volition 12 | It is still true. Being bad at saying it does not make it less true. It just means somebody else says it now.
OPT   - | Let them take it. | finale_handover
OPT   Volition 11 | "Then take the facts off me and file it yourself." | finale_handover

:: finale_handover
DO    SET:solved
SAY   The Sysadmin | They take out a phone, and start typing, and read it back to you flatly as they go - your evidence, in their order, without a single sentence about you in it.
SAY   The Sysadmin | "Transcript asset replaced 01:58 by staff account. Transaction opened 02:14:07 from external address via bulk upload tooling, uncommitted. Account guest_0 created within that transaction. Question seven submission accepted 02:49." They look up. "That is the report."
VOICE Composure 11 | That is what it was supposed to sound like.
VOICE Empathy 10 | And they did not put your name in it. Not the badge, not the floor, not the flask. That was a decision and they made it in about a second.
OPT   - | "Kill the transaction." | finale_resolve

:: finale_resolve
SAY   Narrator | They kill the transaction. It takes four seconds and one confirmation prompt.
SAY   Narrator | The wall display shudders, and thirty-five minutes of queued submissions land at once, in the order they arrived. The clock in the corner rolls forward from 02:14 to 03:22 in one movement.
SAY   Narrator | Question seven, first solve: RAGHUNATHAN, P. 02:13.
VOICE Esprit De Corps 8 | Four hundred metres away, sixty phones buzz at the same time.
OPT   - | Look at the desk. | finale_priya

:: finale_priya
SAY   Narrator | At the desk, Priya makes a small sound and does not wake up. Her machine, still logged in, still holding a half-typed flag in a box, updates in front of her.
VOICE Empathy 9 | She will find out at seven. She will be furious about the four hours and then she will be first, and the second one is going to last longer.
OPT   IF:covered_her | Straighten your coat on her shoulders. | finale_coat
OPT   - | Say something to the sysadmin. | finale_last

:: finale_coat
SAY   Narrator | You straighten the coat where it has slipped off one shoulder. The flask in the inside pocket knocks against the desk leg, once, quietly.
VOICE Electrochemistry 9 | Still there. Still empty. Still yours.
VOICE Volition 10 | Later. Not tonight. Tonight there is a stairwell and a snapped badge and a man on a sofa four kilometres away.
OPT   - | Say something to the sysadmin. | finale_last

:: finale_last
SAY   The Sysadmin | "It is twenty past three." They pick the mug up, look into it, and put it down again. "Competition ends at six. You are the invigilator."
VOICE Volition 9 | Two hours and forty minutes. Awake, upright, in the room. That is the entire job and it has been available the whole time.
OPT   - | "I'm the invigilator." | finale_end
OPT   IF:found_flask | Take the flask out of the coat and put it in the bin. | finale_bin

:: finale_bin
DO    TAKEITEM:hip_flask SET:binned_flask MORALE:1 XP:40
SAY   Narrator | You take it out of the coat pocket without looking at Priya, and you drop it in the bin by the door, where it makes an extremely loud noise in a quiet room.
SAY   The Sysadmin | They do not turn around. "Bin's emptied at six."
VOICE Volition 10 | Two hours and forty minutes to change your mind, and a witness who will not mention it either way.
VOICE Electrochemistry 11 | We will discuss this on Thursday.
OPT   - | "I'm the invigilator." | finale_end

:: finale_end
SAY   Narrator | You stand in the middle of Server Room B at twenty past three in the morning, with a name you still cannot produce on demand, next to a scoreboard that has started moving again.
SAY   Narrator | Somewhere across the city a man is asleep on a sofa and does not yet know that the queue remembered.
SAY   Narrator | The hum goes on. The tube flickers. Two hours and forty minutes.
END
