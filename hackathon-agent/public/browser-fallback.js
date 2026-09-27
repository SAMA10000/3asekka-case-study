(function () {
  const vehicles = [
    { id: "motorbike", ar: "موتوسيكل", maxKg: 50, base: 15, perKm: 2 },
    { id: "tricycle", ar: "تروسيكل", maxKg: 300, base: 20, perKm: 2.8 },
    { id: "van", ar: "فان", maxKg: 700, base: 45, perKm: 5.5 },
    { id: "quarter_pickup", ar: "ربع نقل", maxKg: 1500, base: 30, perKm: 3.75 }
  ];

  function latinDigits(text) {
    const arabic = "٠١٢٣٤٥٦٧٨٩";
    const eastern = "۰۱۲۳۴۵۶۷۸۹";
    return String(text)
      .replace(/[٠-٩]/g, (d) => String(arabic.indexOf(d)))
      .replace(/[۰-۹]/g, (d) => String(eastern.indexOf(d)));
  }

  function normalize(text) {
    return latinDigits(text)
      .replace(/[أإآ]/g, "ا")
      .replace(/ى/g, "ي")
      .replace(/ة/g, "ه")
      .replace(/[ًٌٍَُِّْـ]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function routeFrom(text) {
    const clean = latinDigits(text).replace(/\s+/g, " ").trim();
    const patterns = [
      /من\s+(.+?)\s+(?:إلى|الى|لـ|ل)\s*([^،,.]+?)(?=\s+(?:بكره|بكرة|غدا|غداً|الساعة|الساعه|وزن|وزنهم|حوالي|مساف|عدد)|[،,.]|$)/i,
      /من\s+(.+?)\s+(?:إلى|الى|لـ)\s*([^،,.]+)/i
    ];
    for (const p of patterns) {
      const m = clean.match(p);
      if (m) return { pickup: m[1].trim(), destination: m[2].trim() };
    }
    return { pickup: null, destination: null };
  }

  function numberFrom(text, regex) {
    const m = text.match(regex);
    return m ? Number(m[1]) : null;
  }

  function cargoFrom(text) {
    const n = normalize(text);
    const counted = n.match(/(\d+)\s*(كرتونه|كرتون|صندوق|طرد|قطعه|شوال|جوال)/);
    if (counted) return counted[1] + " " + counted[2];
    return ["اثاث","ملابس","اجهزه","بضاعه","معدات","ادوات","خضار","فاكهه","مستلزمات"]
      .find((x) => n.includes(x)) || null;
  }

  function createOffers(fare) {
    if (!Number.isFinite(fare)) return [];
    const drivers = [
      { name: "أحمد", rating: 4.8, completedTrips: 326, mult: 0.95 },
      { name: "محمود", rating: 4.9, completedTrips: 514, mult: 1.00 },
      { name: "كريم", rating: 4.7, completedTrips: 281, mult: 1.08 }
    ];
    return drivers.map((d, i) => ({
      id: "demo-offer-" + (i + 1),
      driverName: d.name,
      amount: Math.round(fare * d.mult),
      rating: d.rating,
      completedTrips: d.completedTrips,
      simulated: true
    }));
  }

  window.run3AsekkaBrowserFallback = function (input) {
    const n = normalize(input);
    const route = routeFrom(input);
    const cargo = cargoFrom(input);
    const weightKg = numberFrom(n, /(\d+(?:\.\d+)?)\s*(?:كيلو|كجم|kg)/i);
    const distanceKm = numberFrom(n, /(\d+(?:\.\d+)?)\s*(?:كم|كيلومتر|km)/i);

    const missing = [];
    if (!route.pickup) missing.push("pickup");
    if (!route.destination) missing.push("destination");
    if (!cargo) missing.push("cargo");
    if (!Number.isFinite(weightKg)) missing.push("weightKg");

    const vehicle = Number.isFinite(weightKg)
      ? (vehicles.find((v) => weightKg <= v.maxKg) || { id: "needs_review", ar: "تحتاج مراجعة حمولة" })
      : null;

    const fare = vehicle && vehicle.base != null && Number.isFinite(distanceKm)
      ? Math.round((vehicle.base + vehicle.perKm * distanceKm) * 100) / 100
      : null;

    const labels = {
      pickup: "مكان الاستلام",
      destination: "مكان التسليم",
      cargo: "نوع أو وصف الحمولة",
      weightKg: "الوزن التقريبي بالكيلو"
    };

    const actions = [{ tool: "extract_transport_request", status: "done", source: "browser_safe_fallback" }];

    if (missing.length) {
      actions.push({ tool: "request_missing_information", status: "waiting_for_user", fields: missing });
    } else {
      actions.push({ tool: "recommend_vehicle", status: "done", vehicleId: vehicle?.id || null });
      actions.push({
        tool: "calculate_route",
        status: Number.isFinite(distanceKm) ? "distance_supplied_for_demo" : "sandbox_integration_required"
      });
      actions.push({
        tool: "estimate_fare",
        status: Number.isFinite(fare) ? "done" : "waiting_for_route_distance"
      });
      actions.push({ tool: "prepare_transport_request", status: "done" });
      actions.push({
        tool: "driver_matching_and_bidding",
        status: Number.isFinite(fare) ? "simulated_public_demo" : "waiting_for_fare"
      });
    }

    return {
      agent: {
        name: "3ASEKKA AI Transport Agent",
        aiEnabled: false,
        mode: "github_pages_safe_fallback",
        provider: null,
        model: null,
        aiError: null
      },
      status: missing.length ? "needs_information" : (Number.isFinite(distanceKm) ? "ready_for_matching" : "ready_for_routing"),
      intent: "local_goods_transport",
      request: {
        pickup: route.pickup,
        destination: route.destination,
        cargo,
        units: null,
        weightKg,
        distanceKm,
        requestedTime: /بكره|بكرة|غدا|غداً/.test(input) ? { day: "tomorrow", hour: null, minute: null } : null
      },
      recommendation: vehicle ? {
        vehicleId: vehicle.id,
        vehicleNameAr: vehicle.ar,
        reason: vehicle.id === "needs_review"
          ? "الحمولة تحتاج مراجعة."
          : "ترشيح أولي حسب الوزن المعلن."
      } : null,
      route: {
        distanceKm,
        source: Number.isFinite(distanceKm) ? "user_supplied_demo_value" : "production_route_engine_boundary"
      },
      pricing: { estimatedFare: fare, currency: "EGP", demoOnly: true },
      offers: createOffers(fare),
      missing,
      followUpQuestionAr: missing.length
        ? "محتاج أعرف " + missing.map((x) => labels[x]).join(" و") + " علشان أكمل طلب النقل."
        : null,
      actions,
      nextAction: missing.length
        ? "Collect only the missing transport fields."
        : (Number.isFinite(distanceKm) ? "Ready for sandbox matching." : "Call route engine next.")
    };
  };
})();
