# 3ASEKKA — عالسكة
## Production On-Demand Goods Transportation Platform
### Uber / Careem / inDrive-style operating model for logistics and goods transport

> **VIEW-ONLY PORTFOLIO / CASE STUDY — NOT OPEN SOURCE**
>
> This public repository contains **documentation and reduced presentation visuals only**. It does **not** contain the production application source code, private backend code, credentials, API secrets, signing keys, database secrets, or private user data.
>
> **NO OPEN-SOURCE LICENSE IS GRANTED. ALL RIGHTS RESERVED.** See [`LICENSE`](LICENSE).

**3ASEKKA (عالسكة)** is a production **on-demand goods transportation application** built for the Egyptian market. Its operating model is closer to **Uber, Careem and inDrive** than to an e-commerce marketplace: a customer creates a transport request, selects the required vehicle, chooses pickup and drop-off points, receives a route-based suggested price, drivers can submit competing offers, the customer selects a driver, and the trip proceeds through a real-time operational lifecycle until delivery is completed.

The project is a full operational product — **customer flow + driver flow + owner/admin operations + monetization + AI-assisted verification + real-time infrastructure**.

---

## Visual proof

![3ASEKKA production UI — vehicle selection, order details, bidding, live tracking and customer home](showcase/3asekka_core_flow.jpg)

The image above is a reduced public gallery created from **actual screenshots preserved in the production source archive**. High-resolution originals are kept private.

### OCR / AI verification architecture

![3ASEKKA OCR anti-manipulation flow](3asekka_ocr_antifraud_flow_colored.png)

➡️ **More visuals and technical explanation:** [`SHOWCASE.md`](SHOWCASE.md)

---

# Production identity

- **Android package:** `com.asekka.app`
- **Production version:** `1.1.0`
- **Android versionCode:** `20260815`
- **Mobile:** React Native `0.81` + Expo SDK `54` + React `19`
- **Backend / Database / Realtime:** Supabase — PostgreSQL, Auth, Realtime, Storage, RPCs and Edge Functions
- **Maps / routing / route pricing:** Google Maps + Google Routes
- **OCR / Computer Vision:** Google Cloud Vision through a server-side Supabase Edge Function
- **Push notifications:** Firebase Cloud Messaging (FCM)
- **Location:** Expo Location + Google geocoding

A production Android release exists under the same package identity.

---

# What was built

## 1. Customer transport flow

The customer side supports a complete goods-transport journey:

- Create an immediate transport request
- Schedule a transport request for a future date/time
- Select pickup and destination on interactive maps
- Store pickup/drop-off coordinates
- Reuse saved addresses
- Add cargo description and estimated weight
- Add pickup-floor information
- Choose the required vehicle class
- Receive a server-calculated suggested fare
- Adjust the offer while respecting the backend minimum
- Apply promo codes
- Submit the request into the bidding flow
- Receive driver offers in real time
- Compare price, driver rating, completed trips and vehicle information
- Accept or reject bids
- Chat with the selected driver
- Use supported calling / communication flows
- Track the trip lifecycle in real time
- Follow driver-location updates
- Cancel through backend cancellation rules
- Receive trip receipts / invoices
- Open disputes and support tickets
- Repeat a previous completed order
- View history, analytics and notifications

---

## 2. Four goods-transport vehicle classes

The application supports four operational vehicle categories:

| Vehicle class | Intended capacity shown in the product |
|---|---:|
| Quarter pickup / ربع نقل | up to ~1.5 ton |
| Van / فان | up to ~700 kg |
| Tricycle / تروسيكل | up to ~300 kg |
| Motorbike / موتوسيكل | up to ~50 kg |

Vehicle type is part of the **order rules, driver eligibility and pricing configuration**, not just a UI choice.

---

## 3. Smart route-based pricing engine

Pricing is calculated server-side rather than relying on a simple hard-coded phone formula.

The fare architecture can use:

- Pickup coordinates
- Drop-off coordinates
- Google Routes road distance
- Estimated route duration
- Toll information when available
- Vehicle-specific pricing profiles
- Admin-configured market pricing points
- Minimum driver fare
- Configurable platform commission
- Configurable pricing / return factors
- Configurable rounding rules

The backend returns a **suggested customer fare and minimum allowed offer**, supporting an inDrive-style commercial negotiation model while protecting configured minimum pricing.

---

## 4. Real-time driver bidding

Drivers can receive eligible open transport requests and submit competing offers.

The bidding workflow includes:

- Supabase Realtime subscriptions
- Driver offer amount
- Driver identity / profile information
- Rating
- Completed-trip count
- Vehicle information
- Customer accept / reject actions
- Expired / closed-order protection
- Backend validation for accepting bids
- Global operational bidding controls
- Driver-level restrictions linked to operational / debt rules

