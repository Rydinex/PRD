const { query } = require("./db");

function extractSessionToken(req) {
  const authHeader = req.headers.authorization || "";
  if (authHeader.toLowerCase().startsWith("bearer ")) {
    return authHeader.slice(7).trim();
  }

  const headerToken = req.headers["x-session-token"];
  if (headerToken) return String(headerToken).trim();

  const queryToken = req.query.sessionToken;
  if (queryToken) return String(queryToken).trim();

  return null;
}

async function loadSessionContext(token) {
  if (!token) return null;

  const sql = `
    SELECT
      s.user_id,
      u.role,
      u.full_name,
      s.session_token,
      s.expires_at
    FROM user_sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.session_token = $1
      AND s.revoked_at IS NULL
      AND s.expires_at > NOW()
      AND u.deleted_at IS NULL
      AND u.is_active = TRUE
    LIMIT 1
  `;

  const r = await query(sql, [token]);
  if (!r.rows.length) return null;
  return r.rows[0];
}

function requireAuth(req, res, next) {
  const token = extractSessionToken(req);
  if (!token) {
    return res.status(401).json({ ok: false, error: "Missing session token" });
  }

  loadSessionContext(token)
    .then((ctx) => {
      if (!ctx) {
        return res.status(401).json({ ok: false, error: "Invalid or expired session" });
      }
      req.auth = ctx;
      return next();
    })
    .catch((err) => {
      return res.status(500).json({ ok: false, error: err.message || "Auth check failed" });
    });
}

function requireRole(...roles) {
  return function roleGuard(req, res, next) {
    if (!req.auth) {
      return res.status(401).json({ ok: false, error: "Not authenticated" });
    }

    if (!roles.includes(req.auth.role)) {
      return res.status(403).json({ ok: false, error: "Insufficient role" });
    }

    return next();
  };
}

module.exports = {
  requireAuth,
  requireRole,
};
