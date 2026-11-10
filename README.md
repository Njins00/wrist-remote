# Wrist Remote

A free, open-source Garmin watch app that works as a remote for your Roku,
over your home Wi-Fi.

Still in development. Only runs on the Venu Sq 2 for now.

## What you need

- A Roku on your home Wi-Fi, with network control turned on:
  Settings › System › Advanced system settings › Control by mobile apps ›
  Network access › Enabled
- An iPhone with Garmin Connect, on the same Wi-Fi as the Roku.
- When iOS asks if Garmin Connect can use your Local Network, tap Allow.
  The watch can't reach the Roku without it.

## Setup

1. On the Roku, find its IP in Settings › Network › About.
   It looks something like 192.168.1.42.
2. On your phone, open the Connect IQ app, then Device › My Device Apps ›
   Wrist Remote › Settings. Enter the IP, then tap Save.
3. In the same settings you can add a room name, something generic like
   "Living room". It shows at the top of the watch screen. Leave it blank and
   it just says Roku.

## Tips

- To let the remote wake your TV, try turning on CEC with 1-Touch Play and
  TV Power, and power the stick from a wall adapter instead of the TV's USB
  port.
- Volume works on Roku TVs. On sticks it depends on your TV: turn on CEC TV
  Volume on the Roku and try it.

## Privacy

- No accounts, no analytics, no ads, no logging.
- The watch only sends key presses to your Roku's IP on port 8060, through
  the Garmin Connect app on your phone. Nothing else.
- Your Roku IP and room name live in the app's settings.
- The watch counts successful button presses, only to know when to show
  the Tip jar screen. The count stays on the watch and is never sent
  anywhere.

## Limits

- Android isn't supported yet. Garmin Connect on Android needs HTTPS, and
  the Roku only speaks plain HTTP on your network.

## Building from source

- You need the Connect IQ SDK.
- Use your own developer key. Never commit keys to the repo.

## License

GPL-3.0. The LICENSE file gets added before the public release.

## Not affiliated

Not affiliated with Roku or Garmin. Roku and Garmin are trademarks of their
owners.

## Later

- Ko-fi tip jar
- Home Assistant
