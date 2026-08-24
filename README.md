# 3ASEKKA (عالسكة)
## Production On-Demand Goods Transportation Platform — Uber / Careem / inDrive Style for Logistics

**3ASEKKA (عالسكة)** is a production **on-demand transportation and logistics application for moving goods**, built for the Egyptian market.

Its operating model is closer to **Uber, Careem and inDrive** than to an e-commerce marketplace: a customer creates a transport request, chooses the required vehicle, selects pickup and drop-off points, receives a route-based suggested fare, drivers can submit competing offers, the customer chooses a driver, and the trip then moves through a real-time operational lifecycle until delivery is completed.

The project was built as a full operational product — not just a set of mobile screens.

> **Public case study only.** Production source code, private APIs, service credentials, signing keys and user data are intentionally not published here.

---

## Production stack

- **Mobile:** React Native `0.81` + Expo SDK `54` + React `19`
- **Backend / Database / Realtime:** Supabase — PostgreSQL, Auth, Realtime, Storage, RPCs and Edge Functions
- **Maps & route pricing:** Google Maps / Google Routes
- **OCR & Computer Vision:** Google Cloud Vision via a server-side Supabase Edge Function
- **Push notifications:** Firebase Cloud Messaging (FCM)
- **Location:** Expo Location + Google geocoding
- **Voice / communication:** real-time chat, voice notes and configurable calling flows
- **Android production identity:** `com.asekka.app`
- **Production version:** `1.1.0`
- **Android versionCode:** `20260815`

---

# What was built

## 1) Customer transportation flow

The customer can:

- Create an immediate transport request
- Schedule a transport request for a later date/time
- Select pickup and drop-off locations
- Pick locations from interactive maps
- Reuse saved addresses
- Store pickup/drop-off coordinates
- Add cargo description
- Add estimated cargo weight
- Add pickup-floor information
- Choose the required vehicle type
- Receive a server-calculated suggested fare
- Adjust the offer without going below the server-approved minimum
- Apply promo codes
- Submit the request into the bidding flow
- Receive driver offers in real time
- Compare offers and driver information
- Accept or reject individual bids
- Chat with a driver
- Use supported calling flows
- Track the trip lifecycle in real time
- Follow driver-location updates
- Cancel with a server-calculated cancellation policy
- Receive trip receipts / invoices
- Open a dispute
- Contact support
- Repeat a previous completed order with its route/cargo details
- View trip history and customer analytics
- Receive in-app and push notifications

---

## 2) Four transportation vehicle classes

The application currently supports four goods-transport categories:

| Vehicle | Intended capacity shown in the app |
|---|---:|
| **Quarter pickup / ربع نقل** | up to ~1.5 ton |
| **Van / فان** | up to ~700 kg |
| **Tricycle / تروسيكل** | up to ~300 kg |
| **Motorbike / موتوسيكل** | up to ~50 kg |

Vehicle type is not only visual UI. It is used in the order flow, driver eligibility and pricing configuration.

---

# 3) Smart route-based pricing engine

One of the strongest parts of the system is the pricing architecture.

The mobile app does **not** rely on a hard-coded local fare formula. Pricing is calculated by an authenticated server-side Edge Function.

The fare engine uses:

- Real pickup coordinates
- Real drop-off coordinates
- **Google Routes traffic-aware road distance**
- Estimated route duration
- Toll information when available
- Vehicle-specific pricing profiles
- Admin-configured market pricing points
- Minimum driver fare
- Configurable platform commission
- Configurable return factor
- Configurable rounding step

The backend calculates a **suggested customer fare and minimum allowed offer**.

This creates an inDrive-like commercial model: the customer sees a realistic starting price and can raise the offer, while the backend prevents offers below the configured minimum.

The bidding increment can also be configured by the admin.

---

# 4) Real-time driver bidding

Drivers can receive eligible open transport requests and submit offers.

The bidding system includes:

- Supabase Realtime bid subscriptions
- Driver offer amount
- Driver name
- Rating
- Completed-trip count
- Vehicle information
- Plate information when available
- Customer accept action
- Customer reject action
- Closed / expired order protection
- Backend RPC validation for accepting and rejecting bids
- Configurable operational switch to stop bidding globally
- Driver-level bidding restrictions when required by operations/debt rules

This is a real transport-negotiation workflow, not a static quote screen.

---

# 5) Scheduling / booking system

Customers can create scheduled transport requests with:

- Date selection
- Time selection
- Cairo-time handling
- Future-slot validation
- Pickup and destination information
- Vehicle selection
- Cargo information

