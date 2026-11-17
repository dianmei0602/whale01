import chronicles from "./data.js";

const dataset = chronicles;
const dynastiesById = new Map(dataset.dynasties.map((item) => [item.id, item]));
const eventsById = new Map(dataset.events.map((item) => [item.id, item]));
const sourcesById = new Map(dataset.sources.map((item) => [item.id, item]));

const views = new Set(["river", "catalog", "atlas", "search"]);
const preferredYears = {
  "pre-qin": -551,
  "qin-han": 105,
  "wei-jin-nanbei": 317,
  "sui-tang": 755,
  "five-dynasties-song": 1127,
  "yuan-ming-qing": 1368
};

const appScreen = document.querySelector(".device-screen");
const appHeader = document.querySelector("#app-header");
const appContent = document.querySelector("#app-content");
const appTabs = document.querySelector("#app-tabs");
const appToast = document.querySelector("#app-toast");
const routeReadout = document.querySelector("#route-readout");
const contentVersion = document.querySelector("#content-version");
const parameters = new URLSearchParams(location.search);

const storedTheme = localStorage.getItem("chinese-chronicles-demo-theme");
const state = {
  eraId: "five-dynasties-song",
  year: 1127,
  query: "",
  lastView: "river",
  theme: storedTheme === "night" ? "night" : "light"
};

if (dataset.eras.some((era) => era.id === parameters.get("era"))) {
  state.eraId = parameters.get("era");
}
if (Number.isFinite(Number(parameters.get("year"))) && parameters.has("year")) {
  state.year = Number(parameters.get("year"));
}
if (["light", "night"].includes(parameters.get("theme"))) {
  state.theme = parameters.get("theme");
}

let toastTimer = 0;

contentVersion.textContent = dataset.contentVersion;
appScreen.dataset.theme = state.theme;
if (!location.hash) history.replaceState(null, "", "#/river");

