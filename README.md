# WebBlock — Owner app (iOS)

The iPhone companion to the WebBlock website builder. Business owners sign in with the account they created on the
WebBlock website and manage their **live websites** on the go: products, business information and site health.

**SwiftUI · Swift 5 · iOS 17+ · MVVM with `@Observable` · no third-party packages**

---

## Features

### Getting started
- **Onboarding**: four intro pages (Your Website · How It Works · Manage · Monitor), shown once on first launch.
- **Sign in** with email and password, or **Continue with Google**.
- **Forgot password**: a three-step flow (email → 6-digit code with a countdown → new password with a strength meter).
- Accounts are created on the WebBlock website. There is no sign-up in the app.

### Your websites
- After sign-in, a **Your websites** page lists every live website, with a "Welcome back" card and a live count.
- Each website card has shortcuts straight to **Products**, **Business** or **Monitor**.
- Inside a website, a **switcher card** expands in place to show "Switch to" and your other websites.
  Switching keeps you on the same tab, and **Back** returns to the website you were on before (then to the list).
- If no website is live yet, an empty state explains how to publish one from the web.

### Portal tabs (custom glass dock)
| Tab | What you can do |
| --- | --- |
| **Products** | Search, filter by category, switch between grid and list, and view a product page with a full-width photo. Add, edit or delete products with a name, category (or a new one), description, price and a photo (JPG/PNG, up to 2 MB). |
| **Business** | See and edit what customers see: about, contact, location (with a Google Maps link) and opening hours. The name, type and website address are read-only. |
| **Monitor** | **Overview**: summary, plan usage (uptime, products, photos, redeploys, websites), health metrics and build-time chart for deploys. **Activity**: a recent activity log filtered by deploys, products or business info. |

### Everywhere
- **Bell**: notifications with unread markers. Tapping one jumps to the right website and tab.
- **Profile avatar**: a popup to log out.
- Light and dark colors, VoiceOver labels, and the dock steps aside while the keyboard is up.

---

## Run it

1. Open **`WebBlock.xcodeproj`** in **Xcode 26** or later (the iOS 26 SDK is needed for the Liquid Glass APIs).
2. Choose the **WebBlock** scheme and an **iPhone simulator** running iOS 17 or later.
3. Press **⌘R**.

To run on your own iPhone, select the WebBlock target, open **Signing & Capabilities**, turn on
*Automatically manage signing* and pick your team. More help is in [`OPEN_IN_XCODE.md`](OPEN_IN_XCODE.md).

> The project can also be regenerated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
> (`xcodegen generate`). This is optional, since the checked-in `.xcodeproj` works as is.

---

## Try it with sample data

The app runs on an in-memory **mock service**, so there's no backend to set up.

- **Sign in** with any email containing `@` and a password of **8+ characters**.
- The email decides the plan, so you can compare Monitor limits:

  | Email starts with | Plan |
  | --- | --- |
  | `ultra…` (e.g. `ultra@test.com`) | Ultra |
  | `pro…` (e.g. `pro@test.com`) | Pro |
  | anything else | Plus |

- **Forgot password** accepts any 6-digit code.
- Sample websites: **Petal & Stem** (florist), **Golden Crumb Bakery**, **Bean & Brew Café** and **Studio Lotus Yoga**,
  each with its own products and photos.
- To see onboarding again, delete the app from the simulator (it's remembered with `@AppStorage("hasSeenOnboarding")`).

Anything invented for the demo is marked `// SAMPLE` in the code.

---

## Project structure

```
WebBlock/
├── WebBlockApp.swift                 App entry point
├── Core/Theme.swift                  Colors (light + dark), spacing, radii, liquid-glass helpers, backdrops
├── Models/Models.swift               Plain value types: Website, Product, BusinessInfo, MonitorSnapshot, PlanTier…
├── Services/
│   ├── WebBlockService.swift         Service protocol + ServiceLocator  ← plug the real API in here
│   └── MockWebBlockService.swift     Sample data and rules (SAMPLE)
├── ViewModels/
│   ├── AppState.swift                Signed-in user, plan, notifications
│   ├── AuthViewModel.swift           Sign in, Google, forgot-password steps
│   ├── HomeViewModel.swift           Live websites, selected site & tab, switch history for Back
│   └── OwnerViewModels.swift         Products, Business info, Monitor
├── Views/
│   ├── RootView.swift                Onboarding → Sign in → Home
│   ├── Auth/                         OnboardingView, SignInView, Google chooser, ForgotPasswordFlow
│   ├── Home/HomeView.swift           Website list, portal tabs, switcher card, toolbar, notifications
│   ├── Owner/                        ProductsViews, BusinessInfoView, MonitorView
│   └── Components/                   Glass dock, buttons, fields, chips, segmented control, prompts, image picker
└── Resources/Assets.xcassets         App icon, logos and sample product photos
```

---

## Connecting the real backend

All data goes through the `WebBlockService` protocol (`Services/WebBlockService.swift`):

```swift
signIn(email:password:) · signInWithGoogle()
requestPasswordReset(email:) · verifyResetCode(email:code:) · resetPassword(email:code:newPassword:)
websites() · notifications() · markAllNotificationsRead()
products(websiteID:) · saveProduct(_:websiteID:) · deleteProduct(id:websiteID:)
businessInfo(websiteID:) · saveBusinessInfo(_:websiteID:)
monitor(websiteID:plan:)
```

Write a type that conforms to it (for example `APIWebBlockService`, backed by Spring Boot + Keycloak) and assign it to
`ServiceLocator.current`.
The views and view models don't need to change.

---

## Not in this app (on purpose)

The website editor, templates, billing, settings, support and sign-up stay on the WebBlock website.
The app focuses on day-to-day changes to sites that are already live.

## Design notes

- Based on the WebBlock Figma: brand blue `#4379D6`, navy text, white rounded cards and pill buttons.
- Uses the system font (SF Pro) instead of the Figma fonts (DM Sans / Familjen Grotesk), so no font files are bundled.
- On iOS 26 it uses system **Liquid Glass**. On iOS 17–18 the same look is drawn by hand.