Scheduled jobs remain part of the normal order lifecycle and can later transition into active tracking.

---

# 6) Full trip lifecycle

The project contains an operational state machine rather than a simple `pending/completed` flag.

Supported lifecycle states include flows such as:

`pending → bidding → active → driver_en_route → arrived_pickup → picked_up → arrived_dropoff → delivered → completed`

with additional terminal states such as:

- `cancelled`
- `expired`

The backend also stores **order status events**, enabling a real activity timeline and audit trail.

Stale requests can be expired automatically through backend lifecycle rules.

---

# 7) Real-time maps & live trip tracking

The tracking module includes:

- Google Maps / React Native Maps
- Pickup marker
- Drop-off marker
- Driver-location updates
- Latest-known driver location
- Supabase Realtime subscriptions
- Route / distance presentation
- Trip status timeline
- ETA-oriented UI states
- Driver-en-route state
- Pickup-arrival state
- Shipment-in-transit state
- Drop-off-arrival state
- Delivery completion state

Location services also include Arabic reverse geocoding and Egypt geographic bounds validation.

---

# 8) AI-assisted driver & document verification

Driver onboarding uses a multi-step verification system powered by **Google Cloud Vision** through a secured server-side Edge Function.

### Required capture types

1. Profile photo
2. Egyptian National ID — front
3. Egyptian National ID — back
4. Driving license
5. Vehicle registration
6. Vehicle photo / plate

The AI credential is kept server-side and is never bundled into the mobile app.

---

## OCR and document intelligence

The system can use OCR results to extract or validate fields such as:

- Egyptian national ID number
- Document type
- Expiry date
- License-related data
- Vehicle plate
- Vehicle brand
- Vehicle model
- Vehicle color
- Chassis number
- Motor number
- Vehicle type when readable

It also records OCR confidence and machine-verification metadata for admin review.

---

## Computer Vision used in onboarding

### Face Detection
Used for profile-photo / identity capture validation, including detection of:

- No face
- Multiple faces
- Low-confidence face detection
- A document being submitted instead of a profile photo

### Label Detection + Object Localization
Used in vehicle-photo validation to help verify that the uploaded capture actually contains a vehicle.

### Document Text Detection
Used for structured document OCR on identity and license documents.

---

# 9) Cross-document anti-manipulation checks

The verification workflow goes beyond reading text.

It performs consistency checks such as:

### National ID ↔ Driving License
When the national ID number is readable from both documents, they must match.

### Vehicle Registration ↔ Vehicle Photo
When the plate is readable from both captures, the plate numbers must match.

### Correct-document checks
The OCR layer detects obvious cases such as submitting a vehicle registration where a driving license is expected, or vice versa.

### Duplicate-image protection
Each capture has an image fingerprint. The same image cannot simply be reused in multiple required document slots.

### Expiry validation
Expired documents can be rejected when the expiry date is successfully extracted.

### Confidence / review states
The workflow supports machine decisions such as:

- `PASS`
- `REVIEW`
- `REJECT`

Low-confidence or ambiguous captures are not silently trusted.

---

## Important real-world vehicle rule

A vehicle registration **is not required to be in the driver's own name**.

A driver can legitimately operate a family-owned or otherwise permitted vehicle.

Therefore the system verifies the correct relationships:

- **National ID ↔ Driving License:** driver identity consistency
- **Vehicle Registration ↔ Vehicle Photo:** vehicle / plate consistency

It does **not** incorrectly force the vehicle owner name to equal the driver's name.

---

# 10) Human-in-the-loop admin approval

AI is an automated verification layer — **not the final authority**.

The admin retains the final approval decision.

The admin review workflow can display:

- Uploaded captures
- OCR text state
- OCR confidence
- Verification decision
- Validation reason
- Vision features used
- Document status
- Driver verification state

The admin can:

- Approve the driver
- Reject the driver
- Request a specific photo/document to be retaken

Sensitive verification state changes are protected at the backend level, not merely by hiding mobile buttons.

---

# 11) Driver availability & operational eligibility

Drivers have an online/offline availability workflow.

The backend can restrict order access based on operational conditions such as:

- Driver verification
- Driver mode enabled
- Vehicle availability
- Vehicle type
- Platform operational controls
- Outstanding service-fee/debt rules

Online presence is refreshed while the driver is active.

---

# 12) Owner monetization / service-fee engine

3ASEKKA includes an actual monetization architecture for the platform owner.

When a trip is completed, the backend can create a **service-fee / commission settlement** containing:

- Gross trip value
- Commission rate
- Platform commission amount
- Driver net amount
- Settlement status
- Settlement code

