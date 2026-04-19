const express = require("express");
const { callFn, query } = require("./db");
const { requireAuth, requireRole } = require("./sessionAuth");

const router = express.Router();

function ok(res, data) {
  res.json({ ok: true, data });
}

function fail(res, err) {
  const message = err && err.message ? err.message : "Internal error";
  res.status(400).json({ ok: false, error: message });
}

router.get("/health", async (req, res) => {
  try {
    const r = await query("SELECT NOW() AS now");
    ok(res, { status: "up", dbTime: r.rows[0].now });
  } catch (err) {
    fail(res, err);
  }
});

router.get("/admin/ping", requireAuth, requireRole("admin"), async (req, res) => {
  ok(res, { status: "admin-ok", userId: req.auth.user_id });
});

router.post("/auth/register", async (req, res) => {
  try {
    const { fullName, email, phone, role, passwordHash } = req.body;
    const r = await callFn("create_account", [fullName, email, phone, role, passwordHash]);
    ok(res, r.rows[0]);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/auth/login", async (req, res) => {
  try {
    const { email, passwordHash, sessionMinutes } = req.body;
    const r = await callFn("login_user", [email, passwordHash, sessionMinutes || 1440]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/auth/logout", async (req, res) => {
  try {
    const { sessionToken } = req.body;
    const r = await callFn("logout_user", [sessionToken]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/users/:userId", async (req, res) => {
  try {
    const { fullName, email, phone } = req.body;
    const r = await callFn("edit_profile", [req.params.userId, fullName || null, email || null, phone || null]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/users/:userId/password", async (req, res) => {
  try {
    const { oldPasswordHash, newPasswordHash } = req.body;
    const r = await callFn("change_password", [req.params.userId, oldPasswordHash, newPasswordHash]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.delete("/users/:userId", async (req, res) => {
  try {
    const r = await callFn("delete_account", [req.params.userId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/drivers/become", requireAuth, async (req, res) => {
  try {
    const { userId, licenseNumber } = req.body;
    const r = await callFn("become_driver", [userId, licenseNumber]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/drivers/:driverId/documents", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { docType, fileUrl } = req.body;
    const r = await callFn("upload_driver_document", [req.params.driverId, docType, fileUrl]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/drivers/:driverId/vehicle", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { vehicleId } = req.body;
    const r = await callFn("update_driver_vehicle_info", [req.params.driverId, vehicleId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.get("/drivers/:driverId/rating", async (req, res) => {
  try {
    const r = await callFn("view_driver_rating", [req.params.driverId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/vehicles", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { driverId, make, model, year, plateNumber, color, photoUrl } = req.body;
    const r = await callFn("add_vehicle", [driverId, make, model, year, plateNumber, color || null, photoUrl || null]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/vehicles/:vehicleId", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { make, model, year, plateNumber, color, photoUrl } = req.body;
    const r = await callFn("edit_vehicle", [
      req.params.vehicleId,
      make || null,
      model || null,
      year || null,
      plateNumber || null,
      color || null,
      photoUrl || null,
    ]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.delete("/vehicles/:vehicleId", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const r = await callFn("remove_vehicle", [req.params.vehicleId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/ride-requests", async (req, res) => {
  try {
    const { riderId, pickupLon, pickupLat, destLon, destLat } = req.body;
    const r = await callFn("request_ride", [riderId, pickupLon, pickupLat, destLon, destLat]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/ride-requests/:requestId/pickup", async (req, res) => {
  try {
    const { lon, lat } = req.body;
    const r = await callFn("set_pickup_location", [req.params.requestId, lon, lat]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/ride-requests/:requestId/destination", async (req, res) => {
  try {
    const { lon, lat } = req.body;
    const r = await callFn("set_destination_location", [req.params.requestId, lon, lat]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/ride-requests/:requestId/cancel", async (req, res) => {
  try {
    const r = await callFn("cancel_request", [req.params.requestId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/accept", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { requestId, driverId } = req.body;
    const r = await callFn("accept_ride", [requestId, driverId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/reject", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { requestId } = req.body;
    const r = await callFn("reject_ride", [requestId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/:rideId/start", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const r = await callFn("start_ride", [req.params.rideId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/:rideId/end", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { fareFinal } = req.body;
    const r = await callFn("end_ride", [req.params.rideId, fareFinal]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/:rideId/cancel", async (req, res) => {
  try {
    const r = await callFn("cancel_ride", [req.params.rideId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/:rideId/message", async (req, res) => {
  try {
    const { senderId, message } = req.body;
    const r = await callFn("send_ride_message", [req.params.rideId, senderId, message]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/rides/:rideId/share", async (req, res) => {
  try {
    const { sharedWith } = req.body;
    const r = await callFn("share_trip", [req.params.rideId, sharedWith]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/payments/methods", async (req, res) => {
  try {
    const { userId, methodType, providerToken, last4, makeDefault } = req.body;
    const r = await callFn("add_payment_method", [userId, methodType, providerToken || null, last4 || null, makeDefault !== false]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.patch("/payments/methods/select", async (req, res) => {
  try {
    const { userId, methodId } = req.body;
    const r = await callFn("select_payment_method", [userId, methodId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/payments/promo/apply", async (req, res) => {
  try {
    const { amount, code } = req.body;
    const r = await callFn("apply_promo_code", [amount, code]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/payments/pay-now", async (req, res) => {
  try {
    const { rideId, amount, method, status } = req.body;
    const r = await callFn("pay_now", [rideId, amount, method, status || "paid"]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/drivers/:driverId/online", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const { lon, lat } = req.body;
    const r = await callFn("go_online", [req.params.driverId, lon, lat]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/drivers/:driverId/offline", requireAuth, requireRole("driver", "admin"), async (req, res) => {
  try {
    const r = await callFn("go_offline", [req.params.driverId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.post("/ratings", async (req, res) => {
  try {
    const { rideId, rating, comment, raterUserId, ratedUserId, ratedRole } = req.body;
    const r = await callFn("submit_rating", [rideId, rating, comment || null, raterUserId, ratedUserId, ratedRole]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.get("/users/:userId/reviews", async (req, res) => {
  try {
    const r = await callFn("review_history", [req.params.userId]);
    ok(res, r.rows);
  } catch (err) {
    fail(res, err);
  }
});

router.get("/ride-requests/:requestId/distance", async (req, res) => {
  try {
    const r = await callFn("request_distance_meters", [req.params.requestId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.get("/ride-requests/:requestId/distance-km", async (req, res) => {
  try {
    const r = await callFn("request_distance_km", [req.params.requestId]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.get("/ride-requests/:requestId/quote", async (req, res) => {
  try {
    const { market = "default", weather = "normal" } = req.query;
    const r = await callFn("quote_request_by_market", [req.params.requestId, market, weather, null, null, null, null]);
    ok(res, r.rows[0] || null);
  } catch (err) {
    fail(res, err);
  }
});

router.get("/ride-requests/:requestId/match-top", async (req, res) => {
  try {
    const market = req.query.market || "default";
    const weather = req.query.weather || "normal";
    const top = Number(req.query.top || 3);
    const speed = Number(req.query.speed || 25);
    const r = await callFn("match_quote_top_drivers", [req.params.requestId, market, weather, top, speed]);
    ok(res, r.rows);
  } catch (err) {
    fail(res, err);
  }
});

module.exports = router;
