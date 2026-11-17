# Wrist Remote help

Setup steps and fixes for the most common problems. Still stuck? Open an issue on GitHub (please don't post your IP address or other personal details).

## Before you start

- **iPhone only.** Garmin Connect on Android blocks the kind of connection a Roku needs.
- **Same Wi-Fi.** Your phone and Roku must be on the same home Wi-Fi network, and your watch near your phone.
- **Roku network control on.** On the Roku: Settings › System › Advanced system settings › Control by mobile apps › Network access › **Enabled**. Newer Roku software sets this to Limited, which blocks remotes like this one.
- **iPhone Local Network permission** (first time only, see below).

## Setup

1. On your TV: **Settings › Network › About**. Note the **IP address**.
2. On your phone, open the **Connect IQ** app › Device › My Device Apps › **Wrist Remote** › Settings. Enter the IP and tap **Save**.
3. Open Wrist Remote on your watch and follow the steps.

## iPhone: allow Local Network for Garmin Connect

Your watch talks to the Roku through the **Garmin Connect** app on your phone (not the Connect IQ app). iPhones block apps from reaching devices at home until you allow it.

1. Open **Garmin Connect** and keep it on screen.
2. On your watch, press any button in Wrist Remote.
3. When your phone asks to find and connect to devices on your local network, tap **Allow**.

To check later: Settings › Privacy & Security › **Local Network** › Garmin Connect should be on. If Garmin Connect isn't in that list, it hasn't asked yet, so repeat the steps above.

## "Can't reach your Roku"

Go through these in order:

1. **Is the TV on** and the Roku awake?
2. **Is your phone on home Wi-Fi?** Not mobile data or a guest network. Turn off any VPN.
3. **Is Network access Enabled** on the Roku (not Limited)?
4. **iPhone:** does Garmin Connect have Local Network access? (see above)
5. **Did the IP change?** Check Settings › Network › About on the TV and compare it with the IP in the Connect IQ app settings.

## The IP keeps changing

Your router hands out addresses and can give the Roku a new one, for example after a power cut. To stop that, reserve the Roku's IP in your router's settings. It's usually called DHCP reservation, address reservation or static lease. Every router's menu is different, so check your router's manual or app.

## Volume buttons

Volume over the network only works on **Roku TVs**. On Roku sticks and boxes the TV controls the volume, so the buttons are off by default. You can try turning them on in the Connect IQ app settings (Show volume buttons). Some TVs respond, many don't.

## Page 2

Swipe up on the remote for more controls: Rewind, Play/Pause, Fast forward, Replay and Options (✱). Swipe down or press Back to return. On watches with Up and Down buttons, those switch pages too.

## Room name

Set a room name (like Living room) in the Connect IQ app settings so it shows at the top of the remote. Keep it generic and don't use personal names.

## Colours look off

Watches with MIP screens (fēnix 7 family, Forerunner 955, vívoactive 3 Music/4/4S, Enduro, quatix 7, tactix 7/8 Solar, Legacy Hero/Saga) can only show a few colours, so some greys look black. A fix is planned.

## Android

Not supported yet. Garmin Connect on Android only allows secure (https) connections, and a Roku only speaks plain http. A future Home Assistant version may work on Android.

## Privacy

No accounts, no tracking, no analytics, nothing logged. The watch only talks to your own Roku through your phone. The one exception: tapping **Open on phone** on the tip screen opens the Ko-fi page on your phone.

## Supported watches

See the [README](../README.md#supported-watches).
