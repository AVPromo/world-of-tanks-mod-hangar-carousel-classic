const MODEL_NAME = "hangarCarouselClassic";
const CARD_PREFIX = "vehicleCard-";

const LABELS = {
  en: {
    sort_default: "Default order",
    sort_battles: "Battles",
    sort_winRate: "Win rate",
    sort_averageDamage: "Average damage",
    sort_marksOnGun: "Marks of Excellence",
    sort_lastPlayed: "Last played (HCC)",
    sorting: "HCC sorting",
    stat_battles: "⚔️",
    stat_win_rate: "💯",
    stat_damage: "🎯",
    stat_alpha_damage: "🔥",
    stat_mastery: "🥇",
    stat_marks: "〽️",
    carousel_rows: "Carousel rows",
    carousel_rows_description: "Number of vehicle rows displayed in the hangar carousel.",
    carousel_auto: "Automatic rows",
    carousel_auto_description: "Uses 1 row for up to 8 matching vehicles, 2 for up to 16, 3 for up to 24, and 4 above 24.",
    ascending: "Ascending",
    descending: "Descending",
    refresh: "Refresh HCC data",
    unavailable: "Vehicle playlists are unavailable in this client mode"
  }
};

const SORT_ICONS = {
  default: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M8 4v16M5 7l3-3 3 3M16 20V4M13 17l3 3 3-3"/></svg>',
  battles: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 20h18M4 20v-6h4v6M10 20V9h4v11M16 20V4h4v16"/></svg>',
  winRate: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="m4 18 5-5 4 3 7-9M15 7h5v5"/></svg>',
  averageDamage: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="m13 2-8 12h6l-1 8 9-13h-6z"/></svg>',
  marksOnGun: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/></svg>',
  lastPlayed: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v6l4 2"/></svg>'
};

const SORT_DIRECTION_ICONS = {
  descending: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v16M7 15l5 5 5-5"/></svg>',
  ascending: '<svg class="hcc-native-sort-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20V4M7 9l5-5 5 5"/></svg>'
};

let state = { stats: {}, statsConfig: {}, sorting: {}, actionCards: {}, carousel: { rows: 2 }, enabled: false };
let lastStateJson = "";
let lastStatsDiagnostic = "";
let scheduled = false;
let tooltipElement = null;

function setSvgContent(element, svgString) {
  // Safe SVG insertion via DOMParser to prevent innerHTML injection
  const parser = new DOMParser();
  const doc = parser.parseFromString(`<root>${svgString}</root>`, "text/xml");
  if (doc.documentElement.tagName === "parsererror") {
    console.error("Invalid SVG:", svgString);
    return;
  }
  while (element.firstChild) {
    element.removeChild(element.firstChild);
  }
  for (let i = 0; i < doc.documentElement.childNodes.length; i++) {
    const node = doc.documentElement.childNodes[i];
    element.appendChild(document.importNode(node, true));
  }
}

function unwrap(value) {
  if (value && typeof value === "object" && Object.prototype.hasOwnProperty.call(value, "value")) {
    return value.value;
  }
  return value;
}

function labels() {
  return LABELS.en;
}

function findModel() {
  if (!window.subViews) return null;
  for (const id of window.subViews.ids()) {
    const candidate = window.subViews.get(id)?.model?.[MODEL_NAME];
    if (candidate) return candidate;
  }
  return null;
}

function callCommand(commandName, payload) {
  const model = findModel();
  if (!model || typeof model[commandName] !== "function") return false;
  try {
    if (payload === undefined) model[commandName]();
    else model[commandName](payload);
    return true;
  } catch (error) {
    console.error(`[HangarCarouselClassic] ${commandName} failed`, error);
    return false;
  }
}

function scheduleRender() {
  if (scheduled) return;
  scheduled = true;
  requestAnimationFrame(() => {
    scheduled = false;
    applyCarouselRowsClass();
    applyActionCardsVisibility();
    renderNativeFilterPanel();
    renderCardStats();
  });
}

function applyCarouselRowsClass() {
  const rows = Math.max(1, Math.min(4, Number(state.carousel?.rows || 2)));
  for (const root of [document.documentElement, document.body]) {
    if (!root) continue;
    root.classList.remove("hcc-carousel-rows-1", "hcc-carousel-rows-2", "hcc-carousel-rows-3", "hcc-carousel-rows-4");
    root.classList.add(`hcc-carousel-rows-${rows}`);
  }
}