function escapeHTML(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatYear(year) {
  return year < 0 ? `前 ${Math.abs(year)}` : `${year}`;
}

function parseRoute() {
  const value = location.hash.replace(/^#\/?/, "");
  const [name, id] = value.split("/");

  if ((name === "dynasty" || name === "event") && id) {
    return { kind: "detail", detailType: name, id: decodeURIComponent(id) };
  }

  return { kind: "view", name: views.has(name) ? name : "river" };
}

function primaryView(route = parseRoute()) {
  return route.kind === "detail" ? state.lastView : route.name;
}

function eraForID(id) {
  return dataset.eras.find((item) => item.id === id) ?? dataset.eras[0];
}

function eraDynasties(eraId) {
  return dataset.dynasties
    .filter((item) => item.eraId === eraId)
    .sort((a, b) => a.startYear - b.startYear || a.endYear - b.endYear);
}

function eraEvents(eraId) {
  const dynastyIDs = new Set(eraDynasties(eraId).map((item) => item.id));
  return dataset.events
    .filter((item) => dynastyIDs.has(item.dynastyId))
    .sort((a, b) => a.date.year - b.date.year || a.title.localeCompare(b.title, "zh-CN"));
}

function activeDynasties(eraId, year) {
  return eraDynasties(eraId).filter(
    (item) => item.startYear <= year && year <= item.endYear
  );
}

function roleLabel(role) {
  return {
    mainline: "主线王朝",
    divided: "分裂时期",
    parallel: "并立政权",
    disputed: "纪年有争议"
  }[role] ?? "政权";
}

function dynastyPeriod(dynasty) {
  return `${dynasty.startLabel} — ${dynasty.endLabel}`;
}

function normalizeYear(era, year) {
  return Math.min(Math.max(year, era.startYear), era.endYear);
}

function timelinePosition(era, year) {
  const span = Math.max(era.endYear - era.startYear, 1);
  return ((year - era.startYear) / span) * 100;
}

function timelineTicks(era) {
  return [0, 1, 2, 3].map((index) =>
    Math.round(era.startYear + ((era.endYear - era.startYear) * index) / 3)
  );
}

function uniqueEventsOfDynasty(dynastyID) {
  return dataset.events
    .filter((item) => item.dynastyId === dynastyID)
    .sort((a, b) => a.date.year - b.date.year);
}

function sourcesFor(ids) {
  return ids.map((id) => sourcesById.get(id)).filter(Boolean);
}

function timelineMarkup(era, year, ariaLabel) {
  const dynasties = eraDynasties(era.id);
  const ticks = timelineTicks(era);
  const markerPosition = timelinePosition(era, year);

  return `
    <div class="timeline-axis" aria-hidden="true">
      <span></span>
      <div>${ticks.map((tick) => `<span>${formatYear(tick)}</span>`).join("")}</div>
    </div>
    <div class="timeline-rows" aria-label="${escapeHTML(ariaLabel)}">
      ${dynasties.map((dynasty) => {
        const left = timelinePosition(era, dynasty.startYear);
        const width = Math.max(
          timelinePosition(era, dynasty.endYear) - left,
          2.4
        );
        const selected = dynasty.startYear <= year && year <= dynasty.endYear;
        return `
          <button
            type="button"
            class="timeline-row"
            data-action="open-dynasty"
            data-id="${escapeHTML(dynasty.id)}"
            aria-label="${escapeHTML(`${dynasty.name}，${dynastyPeriod(dynasty)}`)}"
          >
            <span>${escapeHTML(dynasty.name)}</span>
            <span class="timeline-track">
              <span
                class="timeline-bar${selected ? " is-selected" : ""}"
                style="--left:${left.toFixed(2)}%;--width:${width.toFixed(2)}%"
              ></span>
            </span>
          </button>
        `;
      }).join("")}
      <span class="timeline-current-rail" aria-hidden="true">
        <span
          class="timeline-current"
          id="${markerID(ariaLabel)}"
          style="--year-pos:${markerPosition.toFixed(3)}%"
        ></span>
      </span>
    </div>
  `;
}

function markerID(label) {
  return label.includes("atlas") ? "atlas-year-marker" : "river-year-marker";
}

function eraSelector() {
  return `
    <div class="era-scroll" role="tablist" aria-label="历史时代">
      ${dataset.eras.map((era) => `
        <button
          type="button"
          class="era-chip"
          role="tab"
          aria-selected="${era.id === state.eraId}"
          data-action="select-era"
          data-id="${escapeHTML(era.id)}"
        >${escapeHTML(era.title)}</button>
      `).join("")}
    </div>
  `;
}

function activePolityTokens(era, year) {
  const active = activeDynasties(era.id, year);
  if (!active.length) {
    return `<span class="polity-empty">这一年，当前资料范围内没有可确认的政权条目。</span>`;
  }

  return active.map((dynasty) => `
    <button
      type="button"
      class="polity-token"
      data-action="open-dynasty"
      data-id="${escapeHTML(dynasty.id)}"
    >${escapeHTML(dynasty.name)}</button>
  `).join("");
}

function eventRows(events) {
  return events.map((event) => {
    const dynasty = dynastiesById.get(event.dynastyId);
    return `
      <button
        type="button"
        class="event-row"
        data-action="open-event"
        data-id="${escapeHTML(event.id)}"
      >
        <span class="event-date">${escapeHTML(event.date.display)}</span>
        <span class="event-copy">
          <strong>${escapeHTML(event.title)}</strong>
          <span>${escapeHTML(dynasty?.name ?? "政权待核")} · ${escapeHTML(event.summary)}</span>
        </span>
        <span class="row-arrow" aria-hidden="true">›</span>
      </button>
    `;
  }).join("");
}

function nearestEvents(era, year, limit = 3) {
  return eraEvents(era.id)
    .slice()
    .sort((a, b) => Math.abs(a.date.year - year) - Math.abs(b.date.year - year))
    .slice(0, limit)
    .sort((a, b) => a.date.year - b.date.year);
}

function renderRiver() {
  const era = eraForID(state.eraId);
  state.year = normalizeYear(era, state.year);
  const active = activeDynasties(era.id, state.year);
  const events = nearestEvents(era, state.year, 4);
  const selectedNames = active.map((item) => item.name).join("、");

  return `
    <section class="screen">
      <h1 class="screen-title">看见同时存在的政权</h1>
      <p class="screen-subtitle">沿着时间移动，比较同一时期真正并立的王朝、列国与政权。</p>
      ${eraSelector()}

      <div class="year-question">
        <span id="river-status">${escapeHTML(era.title)} · ${active.length ? `此时有 ${active.length} 个政权` : "资料范围"}</span>
        <strong id="river-year">${formatYear(state.year)}</strong>
      </div>

      <article class="timeline-card">
        <div class="timeline-card-head">
          <p>${escapeHTML(era.range)}</p>
          <h2 id="river-polity-heading">${escapeHTML(selectedNames || era.title)}</h2>
        </div>
        ${timelineMarkup(era, state.year, "river timeline")}
        <div class="year-slider-wrap">
          <label for="river-year-range">
            <span>${escapeHTML(dynastiesById.get(eraDynasties(era.id)[0]?.id)?.startLabel ?? "")}</span>
            <span>${escapeHTML(eraDynasties(era.id).at(-1)?.endLabel ?? "")}</span>
          </label>
          <input
            id="river-year-range"
            type="range"
            min="${era.startYear}"
            max="${era.endYear}"
            value="${state.year}"
            step="1"
            aria-label="选择年代"
          >
        </div>
      </article>

      <div class="active-polities" id="river-active-polities">
        ${activePolityTokens(era, state.year)}
      </div>

      <div class="section-heading">
        <h2>附近事件</h2>
        <span id="river-event-count">${events.length} 条</span>
      </div>
      <div class="event-list" id="river-event-list">
        ${eventRows(events)}
      </div>
    </section>
  `;
}

function renderCatalog() {
  return `
    <section class="screen">
      <h1 class="screen-title">卷目</h1>
      <p class="screen-subtitle">从时代进入王朝。每个条目保留起止年、政权关系与可追溯出处。</p>

      <div class="catalog-list">
        ${dataset.eras.map((era, index) => {
          const dynasties = eraDynasties(era.id);
          return `
            <details class="catalog-era" ${index < 2 ? "open" : ""}>
              <summary>
                <span>
                  <strong>${escapeHTML(era.title)}</strong>
                  <span>${escapeHTML(era.range)} · ${dynasties.length} 个条目</span>
                </span>
              </summary>
              <div class="dynasty-list">
                ${dynasties.map((dynasty) => `
                  <button
                    type="button"
                    class="dynasty-row"
                    data-action="open-dynasty"
                    data-id="${escapeHTML(dynasty.id)}"
                  >
                    <span class="dynasty-dot" style="--row-color:${escapeHTML(dynasty.accent)}"></span>
                    <span class="dynasty-copy">
                      <strong>${escapeHTML(dynasty.name)} · ${escapeHTML(dynasty.subtitle)}</strong>
                      <span>${escapeHTML(dynastyPeriod(dynasty))} · ${escapeHTML(roleLabel(dynasty.role))}</span>
                    </span>
                    <span class="row-arrow" aria-hidden="true">›</span>
                  </button>
                `).join("")}
              </div>
            </details>
          `;
        }).join("")}
      </div>
    </section>
  `;
}

function renderAtlas() {
  const era = eraForID(state.eraId);
  state.year = normalizeYear(era, state.year);
  const events = nearestEvents(era, state.year, 3);
  const active = activeDynasties(era.id, state.year);
  const position = timelinePosition(era, state.year);

  return `
    <section class="screen">
      <h1 class="screen-title">并立</h1>
      <p class="screen-subtitle">同一条年代尺穿过所有政权。这里首先回答“谁和谁同时存在”，再进入各自卷页。</p>
      ${eraSelector()}

      <div class="atlas-intro">
        <div class="atlas-control">
          <button type="button" class="year-step" data-action="step-year" data-delta="-25" aria-label="向前二十五年">−25</button>
          <strong class="atlas-year-value" id="atlas-year">${formatYear(state.year)}</strong>
          <button type="button" class="year-step" data-action="step-year" data-delta="25" aria-label="向后二十五年">+25</button>
        </div>
        <input
          id="atlas-year-range"
          type="range"
          min="${era.startYear}"
          max="${era.endYear}"
          value="${state.year}"
          step="1"
          aria-label="移动并立年代"
        >
      </div>

      <div class="atlas-matrix">
        ${eraDynasties(era.id).map((dynasty) => {
          const left = timelinePosition(era, dynasty.startYear);
          const width = Math.max(timelinePosition(era, dynasty.endYear) - left, 2.4);
          const selected = dynasty.startYear <= state.year && state.year <= dynasty.endYear;
          return `
            <button
              type="button"
              class="atlas-matrix-row${selected ? " is-current" : ""}"
              data-action="open-dynasty"
              data-id="${escapeHTML(dynasty.id)}"
            >
              <strong>${escapeHTML(dynasty.name)}</strong>
              <span class="atlas-track" style="--year-pos:${position.toFixed(3)}%">
                <i style="--left:${left.toFixed(2)}%;--width:${width.toFixed(2)}%"></i>
              </span>
              <span>${selected ? "在此年" : formatYear(dynasty.startYear)}</span>
            </button>
          `;
        }).join("")}
      </div>

      <div class="section-heading">
        <h2>此时政权</h2>
        <span id="atlas-active-count">${active.length} 个</span>
      </div>
      <div class="active-polities" id="atlas-active-polities">
        ${activePolityTokens(era, state.year)}
      </div>

      <div class="section-heading">
        <h2>同年附近</h2>
        <span>按时间排序</span>
      </div>
      <div class="event-list" id="atlas-event-list">
        ${eventRows(events)}
      </div>
    </section>
  `;
}

function renderSearch() {
  return `
    <section class="screen search-screen">
      <h1 class="screen-title">索引</h1>
      <p class="screen-subtitle">只在随 App 打包的本地资料中检索，不把模型猜测混入史实。</p>

      <div class="search-box">
        <input
          id="search-input"
          type="search"
          value="${escapeHTML(state.query)}"
          placeholder="朝代、人物、都城或事件"
          autocomplete="off"
          aria-label="搜索本地编年史"
        >
        <button type="button" class="search-clear" data-action="clear-search" aria-label="清空搜索">清除</button>
      </div>

      <div class="search-suggestions" id="search-suggestions">
        ${["秦", "洛阳", "靖康", "统一", "丝绸之路"].map((query) => `
          <button type="button" class="search-suggestion" data-action="quick-search" data-query="${escapeHTML(query)}">
            ${escapeHTML(query)}
          </button>
        `).join("")}
      </div>

      <div id="search-results"></div>
    </section>
  `;
}

function searchResults(query) {
  const needle = query.trim().toLocaleLowerCase("zh-CN");
  if (!needle) return { dynasties: [], events: [] };

  const dynasties = dataset.dynasties.filter((dynasty) => {
    const text = [
      dynasty.name,
      dynasty.subtitle,
      dynasty.founder,
      dynasty.capital,
      dynasty.summary,
      ...dynasty.aliases
    ].join(" ");
    return text.toLocaleLowerCase("zh-CN").includes(needle);
  });

  const events = dataset.events.filter((event) => {
    const text = [
      event.title,
      event.summary,
      event.date.display,
      ...event.tags
    ].join(" ");
    return text.toLocaleLowerCase("zh-CN").includes(needle);
  });

  return {
    dynasties,
    events: events.sort((a, b) => a.date.year - b.date.year)
  };
}

function renderSearchResults() {
  const container = document.querySelector("#search-results");
  if (!container) return;

  const query = state.query.trim();
  if (!query) {
    container.innerHTML = `
      <div class="empty-state is-search-empty">
        <h2>从一个名字开始</h2>
        <p>可搜索的内容包括政权名、别名、建立者、都城、事件标题和摘要。</p>
      </div>
    `;
    return;
  }

  const results = searchResults(query);
  if (!results.dynasties.length && !results.events.length) {
    container.innerHTML = `
      <div class="empty-state is-search-empty">
        <h2>本机资料中暂无“${escapeHTML(query)}”</h2>
        <p>当前版本只收录经过整理的 23 个政权条目和 34 个事件。</p>
      </div>
    `;
    return;
  }

  const dynastyMarkup = results.dynasties.length
    ? `
      <p class="search-result-label">政权 ${results.dynasties.length}</p>
      <div class="dynasty-list">
        ${results.dynasties.map((dynasty) => `
          <button
            type="button"
            class="dynasty-row"
            data-action="open-dynasty"
            data-id="${escapeHTML(dynasty.id)}"
          >
            <span class="dynasty-dot" style="--row-color:${escapeHTML(dynasty.accent)}"></span>
            <span class="dynasty-copy">
              <strong>${escapeHTML(dynasty.name)}</strong>
              <span>${escapeHTML(dynastyPeriod(dynasty))} · ${escapeHTML(dynasty.subtitle)}</span>
            </span>
            <span class="row-arrow" aria-hidden="true">›</span>
          </button>
        `).join("")}
      </div>
    `
    : "";

  const eventMarkup = results.events.length
    ? `
      <p class="search-result-label">事件 ${results.events.length}</p>
      <div class="event-list">
        ${eventRows(results.events)}
      </div>
    `
    : "";

  container.innerHTML = dynastyMarkup + eventMarkup;
}

function sourceMarkup(ids) {
  return sourcesFor(ids).map((source) => `
    <article class="source-card">
      <strong>${escapeHTML(source.title)}</strong>
      <span>${escapeHTML(source.author)} · ${escapeHTML(source.citation)}</span>
      <p>${escapeHTML(source.note)}</p>
    </article>
  `).join("");
}

function renderDynastyDetail(dynasty) {
  const events = uniqueEventsOfDynasty(dynasty.id);
  return `
    <section class="screen detail-page">
      <p class="detail-period">${escapeHTML(dynastyPeriod(dynasty))}</p>
      <h1 class="detail-title">${escapeHTML(dynasty.name)}</h1>
      <p class="detail-subtitle">${escapeHTML(dynasty.subtitle)}</p>
      <div class="detail-meta">
        <span>${escapeHTML(roleLabel(dynasty.role))}</span>
        <span>${events.length} 个事件</span>
      </div>

      <div class="detail-separator"></div>
      <p class="detail-lede">${escapeHTML(dynasty.summary)}</p>

      <dl class="detail-facts">
        <div><dt>建立者</dt><dd>${escapeHTML(dynasty.founder)}</dd></div>
        <div><dt>都城</dt><dd>${escapeHTML(dynasty.capital)}</dd></div>
        <div><dt>又称</dt><dd>${escapeHTML(dynasty.aliases.join("、") || "暂无别名")}</dd></div>
      </dl>

      <div class="section-heading">
        <h2>编年摘记</h2>
        <span>${events.length} 条</span>
      </div>
      ${events.length ? `<div class="event-list">${eventRows(events)}</div>` : `
        <div class="empty-state">
          <p>本版尚未为该条目录入单独事件。</p>
        </div>
      `}

      <div class="section-heading">
        <h2>资料出处</h2>
        <span>可追溯</span>
      </div>
      <div class="source-list">${sourceMarkup(dynasty.sourceIds)}</div>
    </section>
  `;
}

function renderEventDetail(event) {
  const dynasty = dynastiesById.get(event.dynastyId);
  return `
    <section class="screen detail-page">
      <p class="detail-period">${escapeHTML(event.date.display)} · ${escapeHTML(event.date.precision === "approximate" ? "约数" : event.date.precision === "disputed" ? "存在异说" : "通行纪年")}</p>
      <h1 class="detail-title">${escapeHTML(event.title)}</h1>
      ${dynasty ? `<p class="detail-subtitle">${escapeHTML(dynasty.name)} · ${escapeHTML(dynastyPeriod(dynasty))}</p>` : ""}
      <div class="detail-meta">
        ${event.tags.map((tag) => `<span>${escapeHTML(tag)}</span>`).join("")}
      </div>

      <div class="detail-separator"></div>
      <p class="detail-body">${escapeHTML(event.summary)}</p>

      ${event.caveat ? `
        <div class="detail-caveat">
          <strong>阅读提示</strong>
          <p>${escapeHTML(event.caveat)}</p>
        </div>
      ` : ""}

      ${dynasty ? `
        <button type="button" class="text-link" data-action="open-dynasty" data-id="${escapeHTML(dynasty.id)}">
          查看所在政权：${escapeHTML(dynasty.name)} ›
        </button>
      ` : ""}

      <div class="section-heading">
        <h2>这页的依据</h2>
        <span>可追溯</span>
      </div>
      <div class="source-list">${sourceMarkup(event.sourceIds)}</div>
    </section>
  `;
}

function renderHeader(route) {
  const themeLabel = state.theme === "night" ? "日读" : "夜读";

  if (route.kind === "detail") {
    appHeader.innerHTML = `
      <button type="button" class="back-button" data-action="back">返回</button>
      <p class="header-title">${route.detailType === "dynasty" ? "政权" : "事件"}</p>
      <button type="button" class="header-action" data-action="toggle-theme">${themeLabel}</button>
    `;
    return;
  }

  const titles = {
    river: "长河",
    catalog: "卷目",
    atlas: "并立",
    search: "索引"
  };

  appHeader.innerHTML = `
    <button type="button" class="brand-button" data-action="top">
      <span class="brand-seal" aria-hidden="true">华</span>
      <span>华章</span>
    </button>
    <p class="header-title">${titles[route.name]}</p>
    <button type="button" class="header-action" data-action="toggle-theme">${themeLabel}</button>
  `;
}

function render() {
  const route = parseRoute();
  renderHeader(route);

  if (route.kind === "detail") {
    appScreen.classList.add("is-detail");
    if (route.detailType === "dynasty") {
      const dynasty = dynastiesById.get(route.id);
      appContent.innerHTML = dynasty
        ? renderDynastyDetail(dynasty)
        : renderMissingDetail("没有找到这个政权");
    } else {
      const event = eventsById.get(route.id);
      appContent.innerHTML = event
        ? renderEventDetail(event)
        : renderMissingDetail("没有找到这个事件");
    }
  } else {
    appScreen.classList.remove("is-detail");
    const renderers = {
      river: renderRiver,
      catalog: renderCatalog,
      atlas: renderAtlas,
      search: renderSearch
    };
    appContent.innerHTML = renderers[route.name]();
    if (route.name === "search") renderSearchResults();
  }

  const activeView = primaryView(route);
  appTabs.querySelectorAll("a").forEach((link) => {
    const active = link.dataset.view === activeView;
    link.classList.toggle("is-active", active);
    if (active) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  });

  routeReadout.textContent = {
    river: "长河",
    catalog: "卷目",
    atlas: "并立",
    search: "索引"
  }[activeView];

  appContent.scrollTop = 0;
}

function renderMissingDetail(message) {
  return `
    <section class="screen">
      <div class="empty-state">
        <h1 class="screen-title">${escapeHTML(message)}</h1>
        <p>返回上一页，或从索引重新查找。</p>
        <button type="button" class="text-link" data-action="back">返回</button>
      </div>
    </section>
  `;
}

function changeEra(eraID) {
  const era = eraForID(eraID);
  state.eraId = era.id;
  state.year = preferredYears[era.id] ?? Math.round((era.startYear + era.endYear) / 2);
  render();
}

function updateRiverYear(year) {
  const era = eraForID(state.eraId);
  state.year = normalizeYear(era, year);
  const position = timelinePosition(era, state.year);
  const yearLabel = document.querySelector("#river-year");
  const marker = document.querySelector("#river-year-marker");
  const activeContainer = document.querySelector("#river-active-polities");
  const statusLabel = document.querySelector("#river-status");
  const polityHeading = document.querySelector("#river-polity-heading");
  const eventList = document.querySelector("#river-event-list");
  const eventCount = document.querySelector("#river-event-count");
  const active = activeDynasties(era.id, state.year);
  const events = nearestEvents(era, state.year, 4);

  if (yearLabel) yearLabel.textContent = formatYear(state.year);
  if (marker) marker.style.setProperty("--year-pos", `${position}%`);
  if (activeContainer) activeContainer.innerHTML = activePolityTokens(era, state.year);
  if (statusLabel) {
    statusLabel.textContent = `${era.title} · ${active.length ? `此时有 ${active.length} 个政权` : "资料范围"}`;
  }
  if (polityHeading) {
    polityHeading.textContent = active.map((item) => item.name).join("、") || era.title;
  }
  if (eventList) eventList.innerHTML = eventRows(events);
  if (eventCount) eventCount.textContent = `${events.length} 条`;

  document.querySelectorAll(".timeline-row").forEach((row) => {
    const dynasty = dynastiesById.get(row.dataset.id);
    const selected = dynasty && dynasty.startYear <= state.year && state.year <= dynasty.endYear;
    row.querySelector(".timeline-bar")?.classList.toggle("is-selected", Boolean(selected));
  });
}

function updateAtlasYear(year) {
  const era = eraForID(state.eraId);
  state.year = normalizeYear(era, year);
  const position = timelinePosition(era, state.year);
  const yearLabel = document.querySelector("#atlas-year");
  const activeContainer = document.querySelector("#atlas-active-polities");
  const activeCount = document.querySelector("#atlas-active-count");
  const eventList = document.querySelector("#atlas-event-list");
  const active = activeDynasties(era.id, state.year);

  if (yearLabel) yearLabel.textContent = formatYear(state.year);
  if (activeContainer) activeContainer.innerHTML = activePolityTokens(era, state.year);
  if (activeCount) activeCount.textContent = `${active.length} 个`;
  if (eventList) eventList.innerHTML = eventRows(nearestEvents(era, state.year, 3));

  document.querySelectorAll(".atlas-matrix-row").forEach((row) => {
    const dynasty = dynastiesById.get(row.dataset.id);
    const selected = dynasty && dynasty.startYear <= state.year && state.year <= dynasty.endYear;
    row.classList.toggle("is-current", Boolean(selected));
    const track = row.querySelector(".atlas-track");
    if (track) track.style.setProperty("--year-pos", `${position}%`);
    const value = row.lastElementChild;
    if (value) value.textContent = selected ? "在此年" : formatYear(dynasty?.startYear ?? state.year);
  });
}

function openDetail(type, id) {
  const route = parseRoute();
  state.lastView = primaryView(route);
  location.hash = `#/${type}/${encodeURIComponent(id)}`;
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  appToast.textContent = message;
  appToast.classList.add("is-visible");
  toastTimer = window.setTimeout(() => {
    appToast.classList.remove("is-visible");
  }, 1800);
}

document.addEventListener("click", (event) => {
  const target = event.target.closest("[data-action]");
  if (!target) return;

  const action = target.dataset.action;

  if (action === "open-dynasty" || action === "open-event") {
    openDetail(action === "open-dynasty" ? "dynasty" : "event", target.dataset.id);
  } else if (action === "select-era") {
    changeEra(target.dataset.id);
  } else if (action === "quick-search") {
    state.query = target.dataset.query ?? "";
    if (parseRoute().name !== "search") {
      location.hash = "#/search";
    } else {
      const input = document.querySelector("#search-input");
      if (input) input.value = state.query;
      renderSearchResults();
    }
  } else if (action === "clear-search") {
    state.query = "";
    const input = document.querySelector("#search-input");
    if (input) {
      input.value = "";
      input.focus();
    }
    renderSearchResults();
  } else if (action === "step-year") {
    const next = state.year + Number(target.dataset.delta ?? 0);
    if (parseRoute().name === "atlas") {
      updateAtlasYear(next);
      const input = document.querySelector("#atlas-year-range");
      if (input) input.value = String(state.year);
    } else {
      updateRiverYear(next);
      const input = document.querySelector("#river-year-range");
      if (input) input.value = String(state.year);
    }
  } else if (action === "toggle-theme") {
    state.theme = state.theme === "night" ? "light" : "night";
    appScreen.dataset.theme = state.theme;
    localStorage.setItem("chinese-chronicles-demo-theme", state.theme);
    renderHeader(parseRoute());
    showToast(state.theme === "night" ? "已切换到夜读" : "已切换到日读");
  } else if (action === "back") {
    location.hash = `#/${state.lastView}`;
  } else if (action === "top") {
    appContent.scrollTo({ top: 0, behavior: "smooth" });
  }
});

document.addEventListener("input", (event) => {
  if (event.target.id === "river-year-range") {
    updateRiverYear(Number(event.target.value));
  } else if (event.target.id === "atlas-year-range") {
    updateAtlasYear(Number(event.target.value));
  } else if (event.target.id === "search-input") {
    state.query = event.target.value;
    renderSearchResults();
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key === "/" && !["INPUT", "TEXTAREA"].includes(document.activeElement?.tagName)) {
    event.preventDefault();
    location.hash = "#/search";
    window.setTimeout(() => document.querySelector("#search-input")?.focus(), 0);
  }

  if (event.key === "Escape" && parseRoute().kind === "detail") {
    location.hash = `#/${state.lastView}`;
  }
});

window.addEventListener("hashchange", render);

render();
