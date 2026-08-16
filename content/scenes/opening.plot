# ---------------------------------------------------------------------------
# Opening. You wake up. Your skills have been awake longer than you have and
# they have opinions about the delay.
# ---------------------------------------------------------------------------

:: wake
SAY   Narrator | Nothing. A warm, total, load-bearing nothing.
VOICE Inland Empire 6 | Stay here. It is very good here. There is a floor and the floor has agreed to hold you and that is the whole arrangement.
VOICE Volition 8 | No. Something in this room is wrong and you are lying in it.
OPT   - | Stay in the nothing. | wake_stay
OPT   Volition 7 | Open your eyes. | wake_open

:: wake_stay
SAY   Narrator | You stay. The nothing gets thinner, the way nothing always does. Underneath it there is a hum, and under the hum there is a smell of hot dust and cold coffee.
VOICE Electrochemistry 8 | Something wonderful happened tonight. You cannot recall a single detail of it and it has left you a headache shaped like a receipt.
VOICE Half Light 10 | Get up. GET UP. Something is standing over you.
GOTO  wake_open

:: wake_open
SAY   Narrator | Ceiling tiles. One of them has been lifted out and put back crooked. A fluorescent tube flickers at a rate designed by nobody.
VOICE Perception 8 | Carpet tile against your cheek. Static. Cable dust. You have been down here between eight and twenty minutes.
VOICE Shivers 11 | The building is running. Everything in it is running. Only this room has stopped.
OPT   - | Sit up. | wake_sit

:: wake_sit
DO    SET:awake SET:sysadmin_present TASK:establish_self
SAY   Narrator | You sit up. The room arranges itself around you in the order your brain can afford: racks, desk, a person at the desk, a person standing over you holding two cups of coffee.
SAY   The Sysadmin | Oh good. I was about ninety seconds from calling somebody who would have made this a much longer night for both of us.
VOICE Composure 10 | Say nothing yet. Whatever you say first will be quoted back to you for the rest of your life.
VOICE Empathy 9 | They are not frightened. They are tired in the specific way of somebody who has been managing a problem alone for forty minutes.
OPT   - | "Who are you?" | wake_who
OPT   - | "Who am I?" | wake_whoami
OPT   Authority 8 | "Nobody touch anything. This is a scene." | wake_authority

:: wake_who
SAY   You | "Who are you?"
SAY   The Sysadmin | "I run the machines. That is the entire job description and I would like it to stay that way." They hand you a coffee. "You are the invigilator. Allegedly."
VOICE Rhetoric 9 | Allegedly. They put a whole sentence of doubt into four syllables and then handed you a hot drink so you could not object.
OPT   - | "Why allegedly?" | wake_allegedly
OPT   - | "Who am I?" | wake_whoami

:: wake_allegedly
SAY   The Sysadmin | "Because for the last hour the invigilator has been a coat on the floor. I am prepared to be generous about that if you are prepared to be useful about it now."
DO    THOUGHT:the_invigilator
VOICE Volition 9 | Take the deal. Take it fast, before you have time to be proud about it.
OPT   - | "I'm prepared." | wake_situation
OPT   Drama 9 | "I was working. From the floor. It is a technique." | wake_drama

:: wake_drama
SAY   You | "I was working. From the floor. It's a technique."
SAY   The Sysadmin | They look at you for exactly as long as that deserves. "Right."
VOICE Drama 9 | They did not believe it. They were also not going to argue with it, and that is nearly as good.
VOICE Composure 12 | You are going to have to earn back every inch of that, and it is going to take the whole night.
OPT   - | "Fine. Tell me what happened." | wake_situation

:: wake_whoami
SAY   You | "Who am I?"
SAY   The Sysadmin | A pause exactly one beat too long. "You are the invigilator. You have a badge somewhere and a clipboard you never used." Another pause. "You do not remember your name."
VOICE Volition 11 | It is in there. It is behind a door and the door is warm to the touch.
VOICE Inland Empire 12 | You will get it back tonight, in the worst possible way, at the worst possible moment. That is how names come back.
OPT   - | "It'll keep. Tell me what happened." | wake_situation
OPT   - | "That's a problem for later." | wake_situation

:: wake_authority
SAY   You | "Nobody touch anything. This is a scene."
SAY   The Sysadmin | "There are two people in the room and one of them is unconscious, so I assume you mean me." They do not put the coffee down. "Fine. I have touched nothing since 02:20."
VOICE Authority 8 | It landed. Badly, sideways, but it landed, and they are following the instruction.
VOICE Half Light 11 | They said 02:20 without being asked what time anything happened. People who volunteer timestamps have been rehearsing.
DO    SET:sysadmin_gave_time
OPT   - | "Start from the beginning." | wake_situation

:: wake_situation
DO    SET:knows_frozen TASK:explain_the_freeze TASK:check_the_contestant
SAY   The Sysadmin | "Beginning. TechHunt runs from eight last night to six this morning. Seven questions, released in order, each one gated on the last. At 02:14 the scoreboard stopped updating."
SAY   The Sysadmin | "Not crashed. Stopped. The site serves, people log in, nothing errors. It simply will not accept another submission, and it will not tell anyone why."
VOICE Logic 9 | Serving but not accepting. That is not a crash. A crash takes the whole thing down. This is something narrower and much more deliberate.
VOICE Interfacing 12 | Something has a hand on a row and will not let go.
OPT   - | "And the person at the desk?" | wake_the_desk
OPT   Logic 9 | "Stopped is not crashed. What is holding it?" | wake_holding

:: wake_holding
SAY   You | "Stopped isn't crashed. Something's holding it."
SAY   The Sysadmin | Their eyebrows move about a millimetre, which from them is applause. "That is what I think too. I have not been able to prove it and I have not wanted to touch the database while a competition is live."
DO    SET:suspects_lock
VOICE Esprit De Corps 12 | Somewhere in a hall of residence, four hundred metres away, sixty students are refreshing a page that is never going to change, and typing into a group chat that this is rigged.
OPT   - | "And the person at the desk?" | wake_the_desk

:: wake_the_desk
SAY   The Sysadmin | "Priya Raghunathan. Top of the board since about eleven. She has been at that desk for nineteen hours and she went face down at some point after two."
SAY   The Sysadmin | "She is breathing. I checked. I checked four times. I would very much like somebody other than me to have also checked."
VOICE Empathy 10 | That is the actual reason they are still standing in this room. Not the scoreboard. Her.
VOICE Half Light 12 | BREATHING IS NOT THE SAME AS FINE.
OPT   - | "I'll check." | wake_finish
OPT   Empathy 9 | "You have been alone with this for forty minutes." | wake_alone

:: wake_alone
SAY   You | "You've been alone with this for forty minutes."
SAY   The Sysadmin | "Forty-six." They finally drink some of their own coffee. "It has been a long forty-six minutes and I have spent a lot of it deciding whether you were dead too."
VOICE Empathy 11 | Do not make a joke. They have earned better than a joke.
VOICE Suggestion 10 | Agree with them about the time. Agreeing about small verifiable things is how you get to ask about large unverifiable ones later.
OPT   - | "Forty-six. Noted. I'll check on her." | wake_finish

:: wake_finish
DO    SET:briefed
SAY   The Sysadmin | "I will be by the racks. I am not going to hover." A beat. "I am going to hover a little."
VOICE Volition 8 | Stand up properly. Feet under you. Whatever else is true, the standing part is available.
SAY   Narrator | You stand up in a room that has stopped, next to a competition that has stopped, next to a woman who has stopped, and the only thing still running is the hardware.
END
