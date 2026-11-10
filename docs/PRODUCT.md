# Wrist Remote: product notes

## Problem

The Roku remote is never where you are. The phone app works, but you have
to find the phone, unlock it and open the app just to pause. A Garmin
watch is already on your wrist, but there was no simple, private way to
use it as a Roku remote.

## Users

- Garmin watch owners with a Roku and an iPhone
- People who want the everyday buttons (move, OK, back, home, play/pause,
  volume), not a full replacement for the remote
- People who care about battery life and don't want a watch app phoning
  home

## Key decisions and trade-offs

- **iPhone only at launch.** Garmin Connect on Android only allows HTTPS,
  and Roku's local control is plain HTTP. Adding a relay or a cloud hop
  would break the "only talks to your Roku" promise, so Android waits.
- **Fixed key list, no free text.** Only a short list of key presses can
  ever be sent. v1 never launches channels. The planned app shortcuts (v3)
  will only launch apps from a fixed list. Smaller feature set, much
  smaller attack surface.
- **Home-network IPs only.** The app refuses anything that isn't 10.x,
  172.16-31.x or 192.168.x, so it can't be pointed at the internet.
- **Network only on a press.** No polling, no status checks, no background
  work. The trade-off is that the app doesn't show if the Roku is on until
  you press something.
- **No retries.** One failure shows a help screen with steps. Retry loops
  drain the battery and hide real problems.
- **TV or stick picked at setup.** Volume over a stick depends on the TV
  (HDMI-CEC) and failed in testing, so sticks start with volume buttons
  off. You can still turn them on.
- **Auto-exit after about 5 minutes idle.** A remote left open shouldn't
  cost battery.
- **Short marquee.** Long room names scroll twice, then stop. Readable
  without a timer running all the time.
- **No analytics.** Even the tip-jar counter stays on the watch. The cost
  is that I learn less about how people use it (see below).
- **Tip jar, not ads or paid tiers.** Free and open source. The tip screen
  shows at most three times (30, 150, 500 presses) and anytime from
  settings.
- **Changed after testing:** the first settings design used cards. Text
  overlapped and got cut on real screens, so I rebuilt it as a simple list.
- **Changed after testing:** a "Sent" toast after every press was noise.
  Now success is just a short button flash, and only errors show a message.

## What I'd measure after launch

There's no telemetry, so only public or opt-in signals:

- Store installs and active users, from the Connect IQ developer dashboard
- Ratings and reviews, and how many mention setup trouble
- GitHub issues: setup problems, watch requests, Android requests
- Which watches people ask for, to decide what to add next
- Ko-fi tips, as a rough sign it's worth keeping up

## Roadmap

- v2: more than one Roku, and Find my Roku
- v3: more controls
- Later: TVs through Home Assistant, through the same single connector
  module
