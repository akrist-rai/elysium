# ---------------------------------------------------------------------------
# The bag.
#
# Every tool in here behaves the way it behaves on a real job, including the
# parts that are tedious. A switch is not a hub. TLS does not open because you
# would like it to. A cloned card is somebody's name in somebody's log.
#
# Entry node: station_self
# ---------------------------------------------------------------------------

:: station_self
SAY   Narrator | You take stock of the person who is going to be doing this. Canvas bag, one strap, worn pale where it crosses the chest. Nothing in it is illegal on its own.
VOICE Encyclopedia 9 | Nothing in it is illegal on its own. That sentence is the entire legal theory of your profession and it has never once been tested on your behalf.
VOICE Composure 8 | Bag round to the front, under the coat, opened at hip height. You have done this on trains, in stairwells, once in a hospital. Nobody has ever looked.
OPT   - | Open the bag. | station_bag

:: station_bag
SAY   Narrator | The laptop, and the four things that make the laptop worth carrying.
VOICE Interfacing 7 | You know the weight of this bag to within about forty grams. You would notice a missing cable by feel before you noticed it by sight.
OPT   - | The laptop. | station_laptop
OPT   - | The sunglasses case that is not sunglasses. | station_proxmark
OPT   - | The grey USB stick. | station_ducky
OPT   - | The certificate you made this morning. | station_burp
OPT   - | Close the bag. | END

# ===========================================================================
# The machine
# ===========================================================================

:: station_laptop
DO    ITEM:field_laptop
SAY   Narrator | Fourteen inch, matte black, every sticker taken off with a thumbnail so that it photographs as nobody's. It boots in nine seconds to a prompt that does not say whose it is.
VOICE Interfacing 8 | Wireless card that will do monitor mode. That is the whole reason you own this specific unpleasant laptop instead of a nicer one.
VOICE Half Light 10 | Screen brightness. You are in a marble room with nine other people and you are about to open a terminal. Turn it down before you turn it on.
OPT   - | Turn the brightness down and open a terminal. | station_wifi
OPT   Composure 9 | Sit on the bench first. Standing men with laptops get looked at. | station_bench
OPT   - | Put it away. | station_bag

:: station_bench
DO    SET:sat_down
SAY   Narrator | You sit on the westbound bench like a man waiting for a train that is coming, which is a lie told entirely with posture, and it is the most effective thing you will do all night.
VOICE Savoir Faire 9 | Ankle over knee, laptop on the thigh, screen tilted away from the hall. From six metres you are checking football scores.
VOICE Esprit De Corps 10 | The two who stood up when the shutter came down have sat back down because you sat down. You have just told nine people that this is fine. You have no idea whether it is fine.
OPT   - | Open a terminal. | station_wifi

:: station_wifi
SAY   Narrator | VOSKRESENSKAYA-FREE, open, no key, sixty-eight clients. It hands you an address in about a second and a half and then a captive portal wants your phone number.
VOICE Interfacing 9 | The portal is a web page, and the page is being served by the thing that is also doing your DNS. Do not give it a phone number. Give it a DNS query and see