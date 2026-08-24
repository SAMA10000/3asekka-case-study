# 3ASEKKA — Platform Ecosystem & Technology Stack

> **VIEW-ONLY PORTFOLIO / CASE STUDY — NOT OPEN SOURCE**  
> Production source code, credentials, signing material and private backend secrets are intentionally excluded.

## A complete transport technology ecosystem

3ASEKKA (عالسكة) is not only a mobile screen set. It was built as a broader **on-demand goods transportation ecosystem** with multiple user and operational surfaces:

### 1. Mobile application — Customer + Driver experiences

One React Native / Expo application provides separate operational experiences for:

- **Customers** — create immediate or scheduled transport requests, choose vehicle type, select pickup/drop-off points, receive route-based pricing, compare driver bids, track trips, communicate, manage payments/invoices and support.
- **Drivers** — onboarding, camera-based document verification, vehicle management, eligible job discovery, bidding, trip execution, earnings, ratings, commission/service-fee obligations, withdrawals and support.

The production Android package is `com.asekka.app`.

### 2. Public website

The platform includes a public web presence at:

`https://3asekka.com`

The website is deployed behind HTTPS/Nginx and includes product/public-facing pages such as privacy and account-deletion information.

### 3. Customer / Driver web portal

The web deployment also includes a dedicated portal surface:

`https://3asekka.com/portal`

This extends the 3ASEKKA product ecosystem beyond the native mobile interface.

### 4. Admin / Owner Dashboard

The platform includes an administrative operations surface at:

`https://3asekka.com/admin`

Admin/owner workflows cover areas such as:

- Driver verification and document review
- AI/OCR verification evidence
- Approve / reject / retake decisions
- Pricing controls
- Commission configuration
- Orders and bidding controls
- Driver debt/service-fee controls
- Payment-receipt review
- Cancellation operations
- Disputes and support tickets
- Notifications
- Driver performance / gamification
- Communication controls
- Operational audit information

### 5. Backend + database + realtime services

The operational backend uses Supabase services including PostgreSQL, Auth, Row Level Security, Realtime, Storage, RPCs and Edge Functions.

---

# Programming languages and core framework stack

## Client / Mobile / Cross-platform

| Technology | Role in 3ASEKKA |
|---|---|
| **TypeScript** | Main typed application language |
| **React 19.1** | Component/UI foundation |
| **React Native 0.81.5** | Native mobile application framework |
| **Expo SDK 54** | Cross-platform application runtime/tooling |
| **React Native Web** | Web-capable React Native layer |
| **React DOM** | React web runtime dependency |
| **React Navigation** | Application navigation and stacks |
| **AsyncStorage** | Local client persistence |
| **React Native Reanimated** | Native UI animation/runtime support |
| **React Native Gesture Handler** | Native gesture handling |
| **React Native SVG** | Vector UI rendering |
| **Lucide React Native** | Icon system |

The production application is therefore correctly described as a **React / React Native / Expo / TypeScript product** — not Flutter, PHP or Laravel.

---

# Backend and data layer

| Technology | Usage |
|---|---|
| **Supabase** | Backend platform |
| **PostgreSQL** | Relational production database |
| **Supabase Auth** | Authentication / session infrastructure |
| **Row Level Security (RLS)** | Database authorization layer |
| **Supabase Realtime** | Live bids, state changes and realtime product flows |
| **Supabase Storage** | Controlled file/document storage |
| **RPC / PostgreSQL functions** | Server-enforced business operations |
| **Supabase Edge Functions** | Server-side APIs and secure integrations |
| **TypeScript / Deno-style Edge runtime** | Server-side Edge Function implementation model |

Business-critical calculations and rules are not intentionally trusted only to UI state; server/backend controls are used for pricing, bidding, verification, financial and operational workflows.

---

# Maps, routing and location technology

- **Google Maps**
- **Google Routes**
- **React Native Maps**
- **React Native Maps Directions**
- **Expo Location**
- Reverse geocoding
- Pickup/drop-off coordinates
- Route-distance and duration data
- Live driver location updates
- Route-based pricing inputs

---

# AI, OCR and Computer Vision

The document-verification layer uses **Google Cloud Vision** through a secured server-side Supabase Edge Function.

The driver onboarding flow is **camera-first**: required identity/vehicle captures are taken from the application camera rather than described as generic file uploads.

AI / machine-assisted capabilities include:

