"use strict";
// Plain JavaScript dashboard. It talks to the same API documented at /docs.
// Safety rules: data is only ever inserted as text (never as HTML), and the
// API key lives in memory only (never saved in the browser or put in the URL).

const PAGE_SIZE = 10;
const state = { key: "", svcOffset: 0, incOffset: 0, services: [] };
const $ = (id) => document.getElementById(id);

// Build an element. String children become text nodes, so they cannot inject HTML.
function el(tag, attrs, ...children) {
  const node = document.createElement(tag);
  for (const [name, value] of Object.entries(attrs || {})) {
    if (name === "class") node.className = value;
    else if (name.startsWith("on")) node.addEventListener(name.slice(2), value);
    else node.setAttribute(name, value);
  }
  node.append(...children);
  return node;
}

function showMessage(text, kind) {
  const box = $("message");
  box.textContent = text;
  box.className = kind || "";
}

function describeError(status, data) {
  const detail = data && data.detail;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    return detail.map((d) => `${(d.loc || []).slice(1).join(".") || "input"}: ${d.msg}`).join("; ");
  }
  return `Request failed (HTTP ${status})`;
}

async function api(method, path, body) {
  const headers = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (method !== "GET") {
    if (!state.key) throw new Error("Enter the API key first (top of the page).");
    headers["X-API-Key"] = state.key;
  }
  const response = await fetch(path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (response.status === 204) return null;
  const data = await response.json().catch(() => null);
  if (!response.ok) throw new Error(describeError(response.status, data));
  return data;
}

// Run an action and show any error instead of failing silently.
async function run(action, successText) {
  try {
    await action();
    if (successText) showMessage(successText, "ok");
  } catch (error) {
    showMessage(error.message, "error");
  }
}

function badge(value) {
  return el("span", { class: `badge b-${value.toLowerCase()}` }, value);
}

function formatTime(value) {
  return value ? new Date(value).toLocaleString() : "-";
}

function emptyRow(columns, text) {
  return el("tr", {}, el("td", { class: "empty", colspan: String(columns) }, text));
}

function query(params) {
  const q = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== "" && value !== undefined) q.set(key, value);
  }
  return q.toString();
}

function renderPager(container, total, offset, onChange) {
  const first = total === 0 ? 0 : offset + 1;
  const last = Math.min(offset + PAGE_SIZE, total);
  const prev = el("button", { type: "button", class: "secondary" }, "Previous");
  const next = el("button", { type: "button", class: "secondary" }, "Next");
  prev.disabled = offset === 0;
  next.disabled = offset + PAGE_SIZE >= total;
  prev.addEventListener("click", () => onChange(Math.max(0, offset - PAGE_SIZE)));
  next.addEventListener("click", () => onChange(offset + PAGE_SIZE));
  container.replaceChildren(prev, next, el("span", {}, `${first}-${last} of ${total}`));
}

function statusSelect(options, current, onChange) {
  const select = el("select", { "aria-label": "Change status" },
    ...options.map((o) => el("option", { value: o }, o)));
  select.value = current;
  select.addEventListener("change", () => onChange(select.value));
  return select;
}

// ---------- metrics ----------
async function loadMetrics() {
  const m = await api("GET", "/metrics/summary");
  const items = [
    ["Total services", m.total_services],
    ["Healthy services", m.healthy_services],
    ["Unhealthy services", m.unhealthy_services],
    ["Open incidents", m.open_incidents],
    ["Critical open incidents", m.critical_open_incidents],
    ["Resolved incidents", m.resolved_incidents],
  ];
  $("metrics").replaceChildren(...items.map(([label, value]) =>
    el("div", { class: "card" }, el("div", { class: "num" }, String(value)), el("div", { class: "label" }, label))));
}

// ---------- services ----------
async function loadAllServices() {
  // Used for the dropdowns and to show service names in the incident table.
  const data = await api("GET", "/services?limit=100");
  state.services = data.items;
  const options = (placeholder) => [
    ...(placeholder ? [el("option", { value: "" }, placeholder)] : []),
    ...data.items.map((s) => el("option", { value: String(s.id) }, `${s.name} (${s.environment})`)),
  ];
  const create = $("inc-service");
  const keep = create.value;
  create.replaceChildren(...options(null));
  if (keep) create.value = keep;
  const filter = $("f-inc-service");
  const keepFilter = filter.value;
  filter.replaceChildren(...options("all"));
  filter.value = keepFilter;
}

