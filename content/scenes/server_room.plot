# ---------------------------------------------------------------------------
# The room. Eight things in it, each of which is a sentence somebody left
# unfinished.
# ---------------------------------------------------------------------------

# ===========================================================================
# YOURSELF
# ===========================================================================

:: yourself
SAY   Narrator | You take stock of the person doing the investigating. It is not encouraging.
VOICE Perception 8 | Lanyard, no badge on it. Coat that has been slept in. A cuff stiff with something you are choosing not to identify yet.
VOICE Electrochemistry 7 | There is a shape in your inside pocket and you already know what it is and you are already reaching for it.
VOICE Volition 10 | You do not have to reach for it.
OPT   - | Check the inside pocket. | yourself_flask
OPT   Volition 10 | Do not check the inside pocket. | yourself_refuse
OPT   - | Check the lanyard instead. | yourself_lanyard

:: yourself_flask
DO    ITEM:hip_flask SET:found_flask
SAY   Narrator | A hip flask. Empty. Your initials are on it, which is presently the strongest evidence available as to what your initials are.
VOICE Electrochemistry 8 | It was full at eight. It is empty at three. You did excellent work tonight and none of it was the work.
VOICE Composure 12 | Put it away before the sysadmin turns around.
VOICE Volition 11 | This is the thing. This is the whole thing. You have been holding the answer to "where were you" in your coat the entire time.
OPT   - | Put it away. | yourself_lanyard
OPT   Pain Threshold 9 | Look at it for a while longer. | yourself_stare

:: yourself_stare
DO    THOUGHT:the_invigilator MORALE:-1
SAY   Narrator | You look at it for a while longer. Nothing about it changes and neither do you.
VOICE Pain Threshold 9 | Good. Feel it properly now, in one piece, rather than in instalments all night.
VOICE Inland Empire 11 | The flask is not the reason you were on the floor. You will find that out later and it will not be a relief.
OPT   - | Put it away. | yourself_lanyard

:: yourself_refuse
DO    SET:refused_flask XP:20
SAY   Narrator | You take your hand out of your coat. The shape stays in the pocket, unexamined, and something in your chest unclenches by about four percent.
VOICE Volition 10 | Filed. That is one.
VOICE Electrochemistry 9 | Cheap. Petty. You will be back within the hour and we both know it.
OPT   - | Check the lanyard. | yourself_lanyard

:: yourself_lanyard
SAY   Narrator | The lanyard is university issue, blue, printed with a sponsor's name. The plastic sleeve at the end is empty.
VOICE Visual Calculus 11 | The sleeve is stretched at the top. The card was not taken out gently, and it was not taken out by somebody standing in front of you.
VOICE Logic 10 | Either you lost your badge tonight, or somebody took it. Both of those are worth knowing and only one of them is your fault.
DO    SET:badge_missing
OPT   - | Enough self-examination. | END
OPT   Inland Empire 10 | Ask the room what your name is. | yourself_name

:: yourself_name
SAY   Narrator | You stand still and let the room have a go at it.
VOICE Inland Empire 10 | Nothing. The room does not know either. The room has met four hundred people this year and you were not the memorable one.
VOICE Shivers 12 | Down the corridor, in the office with the printer, there is a duty roster on a wall with your name on it, in a column headed 20:00-06:00, and it is the only place in the building where you currently exist.
DO    SET:knows_roster
OPT   - | Sit with that. | END
