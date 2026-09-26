import assert from "node:assert/strict";

process.env.FORCE_RULES_ONLY = "1";

const { runTransportAgent } = await import("./agent.mjs");

const cases = [
  {
    name: "Alexandria boxes full request",
    input: "عايز أنقل 20 كرتونة من سموحة إلى المنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم",
    check(result) {
      assert.equal(result.request.pickup, "سموحة");
      assert.equal(result.request.destination, "المنشية");
      assert.equal(result.request.weightKg, 250);
      assert.equal(result.request.distanceKm, 12);
      assert.equal(result.recommendation.vehicleId, "tricycle");
      assert.equal(result.status, "ready_for_matching");
      assert.ok(Number.isFinite(result.pricing.estimatedFare));
    }
  },
  {
    name: "Arabic Indic digits",
    input: "انقل ١٠ كرتونة من سيدي جابر إلى كليوباترا وزنهم ٤٠ كيلو والمسافة ٦ كم",
    check(result) {
      assert.equal(result.request.weightKg, 40);
      assert.equal(result.request.distanceKm, 6);
      assert.equal(result.recommendation.vehicleId, "motorbike");
    }
  },
  {
    name: "Missing weight asks only for missing data",
    input: "عايز أنقل أثاث من رشدي إلى سموحة",
    check(result) {
      assert.equal(result.status, "needs_information");
      assert.deepEqual(result.missing, ["weightKg"]);
      assert.match(result.followUpQuestionAr, /الوزن/);
    }
  },
  {
    name: "Distance is routed instead of asked from customer",
    input: "عايز أنقل معدات من محرم بك إلى سموحة وزنها 500 كيلو",
    check(result) {
      assert.equal(result.status, "ready_for_routing");
      assert.equal(result.missing.length, 0);
      assert.equal(result.recommendation.vehicleId, "van");
      assert.equal(result.route.source, "production_route_engine_boundary");
    }
  },
  {
    name: "Heavy load selects quarter pickup",
    input: "نقل بضاعة من العجمي إلى برج العرب وزنها 1200 كيلو والمسافة 35 كم",
    check(result) {
      assert.equal(result.recommendation.vehicleId, "quarter_pickup");
      assert.equal(result.status, "ready_for_matching");
    }
  }
];

let passed = 0;

for (const testCase of cases) {
  const result = await runTransportAgent(testCase.input);
  try {
    testCase.check(result);
    passed += 1;
    console.log("PASS:", testCase.name);
  } catch (error) {
    console.error("FAIL:", testCase.name);
    console.error(JSON.stringify(result, null, 2));
    throw error;
  }
}

console.log("\n" + passed + "/" + cases.length + " evaluation cases passed.");
