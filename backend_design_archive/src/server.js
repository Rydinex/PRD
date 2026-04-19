require("dotenv").config();

const express = require("express");
const path = require("path");
const routes = require("./routes");
const { requireAuth, requireRole } = require("./sessionAuth");

const app = express();
const port = Number(process.env.PORT || 3000);
const projectRoot = path.resolve(__dirname, "..", "..");

app.use(express.json({ limit: "1mb" }));
app.use("/api", routes);

// Serve all PRD frontend files on the same domain as the API.
app.use(express.static(projectRoot, { extensions: ["html"] }));

app.get("/web-dashboard", (req, res) => {
  res.sendFile(path.join(projectRoot, "index.html"));
});

app.get("/admin-dashboard", requireAuth, requireRole("admin"), (req, res) => {
  res.sendFile(path.join(projectRoot, "apps", "admin", "index.html"));
});

app.get("/rider-app", (req, res) => {
  res.sendFile(path.join(projectRoot, "apps", "rider", "index.html"));
});

app.get("/driver-app", requireAuth, requireRole("driver", "admin"), (req, res) => {
  res.sendFile(path.join(projectRoot, "apps", "driver", "index.html"));
});

app.get("/", (req, res) => {
  res.sendFile(path.join(projectRoot, "index.html"));
});

app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Rydinex API listening on :${port}`);
});