function applyActionCardsVisibility() {
  const classes = {
    hideBuyTank: "hcc-hide-buy-tank",
    hideBuySlot: "hcc-hide-buy-slot",
    hideRestoreTank: "hcc-hide-restore-tank"
  };
  for (const root of [document.documentElement, document.body]) {
    if (!root) continue;
    for (const [key, className] of Object.entries(classes)) {
      root.classList.toggle(className, Boolean(state.actionCards?.[key]));
    }
  }
}

function formatCompact(value) {
  const number = Number(value || 0);
  if (number >= 10000) return `${(number / 1000).toFixed(number >= 100000 ? 0 : 1)}k`;
  return number.toLocaleString();
}

function masteryLabel(value) {
  return value > 0 ? `${labels().stat_mastery} ${value}` : "";
}

function winRateBand(value) {
  const winRate = Number(value || 0);
  if (winRate < 47) return "bad";
  if (winRate < 50) return "below-average";
  if (winRate < 52) return "average";
  if (winRate < 55) return "good";
  if (winRate < 60) return "great";
  return "exceptional";
}

function statRows(stats) {
  const fields = state.statsConfig?.fields || [];
  const rows = [];
  if (fields.includes("battles")) {
    rows.push([{ classes: ["battles"], text: `${labels().stat_battles} ${formatCompact(stats.battles)}` }]);
  }
  if (fields.includes("winRate")) {
    const winRate = Number(stats.winRate || 0);
    rows.push([{
      classes: ["win-rate", `win-rate-${winRateBand(winRate)}`],
      text: `${labels().stat_win_rate} ${winRate.toFixed(1)}%`
    }]);
  }
  if (fields.includes("averageDamage")) {
    rows.push([{ classes: ["damage"], text: `${labels().stat_damage} ${formatCompact(stats.averageDamage)}` }]);
  }
  if (fields.includes("alphaDamage")) {
    rows.push([{ classes: ["alpha-damage"], text: `${labels().stat_alpha_damage} ${formatCompact(stats.alphaDamage)}` }]);
  }
  const achievements = [];
  if (fields.includes("mastery") && stats.mastery) {
    achievements.push({ classes: ["mastery", `mastery-${Number(stats.mastery)}`], text: masteryLabel(stats.mastery) });
  }
  if (fields.includes("marksOnGun") && stats.marksOnGun) {
    achievements.push({ classes: ["marks", `marks-${Number(stats.marksOnGun)}`], text: `${stats.marksOnGun} ${labels().stat_marks}` });
  }
  if (achievements.length) rows.push(achievements);
  return rows.slice(0, 4);
}

function directChildByClass(parent, className) {
  for (const child of parent.children) {
    if (child.classList.contains(className)) return child;
  }
  return null;
}

function renderCardStats() {
  const minimumBattles = Number(state.statsConfig?.minimumBattles ?? 1);
  const cards = Array.from(document.querySelectorAll(`[data-test-id^="${CARD_PREFIX}"]`));
  let matched = 0;
  let visible = 0;
  let sampleText = "";
  cards.forEach((card) => {
    const id = card.getAttribute("data-test-id").slice(CARD_PREFIX.length);
    const stats = state.stats?.[id];
    const nativeContent = card.querySelector('[class*="Card_content_"]');
    const staleOverlay = nativeContent ? directChildByClass(nativeContent, "hcc-card-stats") : null;
    if (staleOverlay) staleOverlay.remove();
    const host = card;
    host.classList.add("hcc-card-stats-host");
    let overlay = directChildByClass(host, "hcc-card-stats");
    if (stats) matched += 1;
    card.removeAttribute("data-hcc-stats");
    if (!stats || Number(stats.battles) < minimumBattles || state.statsConfig?.enabled === false) {
      if (overlay) overlay.remove();
      return;
    }

    if (!overlay) {
      overlay = document.createElement("div");
      overlay.className = "hcc-card-stats";
      overlay.dataset.vehicleId = id;
      host.appendChild(overlay);
    }

    const rows = statRows(stats);
    const signature = JSON.stringify(rows);
    if (overlay.dataset.signature !== signature) {
      overlay.dataset.signature = signature;
      overlay.innerHTML = "";
      rows.forEach((items) => {
        const line = document.createElement("div");
        line.className = "hcc-card-stats-line";
        items.forEach((item) => {
          const value = document.createElement("span");
          value.className = `hcc-card-stat ${item.classes.map((name) => `hcc-card-stat--${name}`).join(" ")}`;
          value.textContent = item.text;
          line.appendChild(value);
        });
        overlay.appendChild(line);
      });
    }
    if (!sampleText) sampleText = `${id}=${overlay.textContent}`;
    visible += 1;
  });

  const diagnostic = `${cards.length}/${matched}/${visible}/${Object.keys(state.stats || {}).length}`;
  if (diagnostic !== lastStatsDiagnostic) {
    lastStatsDiagnostic = diagnostic;
    console.warn(`[HangarCarouselClassic] cards/matched/visible/stats: ${diagnostic}; sample: ${sampleText}`);
  }
}

