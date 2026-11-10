# Wrist Remote

A free, open-source Garmin watch app that works as a remote for your Roku.
Tap the watch, the TV listens.

## Why I built it

I keep losing my Roku remote. Under the couch, in the kitchen, and once in the fridge while grabbing a beer.

The Roku phone app has a remote, but that means finding my phone, unlocking it and digging through the app just to skip an ad. Half the time I'd end up doom scrolling and miss important details of the movie I'm watching.

The one thing I never lose is my Garmin watch. It is like a part of me now and only comes off to charge every couple of weeks. So I built a remote for it.

I wanted it to be simple, private and easy on the battery. It only talks to your own Roku on your home network, and nothing else.

No ads, no subscription, always open source.

## Features

- Up, down, left, right and OK
- Back, Home and Play/Pause
- Volume up, down and mute (optional, for Roku TVs)
- A room name at the top so you know which Roku you're on
- First-run setup that asks if you have a Roku TV or a stick/box
- Clear help screens when something goes wrong, with steps to fix it
- Settings on the watch: see your Roku's IP, name and device type, with
  steps to change them
- A tip jar (QR code + Open on phone) in settings

## How it works

Watch → Bluetooth → Garmin Connect on your iPhone → home Wi-Fi → Roku

The watch can't get on Wi-Fi by itself, so each button press goes through
Garmin Connect on your phone. The phone sends it to your Roku using Roku's
built-in network control (ECP, port 8060). The phone has to be on the same
Wi-Fi as the Roku.

## What you need

- A Roku on your home Wi-Fi with network control turned on:
  Settings › System › Advanced system settings › Control by mobile apps ›
  Network access › Enabled
- An iPhone with Garmin Connect, on the same Wi-Fi as the Roku
- When iOS asks if Garmin Connect can use your Local Network, tap Allow.
  The watch can't reach the Roku without it.

## Setup

1. On the Roku, find its IP in Settings › Network › About.
   It looks something like 192.168.1.42.
2. On your phone, open the Connect IQ app, then Device › My Device Apps ›
   Wrist Remote › Settings. Enter the IP, then tap Save.
3. Optional: add a room name, something generic like "Living room". It
   shows at the top of the watch screen. Leave it blank and it just says
   Roku.
4. Open Wrist Remote on the watch and pick Roku TV or Roku stick or box.

## Privacy and security by design

- No accounts, analytics, ads, crash reporting or third-party code.
- The app only talks to the one IP you set, and only to send a key press.
  It only accepts home-network IPs (10.x, 172.16-31.x, 192.168.x).
- It can only send keys from a fixed list and never builds a request from
  text you type. v1 never launches channels. The planned app shortcuts
  (v3) will only launch apps from a fixed list.
- Your IP and room name live in the app's settings. They're never logged.
- The watch counts successful button presses, only to know when to show
  the tip jar (once each at 30, 150 and 500 presses). The count stays on
  the watch and is never sent anywhere.
- Open on phone, on the tip jar screen, hands your phone one fixed Ko-fi
  link, and only when you tap it.

## Battery

- Runs only while it's open. No background work, no glance.
- No polling. The network is used only when you press a button.
- No GPS, heart rate or other sensors.
- Dark screens. A long room name scrolls twice, then stops.
- One failed send shows an error. No retry loops.
- Goes back to the watch face after about 5 minutes without a press.

## Supported watches

- Venu Sq 2: tested on a real watch.
- Forerunner 265, Venu 3: tested in the Garmin simulator.
- fēnix 7: tested in the simulator. Colours may look off on its 64-colour screen; a fix is planned.

## Limits

- iPhone only for now. Garmin Connect on Android only allows HTTPS, and the
  Roku only speaks plain HTTP on your network.
- Volume works on Roku TVs. On sticks it depends on your TV, so setup
  turns it off. To try it anyway, turn on "Show volume buttons" in the
  Connect IQ app (Device › My Device Apps › Wrist Remote › Settings) and
  CEC TV Volume on the Roku.
- Your phone has to be within Bluetooth range of the watch.
- One Roku at a time for now.

## Build it yourself

- Install the Connect IQ SDK.
- Make your own developer key and keep it outside the repo. Never commit
  it. The .gitignore blocks the usual key files.
- Build with
  `monkeyc -d venusq2 -f monkey.jungle -o bin/WristRemote.prg -y <path to your key>`
  and swap venusq2 for your watch. Or use the Monkey C extension in VS Code.

## Roadmap

- v2: more than one Roku, and Find my Roku
- v3: more controls
- Later: TVs through Home Assistant

## Support

It's free. If it's useful to you, you can buy me a coffee at
[ko-fi.com/njinsapps](https://ko-fi.com/njinsapps).

## License

Copyright (C) 2026 Njins00

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

Full text in [LICENSE](LICENSE).

## Not affiliated

Not affiliated with or endorsed by Roku, Inc. or Garmin. Roku and Garmin
are trademarks of their owners.
