# Running Qubist on your iPhone

This guide builds Qubist from Godot, through Xcode, onto your own iPhone using a free Apple ID. No paid Apple Developer Program membership is needed.

With a free Apple ID:

- The app runs for **7 days**, then stops opening. Build and run it again from Xcode to renew it.
- You can have up to 3 apps installed this way at a time.
- TestFlight and the App Store need the paid membership. See issue #40.

## What you need

- A Mac with the current **Xcode** from the Mac App Store.
- **Godot 4.3** or newer (the same version the project uses).
- An **iPhone** and a cable to connect it to the Mac.
- An **Apple ID**.

## One-time setup

### 1. Install Godot's iOS export templates

In Godot, open the project, then choose **Editor › Manage Export Templates** and click **Download and Install**. The download is large and only needed once per Godot version.

### 2. Sign in to Xcode and create a signing certificate

1. Open Xcode and choose **Xcode › Settings › Accounts**.
2. Click **+**, choose **Apple ID** and sign in.
3. Select your account, click **Manage Certificates**, then **+** › **Apple Development**. Close the dialog.

### 3. Find your Team ID

Your free account has a "Personal Team" with a 10-character Team ID.

1. Open **Keychain Access** on the Mac.
2. In **My Certificates**, double-click the certificate named **Apple Development: your name or email**.
3. The **Organizational Unit** field is your Team ID (for example `A1B2C3D4E5`).

### 4. Put the Team ID in the export preset

1. In Godot, choose **Project › Export** and select the **iOS** preset.
2. Under **Application**, set **App Store Team ID** to your Team ID.
3. Close the dialog. Godot saves it in `export_presets.cfg`. A Team ID isn't secret, so committing it is fine.

The rest of the preset is already set: bundle ID `com.nacerous.qubist`, iPhone and iPad, iOS 15 or later, Development signing, and **Export Project Only** (Godot writes an Xcode project; Xcode does the signing).

### 5. Prepare the iPhone

1. Connect the iPhone to the Mac and tap **Trust** on the phone if asked.
2. On the iPhone, turn on **Settings › Privacy & Security › Developer Mode**. The phone restarts; confirm when it asks.

## Building and running

Repeat these steps whenever you want a fresh build on the phone.

1. **Export from Godot.** Choose **Project › Export**, select **iOS**, click **Export Project…**, and save as `build/ios/Qubist.xcodeproj` in the repo folder. Keep **Export With Debug** ticked for test builds. The `build/` folder is ignored by git.
2. **Open in Xcode.** Open `build/ios/Qubist.xcodeproj`.
3. **Check signing.** Select the **Qubist** target, then the **Signing & Capabilities** tab. Tick **Automatically manage signing** and choose **your name (Personal Team)** as the Team. The bundle identifier should read `com.nacerous.qubist`.
4. **Pick the phone.** In the toolbar at the top of Xcode, choose your iPhone as the run destination.
5. **Run.** Press **⌘R**. The first build takes a few minutes.
6. **First time only: trust yourself.** The first launch is blocked with "Untrusted Developer". On the iPhone, open **Settings › General › VPN & Device Management**, tap your Apple ID under **Developer App**, and tap **Trust**. Then press **⌘R** in Xcode again.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Godot: "App Store Team ID not specified" | Do step 4 of the one-time setup. |
| Godot: export templates missing | Do step 1 of the one-time setup. |
| Xcode: "No profiles for 'com.nacerous.qubist' were found" | Tick **Automatically manage signing** and choose your Personal Team (step 3 above). |
| Xcode: "Failed to register bundle identifier" | Someone else's account already uses this ID. Change it in Godot's iOS preset (for example add your name) and export again. |
| iPhone: "Untrusted Developer" | Step 6 above. |
| App stopped opening after a week | Free-account builds expire after 7 days. Run it again from Xcode. |
| Xcode can't see the phone | Unlock the phone, reconnect the cable, and check that Developer Mode is on. |

## While you test

The greybox playtest checklist is in issue #16. Notes worth capturing on the phone:

- Does dragging a piece onto the tower feel accurate? Is 64pt of lift right?
- Is the rotate direction the one you expect?
- Do the swiper's X and Y cuts read clearly with the camera on a corner?
- Do the header, tray and controls fit your screen, including the notch and home bar?