function hideTooltip() {
  if (!tooltipElement) return;
  tooltipElement.remove();
  tooltipElement = null;
}

function showTooltip(anchor, title, description) {
  hideTooltip();
  const rect = anchor.getBoundingClientRect();
  const tooltip = document.createElement("div");
  tooltip.className = "hcc-hover-tooltip";
  const titleElement = document.createElement("div");
  titleElement.className = "hcc-hover-tooltip-title";
  titleElement.textContent = title;
  tooltip.appendChild(titleElement);
  if (description) {
    const descriptionElement = document.createElement("div");
    descriptionElement.className = "hcc-hover-tooltip-description";
    descriptionElement.textContent = description;
    tooltip.appendChild(descriptionElement);
  }
  tooltip.style.left = `${Math.round(rect.right + 8)}px`;
  tooltip.style.top = `${Math.round(rect.top + rect.height / 2)}px`;
  document.body.appendChild(tooltip);
  tooltipElement = tooltip;
}

function bindTooltip(button, title, description) {
  button.addEventListener("mouseenter", () => showTooltip(button, title, description));
  button.addEventListener("mouseleave", hideTooltip);
  button.addEventListener("click", hideTooltip);
}

function addHeading(parent, text) {
  const heading = document.createElement("div");
  heading.className = "hcc-native-heading";
  heading.textContent = text;
  parent.appendChild(heading);
}

function carouselRowButtonContent(rows) {
  const automatic = Number(rows) === 0;
  const visibleRows = automatic ? 4 : Number(rows);
  const bars = [];
  for (let index = 0; index < visibleRows; index += 1) {
    bars.push(`<rect x="2" y="${2 + index * 4}" width="12" height="2" rx="0.5" style="fill:#fff!important"/>`);
  }
  return `<svg viewBox="0 0 16 18" aria-hidden="true" style="color:#fff!important;fill:#fff!important">${bars.join("")}</svg>` +
    `<span class="hcc-native-row-button-label" style="color:#fff!important">${automatic ? "A" : rows}</span>`;
}

