# WebBlock — Open and Run in Xcode

## One-step open
1. Unzip `WebBlockiOS-Xcode-Ready.zip` on your Mac.
2. Open the `WebBlockiOS` folder and double-click **`WebBlock.xcodeproj`** (the blue Xcode project icon). **Do not open the enclosing folder alone.**
3. In Xcode's toolbar, choose the **WebBlock** scheme and an available **iPhone Simulator**.
4. Press **⌘R** (or Product > Run).

Minimum iOS: 17. No XcodeGen or third-party packages required.

## If you cannot see an iPhone simulator
Go to **Xcode > Settings > Components** and install an iOS simulator runtime. Choose a device under **Window > Devices and Simulators**.

## If you see a signing issue
For simulator use, choose an iPhone **Simulator**, not a physical device or 'Any iOS Device'. For running on your own iPhone, choose the WebBlock target > Signing & Capabilities, enable Automatically manage signing, and select your team.

## Demo behavior
Mock in-memory service, no live backend. Sign in with any email containing `@` and a password of 8+ characters.
Use an email starting with `pro` or `ultra` to see those plans' Monitor limits. See README.md.

## Verification status
- `project.pbxproj` regenerated for the 17 Swift files in this folder; every object reference checked.
- Swift was **not compiled** here (no Xcode/iOS SDK in the authoring environment). If Xcode reports an error, copy the **first error** from the Issue Navigator (⌘5).
