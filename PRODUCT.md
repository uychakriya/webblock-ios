# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Small shop owners (cafés, florists, bakeries, studios; WebBlock's market is Cambodia) who already built a website on the WebBlock web builder. They use this iPhone app on the go, one-handed, in a few minutes between serving customers: check the site is up, change a product or price, update opening hours, read a notification.

## Product Purpose
The owner companion to the WebBlock website builder. It lets an owner manage their **live** websites from the phone: products (add, edit, delete, photos), business information (about, contact, location, opening hours) and site health (status, uptime, deploys, plan usage, activity). Success: an owner finishes a routine change in under a minute and trusts that the site reflects it.

## Positioning
Not a website builder on the phone: accounts and sites are created on the web; the app is the fast, calm control room for sites that are already live.

## Operating Context
- Sign in with the WebBlock account (email + password, or Google through WebBlock's Keycloak). No sign-up in the app.
- Real backend: WebBlock v2 API (same endpoints as the Android app); sample data only behind `ServiceLocator.useMockData`.
- Only LIVE websites have a portal; an owner may have one or several.
- Changes reach the public website after the next deploy.

## Capabilities and Constraints
- iPhone only, portrait, iOS 17+ (SwiftUI, no third-party packages).
- Screens: welcome intro (first launch), sign in, forgot password (email → code → new password), websites list, portal with three tabs (Products, Business info, Monitoring), product detail and form, notifications, account menu.
- Photo uploads: JPG/PNG, 2 MB max (re-encoded on device).

## Brand Commitments
- Name **WebBlocks** with its block-cluster logo mark and two-colour wordmark.
- Brand blue (#4379D6 light / #6E9BEA dark) as the action colour.
- The floating bottom dock with Products / Business info / Monitoring.
- The cinematic 3D welcome intro (first launch only).
- Owner's direction (17 Nov 2026): premium, modern, production quality; minimal but not boring; subtle depth and polished micro-interactions; cinematic 3D reserved for the welcome screen. Avoid heavy glassmorphism, generic templates, crowded screens and childish visuals.

## Evidence on Hand
- Live test account data (E2E Final Coffee, Lyhov). Bundled sample product images and logos in Assets.xcassets are for the mock data only.
- No real customer testimonials, metrics or pricing in the app; do not invent any.

## Product Principles
1. Every routine change takes one obvious path and finishes in under a minute.
2. Show the site's state first (live, healthy, what changed) before asking for work.
3. Calm over clever: one action per screen leads, the rest recedes.
4. The phone is used one-handed in a busy shop: big targets, short copy, forgiving forms.

## Accessibility & Inclusion
Dynamic Type, VoiceOver labels, Reduce Motion, 44 pt targets, Light and Dark Mode.