async function loadServices() {
  const q = query({
    limit: PAGE_SIZE, offset: state.svcOffset,
    environment: $("f-svc-env").value, status: $("f-svc-status").value,
  });
  const data = await api("GET", `/services?${q}`);
  const rows = data.items.map((s) => el("tr", {},
    el("td", {}, String(s.id)),
    el("td", {}, s.name),
    el("td", {}, s.environment),
    el("td", {}, badge(s.status)),
    el("td", {}, s.description || "-"),
    el("td", {}, el("div", { class: "actions" },
      statusSelect(["HEALTHY", "DEGRADED", "DOWN"], s.status, (status) =>
        run(async () => { await api("PATCH", `/services/${s.id}`, { status }); await refreshAll(); }, "Service updated")),
      el("button", { type: "button", class: "danger", onclick: () => {
        if (!confirm(`Delete service "${s.name}"?`)) return;
        run(async () => { await api("DELETE", `/services/${s.id}`); await refreshAll(); }, "Service deleted");
      } }, "Delete")))));
  $("services-body").replaceChildren(...(rows.length ? rows : [emptyRow(6, "No services yet")]));
  renderPager($("svc-pager"), data.total, data.offset, (offset) => {
    state.svcOffset = offset;
    run(loadServices);
  });
}

// ---------- incidents ----------
async function loadIncidents() {
  const q = query({
    limit: PAGE_SIZE, offset: state.incOffset,
    severity: $("f-inc-severity").value, status: $("f-inc-status").value,
    service_id: $("f-inc-service").value,
  });
  const data = await api("GET", `/incidents?${q}`);
  const names = new Map(state.services.map((s) => [s.id, `${s.name} (${s.environment})`]));
  const rows = data.items.map((i) => el("tr", {},
    el("td", {}, String(i.id)),
    el("td", {}, i.title),
    el("td", {}, badge(i.severity)),
    el("td", {}, badge(i.status), " ",
      statusSelect(["OPEN", "INVESTIGATING", "RESOLVED"], i.status, (status) =>
        run(async () => { await api("PATCH", `/incidents/${i.id}`, { status }); await refreshAll(); }, "Incident updated"))),
    el("td", {}, names.get(i.service_id) || `#${i.service_id}`),
    el("td", {}, formatTime(i.created_at)),
    el("td", {}, formatTime(i.resolved_at))));
  $("incidents-body").replaceChildren(...(rows.length ? rows : [emptyRow(7, "No incidents match")]));
  renderPager($("inc-pager"), data.total, data.offset, (offset) => {
    state.incOffset = offset;
    run(loadIncidents);
  });
}

async function refreshAll() {
  await loadAllServices();
  await Promise.all([loadMetrics(), loadServices(), loadIncidents()]);
}

// ---------- events ----------
$("api-key").addEventListener("input", (e) => { state.key = e.target.value.trim(); });
$("refresh").addEventListener("click", () => run(refreshAll, "Refreshed"));

for (const id of ["f-svc-env", "f-svc-status"]) {
  $(id).addEventListener("change", () => { state.svcOffset = 0; run(loadServices); });
}
for (const id of ["f-inc-severity", "f-inc-status", "f-inc-service"]) {
  $(id).addEventListener("change", () => { state.incOffset = 0; run(loadIncidents); });
}

$("service-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const body = { name: $("svc-name").value, environment: $("svc-env").value, status: $("svc-status").value };
  if ($("svc-desc").value.trim()) body.description = $("svc-desc").value;
  run(async () => {
    await api("POST", "/services", body);
    $("service-form").reset();
    await refreshAll();
  }, "Service created");
});

$("incident-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const serviceId = Number($("inc-service").value);
  if (!serviceId) { showMessage("Create a service first, then pick it here.", "error"); return; }
  const body = { title: $("inc-title").value, severity: $("inc-severity").value, service_id: serviceId };
  if ($("inc-desc").value.trim()) body.description = $("inc-desc").value;
  run(async () => {
    await api("POST", "/incidents", body);
    $("incident-form").reset();
    await refreshAll();
  }, "Incident reported");
});

run(refreshAll);