- Document OCR
- Arabic / English text extraction
- Egyptian National ID parsing/validation
- Face Detection
- Vehicle Label Detection
- Object Localization
- Vehicle / plate text attempts
- Document-type validation
- Wrong-document detection
- Expiry validation when dates are readable
- OCR confidence handling
- Duplicate-capture fingerprint protection
- National ID ↔ driving licence consistency checks
- Vehicle registration ↔ vehicle/plate consistency checks
- `PASS / REVIEW / REJECT` machine states
- Human admin final approval

This is accurately presented as **AI-assisted identity and document verification**, not as guaranteed forensic forgery detection.

---

# Authentication and account technology

- **Supabase Auth**
- **React Native Firebase App/Auth**
- Phone / OTP flows
- WhatsApp OTP workflow
- Email authentication / verification
- Google Sign-In / OAuth flow
- Expo Auth Session
- Expo Web Browser
- App PIN / local access protection

---

# Notifications and realtime communication

- **Firebase Cloud Messaging (FCM)** notification infrastructure
- **Expo Notifications**
- Supabase Realtime
- In-app notifications
- Real-time customer/driver chat
- Voice notes
- **Agora RTC / React Native Agora 4.6.2**
- **React Native CallKeep**
- Calling-flow architecture

---

# Camera, media and device capabilities

- **Expo Image Picker** — application camera capture in driver verification flow
- Expo Location
- Expo Notifications
- Expo Font
- Expo Linear Gradient
- Expo Blur
- Expo Web Browser
- Expo Status Bar
- Expo Updates infrastructure
- Native Android integration through Gradle

---

# Android production toolchain

The production source/build history includes:

- Android Gradle build system
- Android SDK / Build Tools
- Kotlin/Android native build integration
- Signed Release APK/AAB workflow
- Android App Bundle for Google Play
- Production signing keystore
- EAS / Expo build tooling in earlier build workflows

Production identity documented for the current product:

- Package: `com.asekka.app`
- Version: `1.1.0`
- Version code: `20260815`

---

# Web deployment / infrastructure

The public website/portal/admin deployment is served through infrastructure including:

- **Nginx**
- **HTTPS / TLS**
- Let's Encrypt certificate automation
- Linux/VPS deployment
- Static/web release directories
- `/portal` customer/driver web surface
- `/admin` administrative surface
- Public privacy and account-deletion routes

The mobile codebase itself also contains React Native Web / React DOM support. The case study does not falsely claim that every web surface must use the exact same frontend bundle as the native application.

---

# Development and quality tooling

- **Node.js / npm** ecosystem
- TypeScript compiler (`tsc --noEmit`)
- Expo CLI
- EAS tooling
- Gradle
- Source-level automated tests
- RTL contract validation
- Text-encoding validation
- Android release build verification
- SHA-256 artifact verification in delivery/recovery workflows

---

# Product architecture summary

**User-facing product:** Website + Customer/Driver Portal + Customer/Driver Mobile Application  
**Operations:** Admin / Owner Dashboard  
**Frontend technologies:** React + React Native + Expo + TypeScript + React Native Web  
**Backend:** Supabase + PostgreSQL + Auth + RLS + Realtime + Storage + RPCs + Edge Functions  
**Maps:** Google Maps + Google Routes + React Native Maps + Expo Location  
**AI / OCR:** Google Cloud Vision  
**Notifications:** Firebase / FCM + Expo Notifications  
**Communication:** Realtime Chat + Voice Notes + Agora + CallKeep  
**Deployment:** Android / Google Play + Linux VPS + Nginx + HTTPS

This combination demonstrates delivery of a **complete operational transport platform**, not only mobile UI development.

---

## Search keywords

#React #ReactJS #ReactNative #Expo #TypeScript #ReactNativeWeb #Supabase #PostgreSQL #Realtime #EdgeFunctions #GoogleMaps #GoogleRoutes #GoogleCloudVision #OCR #ComputerVision #Firebase #FCM #Agora #AndroidDevelopment #MobileAppDevelopment #WebDevelopment #AdminDashboard #CustomerPortal #DriverApp #TransportApp #LogisticsSoftware #UberLike #CareemLike #InDriveLike #BiddingSystem #LiveTracking #KYC #DriverVerification

---

**PROPRIETARY — ALL RIGHTS RESERVED.** No open-source licence is granted. This document describes the architecture and capabilities for portfolio evaluation; it does not publish the production source code or credentials.