The commission is configurable from backend pricing settings rather than being permanently hard-coded.

This means the product already contains the core financial logic required for a transport-platform owner to monetize completed trips.

---

# 13) Driver service-fee settlement

The current production workflow supports manual service-fee settlement through:

- **InstaPay**
- **Vodafone Cash**
- Receipt image upload
- Transfer-reference capture
- Admin review
- Paid / pending-review settlement states

The database is also structured to support provider expansion. Paymob is represented as a future/disabled provider rather than being falsely presented as active production payment processing.

---

# 14) Wallet, financial ledger & withdrawals

The system includes:

- Wallet balance
- Transaction ledger
- Earnings records
- Trip earnings
- Service-fee obligations
- Customer financial summary
- Driver withdrawal requests

Driver payout destinations include:

- Vodafone Cash
- InstaPay
- Bank account / IBAN details

---

# 15) Customer invoices & receipts

Completed transport requests can produce customer trip receipts/invoices.

The financial layer also supports:

- Invoice number
- Trip reference
- Subtotal / total
- Paid amount
- Amount due
- Payment method
- Invoice status
- Sharing the receipt
- Customer finance summary

The current trip settlement model can record the transport fare as **cash paid directly to the driver** while still maintaining a structured invoice/ledger in the platform.

---

# 16) Cancellation intelligence & debt handling

Cancellation is not a simple delete button.

Before cancelling, the backend can calculate a cancellation quote based on the current trip state.

The system supports:

- Cancellation reasons
- Movement fees after the driver has started moving
- Separate handling for customer vs driver cancellation
- Cancellation event audit
- Customer cancellation invoices
- Outstanding debt
- Wallet payment of eligible customer debt
- Cancellation-frequency monitoring
- Repeat cancellation risk
- Customer/driver pair cancellation risk
- Configurable warning thresholds
- Admin-configurable cancellation finance rules

---

# 17) Driver debt controls

The platform includes backend-controlled debt operations for drivers:

- Outstanding service-fee calculation
- Debt warning
- Debt block thresholds
- Automatic bid restrictions
- Admin driver-level bidding mode controls
- Manual warning trigger

These controls are enforced through backend logic, not only UI state.

---

# 18) Driver earnings, performance & gamification

Drivers have more than an order list.

The project includes:

- Earnings summary
- Earnings details
- Completed-trip statistics
- Ratings
- Bid history
- Performance screen
- Points system
- Levels
- Driver ranks
- Five-star bonus points
- Cancellation penalties
- Daily challenge target
- Admin-configurable gamification settings

This helps support driver retention and operational incentives.

---

# 19) Ratings & reviews

The project contains a ratings system with backend aggregation.

It supports driver performance visibility in places such as:

- Bid comparison
- Driver profile
- Driver ratings screen
- Gamification / performance calculations

---

# 20) Real-time chat + voice notes

Customer/driver communication includes:

- Real-time chat
- Message delivery/read handling
- Voice-note recording and sending
- Participant rules tied to the order
- Communication policy acceptance
- Safety warnings before communication
- Backend communication moderation/audit events

Phone visibility is also handled carefully around the pre-acceptance bidding stage.

---

# 21) Calling architecture

The codebase includes calling infrastructure and call-session screens, with backend operational controls that can enable/disable supported calling flows.

The project also contains native call-related libraries and internal support-call flows.

Calling is treated as an operationally controlled feature rather than an always-on hard-coded button.

---

# 22) Remote safety content + audio support

Safety rules and communication warnings are remotely configurable from the backend.

The configuration supports:

- Enable / disable
- Remote text
- Versioning
- Checkbox / button labels
- Audio enable / disable
- Audio URL
- Transcript metadata
- Voice metadata

The mobile app can present the configured audio to users.

**Accuracy note:** this proves a remote audio/voice delivery system. It does not claim that a specific AI voice generator such as ElevenLabs is embedded in the source code itself; AI-generated audio can be produced externally and published through this configuration.

---

# 23) Notifications

The project contains both realtime in-app notifications and FCM push infrastructure.

Notification scenarios include areas such as:

- New transport requests
- Bid / order updates
- Trip status changes
- Driver verification / retake requests
- Service-fee settlement
- Support messages
- Operational campaigns

The admin dashboard can also send notification campaigns to selected audiences.

---

# 24) Support center

Users can open support tickets and communicate with support.

The admin support center includes:

- Ticket list
- Ticket status
- Conversation history
- Admin replies
- Ticket resolution / closure
- Configurable support contact information
- Realtime support updates

---

