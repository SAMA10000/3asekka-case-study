import { extractTransportWithAI } from "./llm.mjs";

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

function toLatinDigits(text = "") {
  const arabic = "٠١٢٣٤٥٦٧٨٩";
  const eastern = "۰۱۲۳۴۵۶۷۸۹";
  return String(text)
    .replace(/[٠-٩]/g, (d) => String(arabic.indexOf(d)))
    .replace(/[۰-۹]/g, (d) => String(eastern.indexOf(d)));
}

function normalizeArabic(text = "") {
  return toLatinDigits(text)
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
  const text = toLatinDigits(original).replace(/\s+/g, " ").trim();
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

  const countMatch = normalized.match(/(\d+)\s*(كرتونه|كرتون|صندوق|طرد|قطعه|شوال|جوال)/);
  if (countMatch) {
    return {
      description: `${countMatch[1]} ${countMatch[2]}`,
      units: Number(countMatch[1])
    };
  }

  const cargoWords = [
    "اثاث",
    "ملابس",
    "اجهزه",
    "بضاعه",
    "معدات",
    "ادوات",
    "خضار",
    "فاكهه",
    "مواد غذائيه",
    "مستلزمات"
  ];
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

function heuristicExtract(input) {
  const normalized = normalizeArabic(input);
  const route = extractRoute(input);
  const cargo = extractCargo(input);

  return {
    pickup: route.pickup,
    destination: route.destination,
    cargo: cargo.description,
    units: cargo.units,
    weightKg: firstNumber(normalized, /(\d+(?:\.\d+)?)\s*(?:كيلو|كجم|kg)/i),
    distanceKm: firstNumber(normalized, /(\d+(?:\.\d+)?)\s*(?:كم|كيلومتر|km)/i),
    requestedTime: extractRequestedTime(input)
  };
}

function safeNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

function safeText(value) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function mergeExtraction(rules, ai) {
  const aiData = ai?.data ?? {};
  return {
    pickup: safeText(rules.pickup) ?? safeText(aiData.pickup),
    destination: safeText(rules.destination) ?? safeText(aiData.destination),
    cargo: safeText(rules.cargo) ?? safeText(aiData.cargo),
    units: safeNumber(rules.units) ?? safeNumber(aiData.units),
    weightKg: safeNumber(rules.weightKg) ?? safeNumber(aiData.weightKg),
    distanceKm: safeNumber(rules.distanceKm) ?? safeNumber(aiData.distanceKm),
    requestedTime: rules.requestedTime ?? aiData.requestedTime ?? null
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

function buildArabicQuestion(missing) {
  const labels = {
    pickup: "مكان الاستلام",
    destination: "مكان التسليم",
    cargo: "نوع أو وصف الحمولة",
    weightKg: "الوزن التقريبي بالكيلو"
  };
  const needed = missing.map((x) => labels[x]).filter(Boolean);
  if (!needed.length) return null;
  return `محتاج أعرف ${needed.join(" و")} علشان أكمل طلب النقل.`;
}

export async function runTransportAgent(input) {
  const rules = heuristicExtract(input);
  const ai = await extractTransportWithAI(input);
  const request = mergeExtraction(rules, ai);

  const missing = [];
  if (!request.pickup) missing.push("pickup");
  if (!request.destination) missing.push("destination");
  if (!request.cargo) missing.push("cargo");
  if (!Number.isFinite(request.weightKg)) missing.push("weightKg");

  const vehicle = recommendVehicle(request.weightKg);
  const estimatedFare = estimateFare(vehicle?.id, request.distanceKm);
  const offers = createSimulatedOffers(estimatedFare);

  const actions = [
    {
      tool: "extract_transport_request",
      status: "done",
      source: ai.used ? `ai:${ai.provider}` : "deterministic_fallback"
    }
  ];

  if (missing.length) {
    actions.push({
      tool: "request_missing_information",
      status: "waiting_for_user",
      fields: missing
    });
  } else {
    actions.push({
      tool: "recommend_vehicle",
      status: "done",
      vehicleId: vehicle?.id ?? null
    });

    actions.push({
      tool: "calculate_route",
      status: Number.isFinite(request.distanceKm) ? "distance_supplied_for_demo" : "sandbox_integration_required"
    });

    actions.push({
      tool: "estimate_fare",
      status: Number.isFinite(estimatedFare) ? "done" : "waiting_for_route_distance"
    });

    actions.push({
      tool: "prepare_transport_request",
      status: "done"
    });

    actions.push({
      tool: "driver_matching_and_bidding",
      status: offers.length ? "simulated_public_demo" : "waiting_for_fare"
    });
  }

  const status = missing.length
    ? "needs_information"
    : Number.isFinite(request.distanceKm)
      ? "ready_for_matching"
      : "ready_for_routing";

  return {
    agent: {
      name: "3ASEKKA AI Transport Agent",
      aiEnabled: Boolean(ai.used),
      mode: ai.used ? "ai_plus_transport_tools" : "deterministic_safe_fallback",
      provider: ai.provider ?? null,
      model: ai.model ?? null,
      aiError: ai.error ?? null
    },
    status,
    intent: "local_goods_transport",
    request,
    recommendation: vehicle
      ? {
          vehicleId: vehicle.id,
          vehicleNameAr: vehicle.ar,
          reason:
            vehicle.id === "needs_review"
              ? "الحمولة أكبر من حدود المركبات الموجودة في النسخة العامة ويجب مراجعتها."
              : `ترشيح أولي حسب الوزن المعلن، داخل الحد الاسترشادي للمركبة (${vehicle.maxKg} كجم).`
        }
      : null,
    route: {
      distanceKm: request.distanceKm,
      source: Number.isFinite(request.distanceKm)
        ? "user_supplied_demo_value"
        : "production_route_engine_boundary"
    },
    pricing: {
      estimatedFare,
      currency: "EGP",
      demoOnly: true
    },
    offers,
    missing,
    followUpQuestionAr: buildArabicQuestion(missing),
    actions,
    nextAction: missing.length
      ? "Collect only the missing transport fields."
      : Number.isFinite(request.distanceKm)
        ? "Structured request is ready for sandbox driver matching/bidding."
        : "Call the route engine, then estimate fare and continue to matching."
  };
}
