const VEHICLES = [
  { id: "motorbike", ar: "موتوسيكل", maxKg: 50 },
  { id: "tricycle", ar: "تروسيكل", maxKg: 300 },
  { id: "van", ar: "فان", maxKg: 700 },
  { id: "quarter_pickup", ar: "ربع نقل", maxKg: 1500 }
];

const pricing = {
  motorbike: {
    base: Number(process.env.DEMO_MOTORBIKE_BASE ?? 15),
    perKm: Number(process.env.DEMO_MOTORBIKE_PER_KM ?? 2)
  },
  tricycle: {
    base: Number(process.env.DEMO_TRICYCLE_BASE ?? 20),
    perKm: Number(process.env.DEMO_TRICYCLE_PER_KM ?? 2.8)
  },
  van: {
    base: Number(process.env.DEMO_VAN_BASE ?? 45),
    perKm: Number(process.env.DEMO_VAN_PER_KM ?? 5.5)
  },
  quarter_pickup: {
    base: Number(process.env.DEMO_QUARTER_PICKUP_BASE ?? 30),
    perKm: Number(process.env.DEMO_QUARTER_PICKUP_PER_KM ?? 3.75)
  }
};

function normalizeArabic(text = "") {
  return text
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[ًٌٍَُِّْـ]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function firstNumber(text, pattern) {
  const match = text.match(pattern);
  return match ? Number(match[1]) : null;
}

function extractRoute(original) {
  const text = original.replace(/\s+/g, " ").trim();
  const patterns = [
    /من\s+(.+?)\s+(?:إلى|الى|لـ|ل)\s*([^،,.]+?)(?=\s+(?:بكره|بكرة|غدا|غداً|الساعة|الساعه|وزن|وزنهم|حوالي|مساف|عدد|ومعايا|ومعي)|[،,.]|$)/i,
    /من\s+(.+?)\s+(?:إلى|الى|لـ)\s*([^،,.]+)/i
  ];

  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) {
      return {
        pickup: match[1].trim(),
        destination: match[2].trim()
      };
    }
  }
  return { pickup: null, destination: null };
}

function extractCargo(original) {
  const normalized = normalizeArabic(original);

  const countMatch = normalized.match(/(\d+)\s*(كرتونه|كرتون|صندوق|طرد|قطعه)/);
  if (countMatch) {
    return {
      description: `${countMatch[1]} ${countMatch[2]}`,
      units: Number(countMatch[1])
    };
  }

  const cargoWords = ["اثاث", "ملابس", "اجهزه", "بضاعه", "معدات", "ادوات", "خضار", "فاكهه"];
  const word = cargoWords.find((w) => normalized.includes(w));
  return { description: word ?? null, units: null };
}

function extractRequestedTime(original) {
  const normalized = normalizeArabic(original);
  const time = normalized.match(/(?:الساعه|ساعه)\s*(\d{1,2})(?::(\d{2}))?/);
  const day = /بكره|غدا/.test(normalized) ? "tomorrow" : null;

  if (!time && !day) return null;
  return {
    day,
    hour: time ? Number(time[1]) : null,
    minute: time?.[2] ? Number(time[2]) : 0
  };
}

function recommendVehicle(weightKg) {
  if (!Number.isFinite(weightKg)) return null;
  return VEHICLES.find((v) => weightKg <= v.maxKg) ?? {
    id: "needs_review",
    ar: "تحتاج مراجعة حمولة",
    maxKg: null
  };
}

function estimateFare(vehicleId, distanceKm) {
  if (!vehicleId || vehicleId === "needs_review" || !Number.isFinite(distanceKm)) return null;
  const rule = pricing[vehicleId];
  if (!rule) return null;
  return Math.round((rule.base + rule.perKm * distanceKm) * 100) / 100;
}

function createSimulatedOffers(estimatedFare) {
  if (!Number.isFinite(estimatedFare)) return [];
  const multipliers = [0.95, 1, 1.08];
  return multipliers.map((m, index) => ({
    id: `demo-offer-${index + 1}`,
    amount: Math.round(estimatedFare * m),
    rating: [4.7, 4.9, 4.6][index],
    simulated: true
  }));
}

export function runTransportAgent(input) {
  const normalized = normalizeArabic(input);
  const route = extractRoute(input);
  const cargo = extractCargo(input);

  const weightKg = firstNumber(normalized, /(\d+(?:\.\d+)?)\s*(?:كيلو|كجم|kg)/i);
  const distanceKm = firstNumber(normalized, /(\d+(?:\.\d+)?)\s*(?:كم|كيلومتر|km)/i);
  const requestedTime = extractRequestedTime(input);
  const vehicle = recommendVehicle(weightKg);
  const estimatedFare = estimateFare(vehicle?.id, distanceKm);

  const missing = [];
  if (!route.pickup) missing.push("pickup");
  if (!route.destination) missing.push("destination");
  if (!cargo.description) missing.push("cargo");
  if (!Number.isFinite(weightKg)) missing.push("weightKg");
  if (!Number.isFinite(distanceKm)) missing.push("distanceKm");

  return {
    status: missing.length ? "needs_information" : "ready_for_matching",
    intent: "local_goods_transport",
    request: {
      pickup: route.pickup,
      destination: route.destination,
      cargo: cargo.description,
      units: cargo.units,
      weightKg,
      distanceKm,
      requestedTime
    },
    recommendation: vehicle
      ? {
          vehicleId: vehicle.id,
          vehicleNameAr: vehicle.ar,
          reason:
            vehicle.id === "needs_review"
              ? "الحمولة أكبر من حدود المركبات الموجودة في النسخة العامة ويجب مراجعتها."
              : `الوزن المعلن يقع داخل الحد الاسترشادي لهذه المركبة (${vehicle.maxKg} كجم).`
        }
      : null,
    pricing: {
      estimatedFare,
      currency: "EGP",
      demoOnly: true
    },
    offers: createSimulatedOffers(estimatedFare),
    missing,
    nextAction: missing.length
      ? `Ask only for: ${missing.join(", ")}`
      : "Create structured request and proceed to driver matching/bidding."
  };
}
