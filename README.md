# WebBlock – Owner app (iOS)

SwiftUI · Swift 5 · iOS 17+ · MVVM (`@Observable`) · no third-party packages.
Styled after the WebBlock Figma ("Final submit"): blue `#4379D6` titles and pill buttons, navy ink, soft pink→blue sign-in backdrop,
white rounded cards with hairline borders, soft-blue icon tiles, usage donuts and SUCCEEDED / FAILED pills.

## What the app does
1. **Sign in** with the account created on the WebBlock website (no sign-up, no password reset, no profile editing here).
2. After sign-in the user sees **only their live website**, in three bottom tabs:
   **Products** · **Business information** · **Monitor**.
   If the account has several live websites, the site card at the top of each page switches between them.
   If none is live, an empty state explains how to publish one on the web.
3. Top right of every page: **bell** (notifications) and the **profile avatar**. Tapping the avatar opens a popup:
   *"Log out of WebBlock?"* → **Log out** / **Cancel**.

## Run it
Open `WebBlock.xcodeproj`, pick an iPhone simulator (iOS 17+), press ⌘R. See `OPEN_IN_XCODE.md`.

## Try it (sample service)
- Sign in with any email containing `@` and a password of 8+ characters.
- Emails starting with `pro` or `ultra` sign in on that plan (e.g. `pro@test.com`) so you can compare the Monitor limits and the
  Pro/Ultra activity log. Anything else signs in on Plus. (SAMPLE rule, not from Figma.)

## Structure
```
WebBlock/
  Core/Theme.swift                 Figma colors (light + dark), spacing, radii, backdrop, brand mark
  Models/Models.swift              plain value types
  Services/WebBlockService.swift   protocol + ServiceLocator  ← plug the real API in here
  Services/MockWebBlockService     sample data, marked
  ViewModels/                      AppState, Auth, Home, Owner (Products / Business info / Monitor)
  Views/Auth                       SignInView (+ Google chooser sheet)
  Views/Home                       HomeView, tabs, site card, bell + profile popup, notifications
  Views/Owner                      ProductsViews, BusinessInfoView, MonitorView
  Views/Components                 cards, buttons, fields, chips, donuts, toast
```

## Differences from Figma
- **Font:** Figma uses DM Sans / Familjen Grotesk. The app uses the system font (SF Pro) so it needs no font files.
- **Not compiled in the authoring environment** (no Xcode there). If Xcode shows an error, send the first error line.
- **Editor, templates, support, settings, billing** are intentionally not in this app.
- **Product photos / site hero image:** Figma has real photos; the app shows a placeholder until the API provides image URLs.
- **Pagination:** the web "Previous / 1 2 / Next" pager is a "Show more" button on iPhone.
- **Sample values:** notification timestamps and the Google chooser account are SAMPLE.