# 25) Disputes

The customer flow includes an order-dispute module, and the admin dashboard contains dispute review/resolution functionality.

This is important for a real transportation operation where completion, payment or service disagreements may occur.

---

# 26) Promo codes

The customer order flow includes promo-code validation and stores financial values such as:

- Original price
- Discount amount
- Final price after discount

---

# 27) Saved addresses & repeat transport

Customers can save commonly used addresses and mark a default address.

Completed orders can also be repeated with previous information such as:

- Vehicle type
- Pickup location
- Drop-off location
- Coordinates
- Cargo description
- Estimated weight
- Pickup floor

This reduces friction for repeat business customers.

---

# 28) Customer analytics

The customer side includes analytics such as:

- Completed / cancelled trip history
- Recent trip history
- Total paid for completed transports
- Route and transaction history

---

# 29) Filters

The app contains filter workflows for customer and driver views, including combinations of:

- Vehicle type
- Price range
- Scheduled jobs
- Order status
- Time period
- Sorting by time / price

---

# 30) Authentication & account security

The authentication system includes multiple real flows:

- Email registration/login
- Phone registration/login
- WhatsApp OTP flow
- Google sign-in flow
- Email verification
- Forgot-password flow
- Customer / driver account experiences
- Controlled account-mode switching
- App PIN setup / PIN unlock
- Profile editing
- Password change
- Account deletion
- Privacy policy
- Terms and safety acceptance

Sensitive role/verification/wallet changes are protected through backend rules.

---

# 31) Admin operations dashboard

The admin dashboard is a major part of the system and includes operational control over areas such as:

- Orders
- Bids
- Driver documents
- Driver verification
- Retake requests
- Withdrawals
- Service-fee settlements
- Commission payment receipts
- Customer invoices
- Cancellation finance
- Cancellation risk
- Disputes
- Support tickets
- Notification campaigns
- Pricing
- Commission
- Bidding configuration
- Driver debt controls
- Driver gamification
- Calls on/off
- Customer orders on/off
- Driver bidding on/off
- Activity audit
- Communication audit

Several of these switches are enforced server-side through Supabase RPCs / database policies rather than only being cosmetic dashboard toggles.

---

# 32) Backend security & architecture

The project demonstrates production-oriented backend design including:

- Supabase Row Level Security
- Authenticated RPCs
- Admin-only RPCs
- Server-side secrets
- Edge Functions
- Storage policies
- Audit trails
- Realtime subscriptions
- Sensitive-field update guards
- Production notification dispatch
- Server-enforced pricing rules
- Server-enforced bidding rules
- Server-enforced operational switches

---

# High-level architecture

```text
React Native + Expo App
        |
        | Authenticated API / Realtime
        v
Supabase
  ├─ Auth
  ├─ PostgreSQL
  ├─ Realtime
  ├─ Storage
  ├─ RPC / security rules
  └─ Edge Functions
        |
        ├─ Google Cloud Vision (OCR / Face / Labels / Objects)
        ├─ Google Routes / Maps
        ├─ Firebase Cloud Messaging
        └─ WhatsApp OTP integration
```

---

# Why this case study is valuable to a client

This project shows the ability to build a **revenue-ready operational transport platform**, including three separate product layers:

### Customer product
Request transport, negotiate price, schedule, track, communicate, receive receipts and manage problems.

### Driver product
Onboarding, AI-assisted verification, vehicle management, job feed, bidding, trip execution, earnings and payouts.

### Owner / operations product
Commission monetization, pricing, driver approval, financial review, debt enforcement, support, disputes, notifications and operational switches.

A client looking to build an **Uber/Careem/inDrive-style transportation product, delivery platform, freight app, field-service dispatch system or driver onboarding system** can reuse the engineering patterns demonstrated here.

---

## AI positioning

The technically correct positioning is:

> **AI-assisted driver and document verification using OCR, face detection, object/label detection, cross-document consistency checks, duplicate-image protection, confidence scoring and final human admin approval.**

We do **not** falsely describe the current system as forensic Photoshop detection or “100% fraud-proof.”

---

# Interested in building a similar platform?

This case study represents experience across **React Native, Supabase, realtime systems, maps, logistics workflows, pricing engines, AI/OCR onboarding, financial operations and admin systems**.

**GitHub:** [SAMA10000](https://github.com/SAMA10000)

---

## Confidentiality

This public repository intentionally excludes:

- Production source code
- `.env` files
- Supabase service-role credentials
- Google Cloud Vision secrets
- Firebase private credentials
- Android signing keys
- User identity documents
- Customer / driver personal data