---

## 5. Scheduling / booking

Customers can schedule transport for a later date and time with:

- Date selection
- Time selection
- Future-slot validation
- Pickup and destination details
- Vehicle selection
- Cargo details

Scheduled requests continue into the normal operational lifecycle when activated.

---

## 6. Full trip lifecycle

The platform uses a real operational state machine rather than a simple pending/completed flag.

Example lifecycle:

`pending → bidding → active → driver_en_route → arrived_pickup → picked_up → arrived_dropoff → delivered → completed`

with terminal states such as:

- `cancelled`
- `expired`

Order-status events provide an activity timeline / audit trail, and stale requests can be expired through backend lifecycle rules.

---

## 7. Live maps and trip tracking

The tracking system includes:

- Google Maps / React Native Maps
- Pickup marker
- Drop-off marker
- Latest driver location
- Real-time driver-location updates
- Route / distance presentation
- Trip status timeline
- Driver en-route state
- Pickup-arrival state
- Shipment-in-transit state
- Drop-off-arrival state
- Delivery completion state
- Arabic reverse geocoding
- Egypt geographic-bound validation

---

# AI-assisted driver and document verification

Driver onboarding includes a multi-step OCR and computer-vision workflow powered by **Google Cloud Vision** from a secured server-side Edge Function.

## Captures used in the onboarding workflow

- Profile photo
- Egyptian National ID — front
- Egyptian National ID — back
- Driving license
- Vehicle registration
- Vehicle photo / plate

The Google Vision credential remains server-side and is not bundled into the public mobile presentation.

## OCR / document intelligence

The system can extract or validate data such as:

- Egyptian national ID number
- Document type
- Expiry date
- License-related fields
- Vehicle plate
- Vehicle brand / model / color when readable
- Chassis / motor information when readable
- OCR confidence and machine-verification metadata

## Computer Vision

### Face Detection
Used to help identify cases such as:

- No detected face
- Multiple faces
- Low-confidence face capture
- A document submitted where a profile photo is expected

### Label Detection + Object Localization
Used to help validate that a vehicle capture actually contains a vehicle.

### Document Text Detection
Used for structured OCR across identity and license documents.

---

## Cross-document consistency / anti-manipulation checks

The verification system goes beyond text extraction.

Examples include:

- **National ID ↔ Driving License:** identity consistency when the national ID number is readable in both
- **Vehicle Registration ↔ Vehicle Photo:** plate / vehicle consistency when readable
- **Correct-document checks:** helps detect a vehicle registration uploaded as a driving license or vice versa
- **Duplicate-image fingerprint protection:** the exact same image cannot simply be reused across multiple required capture slots
- **Expiry checks:** expired documents can be rejected when the expiry date is successfully extracted
- **Confidence handling:** machine states such as `PASS`, `REVIEW` and `REJECT`

### Real-world vehicle ownership rule

The vehicle registration is **not required to be in the driver's own name**. The driver may legitimately operate a family-owned or otherwise permitted vehicle.

The correct relationships are therefore:

- National ID ↔ Driving License = **same driver**
- Vehicle Registration ↔ Vehicle / plate = **same vehicle**

This avoids a rigid rule that would incorrectly reject legitimate drivers.

### Human-in-the-loop approval

AI is a verification layer, **not the final authority**.

The admin retains the final ability to:

- Approve
- Reject
- Request a specific capture again

This combines automation with human operational control for sensitive onboarding decisions.

> The system is correctly described as **AI-assisted identity and document verification**. It is not marketed as forensic Photoshop detection or “100% fraud-proof”.

---

# Driver operations

The driver side includes workflows for:

- Registration and onboarding
- Identity / vehicle document submission
- Vehicle management
- Online / offline availability
- Eligible request discovery
- Bid submission
- Active-trip lifecycle
- Completed-trip history
- Earnings
- Rating / performance information
- Service-fee / commission obligations
- Withdrawal requests
- Notifications
- Support and communication

Backend eligibility can consider verification state, vehicle type, availability, global platform controls and service-fee / debt rules.

---

# Owner monetization / commission engine

The product contains financial logic for the platform owner.

When a trip is completed, the backend can create a service-fee / commission settlement containing:

- Gross trip value
- Commission rate
- Platform commission amount
- Driver net amount
- Settlement status
- Settlement reference / code

Commission is configurable through backend settings rather than permanently hard-coded.

This gives the owner an operational monetization mechanism tied to completed transport activity.

---

# Payments, wallet and financial operations

The project contains structured financial workflows, including:

- Driver service-fee settlement
- InstaPay workflow
- Vodafone Cash workflow
- Receipt-image upload
- Transfer-reference capture
- Admin payment / receipt review
- Wallet balance
- Transaction ledger
- Trip earnings
- Service-fee obligations
- Driver withdrawal requests
- Vodafone Cash payout destination
- InstaPay payout destination
- Bank / IBAN payout details
- Customer invoices / receipts
- Paid / due amounts
- Finance summaries

The current product should **not** be misrepresented as having every payment gateway live. The database / architecture is provider-extensible, while the active workflows are presented truthfully.

---

# Cancellation and debt controls

Cancellation is handled as an operational / financial process, not just a delete button.

The backend can support:

- Cancellation reasons
- Stage-based movement fees
- Separate customer / driver cancellation handling
- Cancellation audit events
- Cancellation invoices / debt
- Wallet payment of eligible debt
- Cancellation-frequency monitoring
- Repeated-cancellation risk indicators
- Configurable warning thresholds

Driver operations can also include:

- Outstanding service-fee calculation
- Debt warning
- Bid restrictions
- Admin-controlled bidding modes

---

# Driver performance and retention

Driver-facing systems include:

- Earnings summary
- Earnings details
- Completed-trip statistics
- Ratings
- Bid history
- Performance screens
- Points
- Levels / ranks
- Five-star bonus points
- Cancellation penalties
- Daily challenge targets
- Admin-configurable gamification settings

---

# Communication and notifications

The project contains:

- Real-time customer / driver chat
- Message delivery / read handling
- Voice-note recording and sending
- Calling-flow architecture
- Communication policy / safety messaging
- Backend communication audit / moderation hooks
- In-app notifications
- Firebase Cloud Messaging push notifications

The product also has an audio-content architecture that can deliver configurable safety / terms audio. AI-generated voice assets can be produced externally and supplied through this content layer; the repository does not falsely claim that an ElevenLabs-style generator is embedded in the mobile source itself.

---

# Admin / owner operations

The administrative system includes controls and workflows around areas such as:

- Driver verification
- Document review
- Final approve / reject decisions
- Order controls
- Bidding controls
- Pricing configuration
- Commission configuration
- Driver debt / service-fee controls
- Payment and receipt review
- Cancellation operations
- Disputes
- Support tickets
- Notification campaigns
- Driver performance / gamification settings
- Communication / calling controls
- Activity / audit information

Sensitive decisions are intended to be enforced through backend permissions and workflows, not only hidden UI buttons.

---

# Authentication and platform infrastructure

The wider application architecture includes flows for areas such as:

- Phone authentication
- WhatsApp OTP flows
- Email authentication / verification
- Google Sign-In integration
- Password recovery
- App PIN / local access protection
- Customer / driver mode handling
- Supabase Auth
- PostgreSQL database
- Row Level Security policies
- RPCs
- Realtime subscriptions
- Storage policies
- Edge Functions
- Firebase / FCM notifications
- Google Maps / Routes integrations

---

# Why this case study is valuable to clients

3ASEKKA demonstrates experience delivering an **end-to-end transport product**, not only designing screens.

Relevant project types include:

- Uber-like transport applications
- Careem-like service applications
- inDrive-style bidding applications
- Goods / cargo transport systems
- Last-mile / logistics applications
- Driver / courier applications
- Fleet / field-operations systems
- KYC and driver-onboarding systems
- OCR / document-verification applications
- Real-time maps and tracking systems
- Commission-based transport businesses
- Operations-heavy mobile products

---

# Search tags / project keywords

#ReactNative #Expo #Supabase #PostgreSQL #GoogleCloudVision #OCR #ComputerVision #KYC #DocumentVerification #DriverVerification #LogisticsApp #TransportApp #GoodsTransport #OnDemandTransport #UberLike #CareemLike #InDriveLike #DriverApp #CourierApp #GoogleMaps #GoogleRoutes #Realtime #Firebase #FCM #MobileAppDevelopment #BiddingSystem #LiveTracking #DriverOnboarding #CommissionSystem #EgyptTech

---

# Confidentiality, ownership and use restriction

This public repository is deliberately limited to **portfolio documentation and reduced visuals**.

It does **not** include:

- Production source code
- Private backend source
- `.env` files
- Supabase service-role secrets
- Google Vision secrets
- Private Firebase credentials
- Android signing keystores
- Database passwords
- Customer / driver personal data

**PROPRIETARY — ALL RIGHTS RESERVED.**

Viewing for evaluation is permitted. No permission is granted to copy, modify, redistribute, deploy, reproduce, reverse engineer, commercially exploit, or create derivative products from the materials in this repository without prior written authorization from the project owner.

This project is not affiliated with Uber, Careem or inDrive. Those names are used only to describe the general on-demand transport / bidding operating model for comparison.