function renderNativeFilterPanel() {
  const popover = document.querySelector('[class*="FilterPopover_popover_"]');
  if (!popover) return;
  const nativeCategories = popover.querySelectorAll('[class*="FilterPopover_category_"]');
  if (!nativeCategories.length) return;
  const nativeContent = nativeCategories[nativeCategories.length - 1].parentElement;
  if (!nativeContent) return;

  let section = popover.querySelector(".hcc-native-section");
  if (!section) {
    section = document.createElement("div");
    section.className = "hcc-native-section";
    nativeContent.appendChild(section);
  }

  const signature = JSON.stringify([state.enabled, state.sorting, state.actionCards, state.carousel]);
  if (section.dataset.signature === signature) return;  // Early exit if no state change
  section.dataset.signature = signature;
  hideTooltip();
  
  // Clear listeners and content by replacing entire section
  const newSection = document.createElement("div");
  newSection.className = "hcc-native-section";
  newSection.dataset.signature = signature;
  
  const refresh = document.createElement("button");
  refresh.type = "button";
  refresh.className = "hcc-native-icon-button";
  refresh.textContent = "↻";
  refresh.title = labels().refresh;
  refresh.setAttribute("aria-label", labels().refresh);
  bindTooltip(refresh, labels().refresh, "");
  newSection.appendChild(refresh);
  refresh.addEventListener("click", () => callCommand("onRefresh"));

  if (state.sorting?.enabled && Array.isArray(state.sorting.options)) {
    addHeading(newSection, labels().sorting);
    const sorting = document.createElement("div");
    sorting.className = "hcc-native-sorting";
    newSection.appendChild(sorting);
    for (const mode of state.sorting.options) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "hcc-native-sort-button";
      if (mode === state.sorting.mode) button.classList.add("hcc-native-sort-button--active");
      setSvgContent(button, SORT_ICONS[mode] || SORT_ICONS.default);
      const title = labels()[`sort_${mode}`] || mode;
      button.setAttribute("aria-label", title);
      button.title = title;
      bindTooltip(button, title, mode === state.sorting.mode
        ? (state.sorting.descending ? labels().descending : labels().ascending)
        : "");
      button.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        callCommand("onSetSorting", { mode, descending: Boolean(state.sorting.descending) });
      });
      sorting.appendChild(button);
    }
    const direction = document.createElement("button");
    direction.type = "button";
    direction.className = "hcc-native-sort-button hcc-native-sort-direction";
    setSvgContent(direction, state.sorting.descending
      ? SORT_DIRECTION_ICONS.descending
      : SORT_DIRECTION_ICONS.ascending);
    direction.title = state.sorting.descending ? labels().descending : labels().ascending;
    bindTooltip(direction, direction.title, labels()[`sort_${state.sorting.mode}`] || state.sorting.mode);
    direction.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      callCommand("onSetSorting", {
        mode: state.sorting.mode || "default",
        descending: !Boolean(state.sorting.descending)
      });
    });
    sorting.appendChild(direction);
  }

  addHeading(newSection, labels().carousel_rows);
  const carouselRows = document.createElement("div");
  carouselRows.className = "hcc-native-carousel-rows";
  newSection.appendChild(carouselRows);
  const automaticRows = state.carousel?.mode === "auto";
  const activeRows = Math.max(1, Math.min(4, Number(state.carousel?.rows || 2)));
  const supportedRows = state.carousel?.supportedRows || [1, 2, 3, 4];
  for (const rows of [0, ...supportedRows]) {
    const automatic = Number(rows) === 0;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "hcc-native-row-button";
    if ((automatic && automaticRows) || (!automatic && !automaticRows && Number(rows) === activeRows)) {
      button.classList.add("hcc-native-row-button--active");
    }
    button.innerHTML = carouselRowButtonContent(rows);
    const buttonTitle = automatic ? labels().carousel_auto : `${labels().carousel_rows}: ${rows}`;
    const buttonDescription = automatic ? labels().carousel_auto_description : labels().carousel_rows_description;
    button.setAttribute("aria-label", buttonTitle);
    button.title = buttonTitle;
    bindTooltip(button, buttonTitle, buttonDescription);
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      callCommand("onSetCarouselRows", { rows: Number(rows) });
    });
    carouselRows.appendChild(button);
  }
  
  // Replace old section with new one (clears all old event listeners)
  section.parentElement.replaceChild(newSection, section);
}

function syncModel() {
  const model = findModel();
  if (!model) return;
  const stateJson = String(unwrap(model.stateJson) || "{}");
  if (stateJson === lastStateJson) return;
  lastStateJson = stateJson;
  try {
    const parsedState = JSON.parse(stateJson);
    // Validate payload structure for compatibility
    if (typeof parsedState !== "object" || !("version" in parsedState)) {
      console.warn("[HangarCarouselClassic] Invalid payload structure; expected versioned object");
      state = { stats: {}, statsConfig: {}, sorting: {}, actionCards: {}, carousel: { rows: 2 }, enabled: false };
      return;
    }
    state = parsedState;
  } catch (error) {
    console.error("[HangarCarouselClassic] Invalid state JSON", error);
    state = { stats: {}, statsConfig: {}, sorting: {}, actionCards: {}, carousel: { rows: 2 }, enabled: false };
  }
  scheduleRender();
}

engine.whenReady.then(() => {
  const observer = new MutationObserver(scheduleRender);
  observer.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["data-test-id"]
  });
  window.engine.on("subViews.onAdded", syncModel);
  // Sync model every 1 second (matches Python refresh rate)
  window.setInterval(syncModel, 1000);
  // Vehicle cards can be mounted after the model state stops changing.
  window.setInterval(scheduleRender, 1000);
  syncModel();
  scheduleRender();
});

