(function () {
  "use strict";

  var manifest = (window.PRD_MANIFEST && window.PRD_MANIFEST.apps) || { rider: [], driver: [], admin: [] };
  var appFromQuery = new URLSearchParams(window.location.search).get("app");
  var currentPath = normalizePath(window.location.pathname);
  var app = appFromQuery || detectApp(currentPath);
  var list = manifest[app] || [];
  var idx = list.indexOf(currentPath);
  var MOCK_USERS = {
    "standard@rydinex.com": {
      password: "password",
      phone: "000-000-000",
      name: "Standard Driver",
      role: "driver-standard",
      homePath: "driver_dashboard/code.html",
      homeApp: "driver"
    }
  };

  ensureViewportMeta();
  addBaseStyles();
  applyMobileFit();
  wireGlobalInteractions();
  wireButtons();
  wireTapTargets();
  wireForms();
  wireImages();
  wireImprovedScroll();
  wireKeyboardShortcuts();
  initDriverOpsControls();
  wireDriverNativeControls();
  wireHubCards();

  window.addEventListener("resize", debounce(applyMobileFit, 120));
  window.addEventListener("orientationchange", function () {
    window.setTimeout(applyMobileFit, 120);
  });

  function normalizePath(path) {
    if (!path) return "";
    var p = path.replace(/\\/g, "/");
    if (/^[A-Za-z]:\//.test(p)) {
      p = p.replace(/^[A-Za-z]:/, "");
    }
    var marker = "/PRD/";
    var ix = p.lastIndexOf(marker);
    if (ix >= 0) {
      p = p.substring(ix + marker.length);
    }
    if (p.charAt(0) === "/") p = p.substring(1);
    return p;
  }

  function detectApp(path) {
    var p = (path || "").toLowerCase();
    if (p.indexOf("admin") >= 0 || p.indexOf("security_") >= 0 || p.indexOf("access_") >= 0 || p.indexOf("regulatory_") >= 0 || p.indexOf("wizard") >= 0 || p.indexOf("state_launch") >= 0 || p.indexOf("market_research") >= 0 || p.indexOf("expansion_roadmap") >= 0 || p.indexOf("user_management") >= 0 || p.indexOf("role_permissions") >= 0 || p.indexOf("system_") >= 0 || p.indexOf("onboarding_") >= 0 || p.indexOf("vehicle_eligibility") >= 0 || p.indexOf("tnp_financial") >= 0) {
      return "admin";
    }
    if (p.indexOf("driver") >= 0 || p.indexOf("earnings_summary") >= 0 || p.indexOf("incoming_request") >= 0 || p.indexOf("vehicle_audit") >= 0 || p.indexOf("incident") >= 0 || p.indexOf("report_category") >= 0 || p.indexOf("report_confirmation") >= 0) {
      return "driver";
    }
    return "rider";
  }

  function ensureViewportMeta() {
    var meta = document.querySelector("meta[name='viewport']");
    if (!meta) {
      meta = document.createElement("meta");
      meta.setAttribute("name", "viewport");
      document.head.appendChild(meta);
    }
    var content = meta.getAttribute("content") || "";
    if (content.indexOf("viewport-fit=cover") === -1) {
      meta.setAttribute("content", "width=device-width, initial-scale=1.0, viewport-fit=cover");
    }
  }

  function wireGlobalInteractions() {
    document.addEventListener("click", function (e) {
      var link = e.target.closest("a");
      if (!link) return;
      var href = (link.getAttribute("href") || "").trim();
      if (href === "#" || href === "") {
        e.preventDefault();
        smartNavigate(link);
      }
    });
  }

  function wireButtons() {
    document.addEventListener("click", function (e) {
      var button = e.target.closest("button");
      if (!button) return;

      var label = readLabel(button);
      if (!label) {
        toast("Action completed");
        return;
      }

      if (shouldIgnoreAutoNavigate(button, label)) {
        return;
      }

      if (/(go|online|offline|break mode|break)/i.test(label)) {
        toggleOnlineState(button, label);
        return;
      }
      if (/(next|continue|proceed|book|request|confirm|approve|reject|submit|save|done|start|schedule|payment|promo|login|sign in|open|launch|finish|review)/i.test(label)) {
        toast(label + " complete");
        moveNext();
        return;
      }
      if (/(back|previous|cancel|close)/i.test(label)) {
        goPrev();
        return;
      }

      queueFallbackNavigation();
      toast(label + " tapped");
    });
  }

  function wireTapTargets() {
    document.addEventListener("click", function (e) {
      var target = e.target.closest("[role='button'], [onclick], .cursor-pointer");
      if (!target) return;
      if (target.tagName === "BUTTON" || target.tagName === "A") return;
      var label = readLabel(target);
      if (!label) {
        toast("Tapped");
        return;
      }
      if (shouldIgnoreAutoNavigate(target, label)) {
        return;
      }
      if (/(next|continue|proceed|book|request|confirm|submit|save|done|start|go)/i.test(label)) {
        toast(label + " complete");
        moveNext();
        return;
      }
      if (/(back|previous|cancel|close)/i.test(label)) {
        goPrev();
        return;
      }
      queueFallbackNavigation();
      toast(label + " tapped");
    });
  }

  function wireForms() {
    var forms = document.querySelectorAll("form");
    forms.forEach(function (form) {
      form.addEventListener("submit", function (e) {
        e.preventDefault();

        if (tryHandleMockLogin(form)) {
          return;
        }

        toast("Form submitted");
        moveNext();
      });
    });
  }

  function tryHandleMockLogin(form) {
    if (!form) return false;

    var emailInput = form.querySelector("input[type='email'], input[name='email'], input[id='email'], input[name='identifier'], input[id='identifier']");
    if (!emailInput) return false;

    var rawEmail = (emailInput.value || "").trim().toLowerCase();
    if (!rawEmail) {
      toast("Enter email");
      return true;
    }

    var passwordInput = form.querySelector("input[type='password'], input[name='password'], input[id='password'], input[name='security_key'], input[id='security_key']");
    var rawPassword = (passwordInput && passwordInput.value ? passwordInput.value : "").trim();

    var account = MOCK_USERS[rawEmail];
    if (!account) {
      toast("No demo account found");
      return true;
    }

    if (account.password !== rawPassword) {
      toast("Invalid password");
      return true;
    }

    try {
      window.localStorage.setItem("prdActiveUser", JSON.stringify({
        email: rawEmail,
        name: account.name,
        phone: account.phone,
        role: account.role
      }));
    } catch (err) {
      // Ignore localStorage failures in restrictive browser modes.
    }

    toast("Welcome " + account.name);
    navigateToPath(account.homePath, account.homeApp);
    return true;
  }

  function wireImages() {
    document.addEventListener("click", function (e) {
      var img = e.target.closest("img");
      if (!img) return;
      var src = img.getAttribute("src") || "";
      if (!src || src.indexOf("data:") === 0) return;
      showLightbox(src, img.getAttribute("alt") || "Preview");
    });
  }

  function wireImprovedScroll() {
    var scrollTargets = Array.prototype.slice.call(document.querySelectorAll("main, .overflow-y-auto, [class*='overflow-y-']"));
    if (!scrollTargets.length) return;

    window.addEventListener("wheel", function (event) {
      var bodyHidden = getComputedStyle(document.body).overflowY === "hidden" || getComputedStyle(document.body).overflow === "hidden";
      if (!bodyHidden) return;
      var target = scrollTargets.find(function (el) { return el.scrollHeight > el.clientHeight; });
      if (!target) return;
      target.scrollTop += event.deltaY;
      event.preventDefault();
    }, { passive: false });
  }

  function wireKeyboardShortcuts() {
    window.addEventListener("keydown", function (e) {
      if (e.key === "ArrowRight" || e.key.toLowerCase() === "n") {
        moveNext();
      }
      if (e.key === "ArrowLeft" || e.key.toLowerCase() === "p") {
        goPrev();
      }
      if (e.key.toLowerCase() === "g") {
        toggleGlobalOnline();
      }
    });
  }

  function smartNavigate(source) {
    var label = readLabel(source);
    if (/(next|continue|go|open|details|activity|book|request|home)/i.test(label)) {
      moveNext();
      return;
    }
    if (/(back|previous|cancel|close)/i.test(label)) {
      goPrev();
      return;
    }
    toast("Navigation action");
  }

  function queueFallbackNavigation() {
    var startUrl = window.location.href;
    window.setTimeout(function () {
      if (window.location.href === startUrl) {
        moveNext();
      }
    }, 120);
  }

  function shouldIgnoreAutoNavigate(node, label) {
    if (!node) return true;
    if (node.closest("#prd-driver-panel")) return true;
    if (node.closest("[data-prd-role='ops-card']")) return true;
    if (node.closest("[data-prd-no-auto-nav='true']")) return true;

    return /(notifications|refresh estimate|choose on map|set pickup|set destination|use current location|my location|layers|visibility|maps|earnings|fleet|blacksuv|rydinex black|rydinex regular|rydinex comfort|rydinex xl|rydinex economy|refresh|toggle|check tracking|remove queue group|save state rules|verify and close|apply mobile fit)/i.test(label);
  }

  function moveNext() {
    if (!list.length || idx < 0) {
      toast("No linked next screen");
      return;
    }
    var nextIndex = (idx + 1) % list.length;
    var target = relativeUrlFor(list[nextIndex]) + "?app=" + encodeURIComponent(app);
    window.location.href = target;
  }

  function goPrev() {
    if (!list.length || idx < 0) {
      if (window.history.length > 1) {
        window.history.back();
      } else {
        toast("No previous screen");
      }
      return;
    }
    var prevIndex = (idx - 1 + list.length) % list.length;
    var target = relativeUrlFor(list[prevIndex]) + "?app=" + encodeURIComponent(app);
    window.location.href = target;
  }

  function navigateToPath(targetPath, targetApp) {
    var chosenPath = targetPath;
    var chosenApp = targetApp || app;
    var targetList = manifest[chosenApp] || [];

    if (targetList.length && targetList.indexOf(chosenPath) < 0) {
      var dashboardFallback = targetList.find(function (p) { return /driver_dashboard\/code\.html$/i.test(p); });
      chosenPath = dashboardFallback || targetList[0] || chosenPath;
    }

    var target = relativeUrlFor(chosenPath) + "?app=" + encodeURIComponent(chosenApp);
    window.location.href = target;
  }

  function relativeUrlFor(targetPath) {
    var current = currentPath.split("/");
    current.pop();
    var target = targetPath.split("/");

    while (current.length && target.length && current[0] === target[0]) {
      current.shift();
      target.shift();
    }

    var up = new Array(current.length).fill("..");
    return up.concat(target).join("/");
  }

  function toggleOnlineState(button, label) {
    var host = button.closest("div,section,header,main") || document.body;
    var online = /offline/i.test(host.textContent || "") || /go/i.test(label);
    var from = online ? "Offline" : "Online";
    var to = online ? "Online" : "Offline";
    swapText(host, from, to);
    swapText(button, from, to);
    toggleDotColor(host, online);
    toast("Driver is now " + to);
  }

  function toggleGlobalOnline() {
    var all = Array.prototype.slice.call(document.querySelectorAll("button, span, p, h1, h2, h3, h4, h5"));
    var hasOffline = all.some(function (node) { return /offline/i.test(node.textContent || ""); });
    all.forEach(function (node) {
      if (hasOffline) {
        swapText(node, "Offline", "Online");
      } else {
        swapText(node, "Online", "Offline");
      }
    });
    toast("Status toggled");
  }

  function swapText(root, from, to) {
    if (!root) return;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
    var nodes = [];
    while (walker.nextNode()) {
      nodes.push(walker.currentNode);
    }
    nodes.forEach(function (n) {
      n.textContent = n.textContent.replace(new RegExp(from, "gi"), function () { return to; });
    });
  }

  function toggleDotColor(host, online) {
    var dots = host.querySelectorAll(".bg-outline, .bg-primary, .bg-on-surface-variant");
    dots.forEach(function (dot) {
      dot.classList.remove("bg-outline", "bg-primary", "bg-on-surface-variant");
      dot.classList.add(online ? "bg-primary" : "bg-outline");
    });
  }

  function readLabel(el) {
    if (!el) return "";
    var t = (el.innerText || el.textContent || "").replace(/\s+/g, " ").trim();
    return t;
  }

  function addBaseStyles() {
    if (document.getElementById("prd-runtime-style")) return;
    var style = document.createElement("style");
    style.id = "prd-runtime-style";
    style.textContent = ""
      + ".prd-toast{position:fixed;left:50%;bottom:110px;transform:translateX(-50%) translateY(12px);"
      + "background:rgba(17,19,23,.9);color:#fff;padding:10px 14px;border-radius:10px;font:600 12px/1.2 Inter,sans-serif;"
      + "z-index:99999;opacity:0;transition:all .18s ease;border:1px solid rgba(255,255,255,.18);pointer-events:none;}"
      + ".prd-toast.show{opacity:1;transform:translateX(-50%) translateY(0);}"
      + ".prd-lightbox{position:fixed;inset:0;background:rgba(0,0,0,.78);display:flex;align-items:center;justify-content:center;z-index:99998;padding:24px;}"
      + ".prd-lightbox img{max-width:min(96vw,820px);max-height:86vh;border-radius:14px;box-shadow:0 24px 80px rgba(0,0,0,.55);}"
      + ".prd-pill{position:fixed;top:12px;right:12px;z-index:99997;background:rgba(17,19,23,.85);color:#fff;padding:7px 10px;border-radius:999px;font:700 11px/1 Inter,sans-serif;border:1px solid rgba(255,255,255,.15);}"
      + "button,a{cursor:pointer;}"
      + "img,svg,video,canvas,iframe{max-width:100%;height:auto;}"
      + "html,body{max-width:100%;overflow-x:hidden;}"
      + ".prd-driver-panel{position:fixed;left:10px;bottom:90px;z-index:99996;width:min(360px,calc(100vw - 20px));background:rgba(12,16,23,.92);border:1px solid rgba(120,160,255,.35);border-radius:14px;padding:10px 10px 12px;color:#e9f0ff;font:600 12px/1.3 Inter,sans-serif;box-shadow:0 20px 60px rgba(0,0,0,.45);max-height:70vh;overflow:auto;}"
      + ".prd-driver-title{font:800 12px/1.2 Inter,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#b9d0ff;margin:0 0 8px;}"
      + ".prd-driver-row{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:6px 0;}"
      + ".prd-driver-sub{margin:9px 0 5px;font:700 11px/1.2 Inter,sans-serif;color:#92a9c7;text-transform:uppercase;letter-spacing:.08em;}"
      + ".prd-driver-chip{display:inline-flex;align-items:center;gap:6px;border:1px solid rgba(255,255,255,.2);border-radius:999px;padding:4px 8px;margin:3px 6px 3px 0;background:rgba(255,255,255,.04);}"
      + ".prd-driver-btn{background:#22344f;color:#fff;border:1px solid rgba(137,177,255,.45);border-radius:8px;padding:6px 9px;font:700 11px/1 Inter,sans-serif;}"
      + ".prd-driver-btn.danger{background:#4f232a;border-color:rgba(255,120,120,.6);}"
      + ".prd-driver-btn.good{background:#1f4436;border-color:rgba(117,221,171,.65);}"
      + ".prd-kv{font:600 11px/1.2 Inter,sans-serif;color:#d7e6ff;}"
      + ".prd-kv span{color:#8fb0d6;}"
      + ".prd-hub-note{margin:0 0 16px;color:#b7c9e2;font:700 12px/1.4 Inter,sans-serif;}"
      + ".prd-variant-badge{display:inline-flex;align-items:center;gap:4px;margin-top:8px;background:rgba(78,194,255,.12);color:#cfefff;border:1px solid rgba(78,194,255,.25);padding:4px 8px;border-radius:999px;font:700 11px/1 Inter,sans-serif;}"
      + "@media (max-width:430px){body{min-height:100dvh!important;height:auto!important;} .prd-pill{top:8px;right:8px;padding:6px 9px;font-size:10px;}}";
    document.head.appendChild(style);

    var pill = document.createElement("div");
    pill.className = "prd-pill";
    pill.textContent = app.toUpperCase() + " APP";
    document.body.appendChild(pill);
  }

  function wireHubCards() {
    if (!/^apps\/(rider|driver|admin)\/index\.html$/i.test(currentPath)) return;

    var grid = document.querySelector(".grid");
    if (!grid) return;

    var cards = Array.prototype.slice.call(grid.querySelectorAll(".card[href]"));
    if (!cards.length) return;

    var groups = new Map();
    cards.forEach(function (card) {
      var href = card.getAttribute("href") || "";
      var key = hubSemanticKey(href);
      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key).push(card);
    });

    var collapsedGroups = 0;
    groups.forEach(function (items) {
      if (!items || items.length < 2) return;

      var lead = items[0];
      var label = lead.querySelector(".k");
      var pathNode = lead.querySelector(".p");
      if (label) {
        label.textContent = prettifyHubLabel(label.textContent || "");
      }
      if (pathNode) {
        pathNode.textContent = pathNode.textContent + " + " + (items.length - 1) + " related variants";
      }

      var badge = document.createElement("span");
      badge.className = "prd-variant-badge";
      badge.textContent = "+" + (items.length - 1) + " variants";
      lead.appendChild(badge);

      items.slice(1).forEach(function (item) { item.remove(); });
      collapsedGroups += 1;
    });

    if (!collapsedGroups) return;

    var note = document.createElement("p");
    note.className = "prd-hub-note";
    note.textContent = "Similar PRD variants are grouped here to reduce duplicate screen clutter. Open the first card in each group to start the flow.";

    var main = document.querySelector("main");
    var top = document.querySelector(".top");
    if (main && top && top.nextSibling) {
      main.insertBefore(note, top.nextSibling);
    }
  }

  function hubSemanticKey(href) {
    var raw = (href || "").replace(/^\.\.\/\.\.\//, "").replace(/\?app=.*$/i, "");
    return raw
      .replace(/\/code\.html$/i, "")
      .replace(/(?:_[0-9]+|_refined_surge|_updated_surge|_with_fair_pay_badge|_with_audit|_break_mode)$/i, "");
  }

  function prettifyHubLabel(value) {
    return String(value || "")
      .replace(/(?:_[0-9]+|_refined_surge|_updated_surge|_with_fair_pay_badge|_with_audit|_break_mode)$/i, "")
      .replace(/_/g, " ")
      .trim();
  }

  function applyMobileFit() {
    var width = window.innerWidth || document.documentElement.clientWidth;
    var compact = width <= 430;

    document.documentElement.classList.toggle("prd-mobile", compact);
    document.body.classList.toggle("prd-mobile", compact);

    normalizeOversizedNodes(compact);
  }

  function normalizeOversizedNodes(compact) {
    var viewportWidth = Math.max(320, window.innerWidth || 320);
    var selectors = [
      "main", "section", "article", "aside", "header", "footer", "div", "form", "table"
    ].join(",");
    var nodes = document.querySelectorAll(selectors);

    nodes.forEach(function (node) {
      if (!node || !node.getBoundingClientRect) return;
      var rect = node.getBoundingClientRect();
      if (rect.width > viewportWidth + 2) {
        node.style.maxWidth = "100%";
        if (compact) {
          node.style.width = "100%";
        }
        node.style.boxSizing = "border-box";
      }

      if (node.scrollWidth > viewportWidth + 6 && compact) {
        node.style.overflowX = "auto";
        node.style.webkitOverflowScrolling = "touch";
      }
    });
  }

  function debounce(fn, wait) {
    var timer = 0;
    return function () {
      var args = arguments;
      window.clearTimeout(timer);
      timer = window.setTimeout(function () { fn.apply(null, args); }, wait);
    };
  }

  function initDriverOpsControls() {
    // Ops panel suppressed globally — driver screens use their own native UI controls.
    return;

    var panel = document.createElement("div");
    panel.id = "prd-driver-panel";
    panel.className = "prd-driver-panel";
    panel.innerHTML = ""
      + "<p class='prd-driver-title'>Driver Real-Time Operations</p>"
      + "<div class='prd-driver-row'><span>Tracking status</span><strong id='prd-track-status'>Offline</strong></div>"
      + "<div class='prd-driver-row'><span>Socket</span><strong id='prd-socket-status' style='color:#ff9ca0'>Disconnected</strong></div>"
      + "<div class='prd-driver-row'><span>Location precision</span><strong id='prd-precision'>Not checked</strong></div>"
      + "<div class='prd-driver-row'><button id='prd-check-tracking' class='prd-driver-btn'>Check Tracking</button></div>"
      + "<p class='prd-driver-sub'>Airport Geofencing (Corrected)</p>"
      + "<div class='prd-kv'><span>O'Hare (ORD):</span> 41.9742, -87.9073</div>"
      + "<div class='prd-kv' style='margin-bottom:6px;'><span>Midway (MDW):</span> 41.7868, -87.7522</div>"
      + "<div class='prd-kv'><span>Classes:</span> Black, Black SUV</div>"
      + "<p class='prd-driver-sub'>Queue Operations (Airport + Events)</p>"
      + "<label class='prd-driver-chip'><input id='prd-q-black' type='checkbox' checked/> Black</label>"
      + "<label class='prd-driver-chip'><input id='prd-q-black-suv' type='checkbox' checked/> Black SUV</label>"
      + "<div id='prd-queue-group' class='prd-driver-row'><span>Queue Group</span><strong>Premium Group A</strong></div>"
      + "<div class='prd-driver-row'><button id='prd-remove-qgroup' class='prd-driver-btn danger'>Remove Queue Group</button></div>"
      + "<p class='prd-driver-sub'>Surge Visibility</p>"
      + "<label class='prd-driver-chip'><input id='prd-s-black' type='checkbox' checked/> Black</label>"
      + "<label class='prd-driver-chip'><input id='prd-s-black-suv' type='checkbox' checked/> Black SUV</label>"
      + "<p class='prd-driver-sub' id='prd-state-rules-title'>Multi State Rules</p>"
      + "<div id='prd-state-rules-box' class='prd-driver-row'><span>Selected</span><button id='prd-save-state-rules' class='prd-driver-btn good'>Save State Rules</button></div>"
      + "<p class='prd-driver-sub' id='prd-chauffeur-title'>Chauffeur License Verification</p>"
      + "<div id='prd-chauffeur-box' class='prd-driver-row'><span>Pending</span><button id='prd-verify-chauffeur' class='prd-driver-btn good'>Verify and Close</button></div>";
    document.body.appendChild(panel);

    var btnCheck = document.getElementById("prd-check-tracking");
    var btnRemoveGroup = document.getElementById("prd-remove-qgroup");
    var btnSaveRules = document.getElementById("prd-save-state-rules");
    var btnVerify = document.getElementById("prd-verify-chauffeur");

    if (btnCheck) {
      btnCheck.addEventListener("click", function () {
        runTrackingCheck();
      });
    }
    if (btnRemoveGroup) {
      btnRemoveGroup.addEventListener("click", function () {
        var row = document.getElementById("prd-queue-group");
        if (row) row.style.display = "none";
        toast("Queue group removed");
      });
    }
    if (btnSaveRules) {
      btnSaveRules.addEventListener("click", function () {
        closeSection(["prd-state-rules-box", "prd-state-rules-title"]);
        toast("State rules saved and closed");
      });
    }
    if (btnVerify) {
      btnVerify.addEventListener("click", function () {
        closeSection(["prd-chauffeur-box", "prd-chauffeur-title"]);
        toast("Chauffeur license verified and closed");
      });
    }
  }

  function runTrackingCheck() {
    var socketNode = document.getElementById("prd-socket-status");
    var precisionNode = document.getElementById("prd-precision");
    var trackNode = document.getElementById("prd-track-status");

    if (socketNode) {
      socketNode.textContent = "Disconnected";
      socketNode.style.color = "#ff9ca0";
    }

    var markResult = function (text) {
      if (precisionNode) precisionNode.textContent = text;
      if (trackNode) trackNode.textContent = "Offline Check";
      toast("Tracking check complete");
    };

    if (!navigator.geolocation) {
      markResult("Unavailable");
      return;
    }

    navigator.geolocation.getCurrentPosition(function (pos) {
      var acc = typeof pos.coords.accuracy === "number" ? Math.round(pos.coords.accuracy) + "m" : "Unknown";
      markResult(acc);
    }, function () {
      markResult("Permission denied");
    }, { enableHighAccuracy: true, timeout: 8000, maximumAge: 0 });
  }

  function closeSection(ids) {
    ids.forEach(function (id) {
      var node = document.getElementById(id);
      if (node) {
        node.style.display = "none";
      }
    });
  }

  function wireDriverNativeControls() {
    if (app !== "driver") return;
    document.addEventListener("click", function (e) {
      var btn = e.target.closest("[data-prd-action]");
      if (!btn) return;

      var action = (btn.getAttribute("data-prd-action") || "").toLowerCase();
      if (!action) return;

      if (action === "check-tracking") {
        runTrackingCheck();
        return;
      }

      if (action === "remove-queue-group") {
        var box = btn.closest("[data-prd-role='ops-card']") || document;
        var group = box.querySelector("[data-prd-role='queue-group']");
        if (group) group.style.display = "none";
        toast("Queue group removed");
        return;
      }

      if (action === "save-state-rules") {
        var ops = btn.closest("[data-prd-role='ops-card']") || document;
        var stateRules = ops.querySelector("[data-prd-role='state-rules']");
        if (stateRules) stateRules.style.display = "none";
        toast("State rules saved and closed");
        return;
      }

      if (action === "verify-chauffeur") {
        var root = btn.closest("[data-prd-role='ops-card']") || document;
        var chauffeur = root.querySelector("[data-prd-role='chauffeur']");
        if (chauffeur) chauffeur.style.display = "none";
        toast("Chauffeur license verified and closed");
      }
    });
  }

  function toast(message) {
    var node = document.getElementById("prd-toast");
    if (!node) {
      node = document.createElement("div");
      node.id = "prd-toast";
      node.className = "prd-toast";
      document.body.appendChild(node);
    }
    node.textContent = message;
    node.classList.add("show");
    window.clearTimeout(node._hideTimer);
    node._hideTimer = window.setTimeout(function () { node.classList.remove("show"); }, 1400);
  }

  function showLightbox(src, alt) {
    var overlay = document.createElement("div");
    overlay.className = "prd-lightbox";
    overlay.innerHTML = "<img alt=\"" + escapeHtml(alt) + "\" src=\"" + escapeHtml(src) + "\" />";
    overlay.addEventListener("click", function () { overlay.remove(); });
    document.body.appendChild(overlay);
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }
})();
