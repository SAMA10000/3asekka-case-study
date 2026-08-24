# 3ASEKKA (عالسكة)
## Production Logistics Marketplace + AI-Assisted Driver & Document Verification

**3ASEKKA** is a production transportation and logistics platform built for the Egyptian market. It connects customers with drivers through a complete marketplace flow: shipment creation, driver bidding, maps, trip tracking, chat/calls, payments, operational controls, and a multi-layer driver onboarding system powered by OCR and computer vision.

> This repository is a **public case study only**. Production source code, credentials, private APIs, signing keys, and customer data are intentionally not published here.

---

## Why this project matters

3ASEKKA demonstrates the ability to design and ship more than a simple mobile UI. The product combines:

- A two-sided marketplace (customers + drivers)
- Real operational workflows and admin controls
- Maps, location, scheduling and trip lifecycle
- Bidding and driver selection
- In-app messaging and calling flows
- Wallet / payment / commission workflows
- Push notifications and support flows
- Driver, vehicle and document verification
- OCR + computer vision + cross-document checks
- Human-in-the-loop approval for sensitive decisions

This architecture is directly relevant to logistics, field services, delivery, mobility, marketplace, KYC/onboarding and operations-heavy products.

---

## Production proof

- **Android package:** `com.asekka.app`
- **Production version:** `1.1.0`
- **Android versionCode:** `20260815`
- **Mobile:** React Native + Expo
- **Backend / Database:** Supabase (Postgres + Edge Functions)
- **OCR / Computer Vision:** Google Cloud Vision
- **Notifications:** Firebase / FCM

The app has a real Google Play production release under the same package identity.

---

# 1. Customer Marketplace Flow

Customers can:

- Create a transportation request
- Select vehicle type
- Choose pickup and drop-off locations on the map
- Schedule a request
- Receive and compare driver bids
- Select the preferred offer
- Track the order / trip lifecycle
- Chat and use in-app call flows
- Manage cancellations, invoices, disputes and support
- Use saved addresses, promo codes, wallet-related flows and notifications

The focus is not only on screens, but on the state transitions and operational rules behind the marketplace.

---

# 2. Driver Workflow

Drivers can:

- Register and complete onboarding
- Submit identity and vehicle documents
- Add and manage vehicles
- Receive eligible shipment requests
- Submit bids
- Manage active and completed trips
- Track earnings, performance and ratings
- Handle withdrawal and service-fee / commission workflows
- Receive notifications and communicate with customers/support

---

# 3. AI-Assisted OCR & Document Verification

A major part of the project is the driver verification workflow.

## Supported captures

- Profile photo
- National ID — front
- National ID — back
- Driving license
- Vehicle registration
- Vehicle photo

## Server-side AI pipeline

1. The mobile app captures the image.
2. The authenticated request is sent to a Supabase Edge Function.
3. The server calls **Google Cloud Vision** using a server-side key.
4. OCR / face / label / object results are processed.
5. Business validation rules produce a result such as `PASS`, `REVIEW` or `REJECT`.
6. The result, confidence, reason and trace information are stored for admin review.
7. **The admin keeps the final approval/rejection authority.**

The Google Vision key is never shipped inside the mobile app or exposed in this public case study.

---

## AI / Computer Vision features used

### OCR
- Arabic / English document text extraction
- National ID and license field extraction
- Expiry-date detection when readable
- Vehicle information extraction when available

### Face Detection
Used to help validate profile-photo and identity-card captures, including cases such as:

- No detected face
- Multiple faces
- Low-confidence capture
- A document uploaded in place of a profile photo

### Vehicle Detection
Label Detection + Object Localization are used to help confirm that a vehicle capture contains a vehicle and to support vehicle-photo validation.

### Confidence & Quality Gates
Low-confidence or insufficient OCR is not silently accepted. The workflow can move the capture to review or request a new photo.

---

# 4. Cross-Document Consistency Checks

The system goes beyond OCR extraction and compares information across captures.

Examples include:

- **National ID ↔ Driving License:** identity consistency when the national ID number can be extracted from both.
- **Vehicle Registration ↔ Vehicle Photo:** plate-number consistency when the plate can be read from the vehicle image.
- **Document Type Validation:** helps prevent a vehicle registration from being submitted as a driving license, or vice versa.
- **Duplicate Capture Protection:** image fingerprints help prevent the exact same image from being reused across different required capture slots in the same onboarding flow.
- **Expiry Checks:** expired documents can be rejected when a valid expiry date is detected.

### Important vehicle business rule

The vehicle registration **does not have to be in the driver's name**. A driver may legally operate a family-owned or otherwise permitted vehicle.

The verification goal is therefore:

- The driver's **National ID and Driving License** should represent the same driver.
- The **Vehicle Registration** should match the actual vehicle through plate/details.
- The system should not falsely reject a valid vehicle simply because the registered owner is another person.

This distinction is important in real-world logistics onboarding and prevents an overly rigid KYC rule from breaking legitimate operations.

---

# 5. Human-in-the-Loop Admin Review

AI is used as a decision-support layer, not as the final authority.

The admin workflow can surface:

- Uploaded captures
- OCR result
- Confidence score
- Automated decision reason
- Vision features used
- Trace / audit information

The admin can then:

- Approve
- Reject
- Request a specific document/photo to be captured again

This combines automation speed with operational control for high-impact account approvals.

---

# 6. Admin & Operations

The platform includes administrative workflows for areas such as:

- Driver verification
- Document review
- Support tickets
- Disputes
- Payment / receipt review
- Pricing controls
- Operational / debt controls
- Notification campaigns
- Activity and communication auditing

---

# 7. Architecture

```text
React Native / Expo Mobile App
        |
        | authenticated requests
        v
Supabase Auth + Postgres + Edge Functions
        |
        +--> Google Cloud Vision (OCR / Face / Labels / Objects)
        |
        +--> Firebase / FCM notifications
        |
        +--> Maps / routing services
        |
        +--> Real-time marketplace and operational data
```

Sensitive AI and service credentials are stored server-side rather than embedded in the mobile client.

---

# 8. Anti-Fraud Positioning — What We Claim and What We Don't

The correct description is:

> **AI-assisted identity and document verification using OCR, face/object detection, cross-document consistency checks, duplicate-capture protection and human admin approval.**

The current system is designed to reduce bad captures, wrong-document submissions, identity mismatches and duplicate-image reuse.

It is **not** marketed as forensic Photoshop detection, “100% fraud-proof,” or a tamper-proof document-forensics engine. That distinction keeps the case study technically credible.

---

# 9. Capabilities Demonstrated

This project demonstrates practical experience in building:

- Logistics & transportation platforms
- Two-sided marketplaces
- Driver / worker onboarding systems
- KYC-like document workflows
- OCR and computer-vision integrations
- Admin dashboards and moderation flows
- Payment / commission workflows
- Maps and location-driven apps
- Real-time communication features
- Secure server-side integrations
- Production mobile release workflows

---

# Looking for a similar product?

If you are building a logistics platform, service marketplace, driver onboarding system, field-operations product, or an app that needs OCR / document verification and admin review, this case study shows the type of end-to-end system we can deliver.

**GitHub profile:** [SAMA10000](https://github.com/SAMA10000)

---

## Confidentiality & Security

This public repository contains documentation only.

It does **not** contain:

- Production source code
- `.env` files
- Supabase service-role keys
- Google Vision keys
- Firebase private credentials
- Android signing keys
- Customer / driver personal data
