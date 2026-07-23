(() => {
  "use strict";

  const TILE_SELECTOR_GROUPS = [
    ".slider-item",
    '[data-uia="title-card-container"]',
    ".title-card-container",
    ".title-card",
    [
      'a[data-uia="standard-card"]',
      'a[data-uia="progress-card"]',
      'a[data-uia="ranked-card"]',
      'a[data-uia="cloud-game-card"]',
    ].join(","),
  ];
  const ACTION_SCOPE_SELECTORS = [
    '[role="dialog"]',
    ".previewModal--container",
    '[data-uia="preview-modal-container"]',
    ".bob-card",
    ".bob-container",
  ];
  const ACTION_SELECTORS = [
    "button:not([disabled])",
    'a[href]',
    '[role="button"]:not([aria-disabled="true"])',
    '[tabindex]:not([tabindex="-1"])',
  ].join(",");
  const DIRECTIONS = new Map([
    ["ArrowUp", "up"],
    ["ArrowDown", "down"],
    ["ArrowLeft", "left"],
    ["ArrowRight", "right"],
  ]);
  const PAGE_DIRECTIONS = new Map([
    ["PageUp", "up"],
    ["PageDown", "down"],
  ]);

  let mode = "tiles";
  let currentTile = null;
  let currentTileKey = "";
  let currentAction = null;

  function setTileMode(enabled) {
    mode = enabled ? "tiles" : "actions";
    document.documentElement.setAttribute("data-hearth-tile-mode", String(enabled));
  }

  function isRendered(element, minimumSize = 24) {
    if (!(element instanceof HTMLElement) || element.closest('[aria-hidden="true"]')) {
      return false;
    }
    const style = getComputedStyle(element);
    if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) {
      return false;
    }
    const rect = element.getBoundingClientRect();
    return rect.width >= minimumSize && rect.height >= minimumSize;
  }

  function center(element) {
    const rect = element.getBoundingClientRect();
    return {
      x: rect.left + rect.width / 2,
      y: rect.top + rect.height / 2,
      width: rect.width,
      height: rect.height,
    };
  }

  function tileKey(tile) {
    const link = tile.matches("a[href]") ? tile : tile.querySelector("a[href]");
    return link?.href || tile.getAttribute("data-uia") || tile.getAttribute("aria-label") || "";
  }

  function titleTiles() {
    for (const selector of TILE_SELECTOR_GROUPS) {
      const matches = [...document.querySelectorAll(selector)].filter((element) => isRendered(element));
      if (matches.length > 1) {
        return matches;
      }
    }
    return [];
  }

  function preferredInitialTile(tiles) {
    const targetY = window.innerHeight * 0.45;
    const visible = tiles
      .map((tile) => ({ tile, point: center(tile) }))
      .filter(({ point }) => (
        point.x > 0 && point.x < window.innerWidth &&
        point.y > 0 && point.y < window.innerHeight
      ));
    const pool = visible.length ? visible : tiles.map((tile) => ({ tile, point: center(tile) }));
    const nearestRowY = pool.reduce((nearest, entry) => {
      const distance = Math.abs(entry.point.y - targetY);
      return !nearest || distance < nearest.distance ? { y: entry.point.y, distance } : nearest;
    }, null)?.y;
    const row = pool.filter(({ point }) => Math.abs(point.y - nearestRowY) <= Math.max(40, point.height * 0.6));
    return row.reduce((leftmost, entry) => (
      !leftmost || entry.point.x < leftmost.point.x ? entry : leftmost
    ), null)?.tile || null;
  }

  function leaveTile(tile) {
    if (!tile) {
      return;
    }
    tile.removeAttribute("data-hearth-tile-focus");
    tile.dispatchEvent(new MouseEvent("mouseout", { bubbles: true, view: window }));
    tile.dispatchEvent(new MouseEvent("mouseleave", { bubbles: false, view: window }));
  }

  function hoverTile(tile) {
    tile.dispatchEvent(new MouseEvent("mouseover", { bubbles: true, view: window }));
    tile.dispatchEvent(new MouseEvent("mouseenter", { bubbles: false, view: window }));
  }

  function focusTile(tile) {
    if (!tile) {
      return;
    }
    if (currentTile !== tile) {
      leaveTile(currentTile);
    }
    currentTile = tile;
    currentTileKey = tileKey(tile);
    tile.setAttribute("data-hearth-tile-focus", "true");
    if (!tile.hasAttribute("tabindex")) {
      tile.setAttribute("tabindex", "-1");
    }
    if (document.activeElement instanceof HTMLElement) {
      document.activeElement.blur();
    }
    tile.scrollIntoView({ behavior: "smooth", block: "center", inline: "nearest" });
  }

  function restoreCurrentTile(tiles) {
    if (currentTile?.isConnected && tiles.includes(currentTile)) {
      return currentTile;
    }
    if (currentTileKey) {
      const replacement = tiles.find((tile) => tileKey(tile) === currentTileKey);
      if (replacement) {
        focusTile(replacement);
        return replacement;
      }
    }
    const initial = preferredInitialTile(tiles);
    focusTile(initial);
    return initial;
  }

  function directionalCandidate(origin, candidates, direction) {
    const from = center(origin);
    const directional = candidates
      .filter((candidate) => candidate !== origin)
      .map((candidate) => ({ candidate, point: center(candidate) }))
      .filter(({ point }) => {
        if (direction === "left") return point.x < from.x - 8;
        if (direction === "right") return point.x > from.x + 8;
        if (direction === "up") return point.y < from.y - 8;
        return point.y > from.y + 8;
      });
    if (!directional.length) {
      return null;
    }

    const horizontal = direction === "left" || direction === "right";
    const aligned = directional.filter(({ point }) => {
      const secondary = horizontal ? Math.abs(point.y - from.y) : Math.abs(point.x - from.x);
      const tolerance = horizontal
        ? Math.max(from.height, point.height) * 0.8
        : Math.max(from.width, point.width) * 1.25;
      return secondary <= tolerance;
    });
    const pool = aligned.length ? aligned : directional;
    return pool.reduce((best, entry) => {
      const primary = horizontal ? Math.abs(entry.point.x - from.x) : Math.abs(entry.point.y - from.y);
      const secondary = horizontal ? Math.abs(entry.point.y - from.y) : Math.abs(entry.point.x - from.x);
      const score = primary + secondary * (horizontal ? 4 : 2.5);
      return !best || score < best.score ? { candidate: entry.candidate, score } : best;
    }, null)?.candidate || null;
  }

  function visibleActionScope() {
    for (const selector of ACTION_SCOPE_SELECTORS) {
      const scopes = [...document.querySelectorAll(selector)].filter((element) => isRendered(element, 8));
      if (scopes.length) {
        return scopes.at(-1);
      }
    }
    return currentTile?.isConnected ? currentTile : null;
  }

  function actions() {
    const scope = visibleActionScope();
    if (!scope) {
      return [];
    }
    const candidates = [...scope.querySelectorAll(ACTION_SELECTORS)].filter((element) => isRendered(element, 8));
    return candidates.filter((candidate, index) => !candidates.some(
      (other, otherIndex) => otherIndex < index && other.contains(candidate),
    ));
  }

  function clearAction() {
    currentAction?.removeAttribute("data-hearth-action-focus");
    currentAction = null;
  }

  function focusAction(action) {
    if (!action) {
      return;
    }
    clearAction();
    currentAction = action;
    action.setAttribute("data-hearth-action-focus", "true");
    action.focus({ preventScroll: true });
    action.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
  }

  function refreshActionFocus() {
    const available = actions();
    if (currentAction?.isConnected && available.includes(currentAction)) {
      return currentAction;
    }
    const preferred = available.find((action) => /play|watch/i.test(
      action.getAttribute("aria-label") || action.getAttribute("title") || action.textContent || "",
    ));
    focusAction(preferred || available[0] || null);
    return currentAction;
  }

  function enterActionMode() {
    if (!currentTile) {
      return;
    }
    setTileMode(false);
    hoverTile(currentTile);
    refreshActionFocus();
    for (const delay of [250, 650, 1100]) {
      setTimeout(() => {
        if (mode === "actions") {
          refreshActionFocus();
        }
      }, delay);
    }
  }

  function closeVisibleDialog() {
    const dialog = [...document.querySelectorAll('[role="dialog"], .previewModal--container')]
      .filter((element) => isRendered(element, 8))
      .at(-1);
    if (!dialog) {
      return;
    }
    const close = dialog.querySelector(
      'button[aria-label*="Close" i], button[data-uia*="close" i], [role="button"][aria-label*="Close" i]',
    );
    if (close instanceof HTMLElement) {
      close.click();
    }
  }

  function returnToTiles() {
    closeVisibleDialog();
    clearAction();
    setTileMode(true);
    leaveTile(currentTile);
    const tiles = titleTiles();
    focusTile(restoreCurrentTile(tiles));
  }

  function fastPage(direction) {
    closeVisibleDialog();
    clearAction();
    setTileMode(true);
    leaveTile(currentTile);
    currentTile = null;
    currentTileKey = "";
    window.scrollBy({
      top: (direction === "up" ? -1 : 1) * window.innerHeight * 2.5,
      left: 0,
      behavior: "auto",
    });
    setTimeout(() => {
      const refreshedTiles = titleTiles();
      focusTile(preferredInitialTile(refreshedTiles));
    }, 180);
  }

  function consume(event) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }

  function isTextEntry(target) {
    return target instanceof HTMLElement && (
      target.matches("input, textarea, select") || target.isContentEditable
    );
  }

  document.addEventListener("keydown", (event) => {
    if (event.altKey || event.ctrlKey || event.metaKey || isTextEntry(event.target)) {
      return;
    }

    const direction = DIRECTIONS.get(event.key);
    const tiles = titleTiles();
    if (!tiles.length) {
      return;
    }

    const pageDirection = PAGE_DIRECTIONS.get(event.key);
    if (pageDirection) {
      consume(event);
      fastPage(pageDirection);
      return;
    }

    if (mode === "actions") {
      if (event.key === "Escape") {
        consume(event);
        returnToTiles();
        return;
      }
      if (event.key === "Enter") {
        const action = refreshActionFocus();
        if (action) {
          consume(event);
          action.click();
        }
        return;
      }
      if (direction) {
        const available = actions();
        const origin = refreshActionFocus();
        const next = origin && directionalCandidate(origin, available, direction);
        consume(event);
        focusAction(next || origin || available[0] || null);
      }
      return;
    }

    const tile = restoreCurrentTile(tiles);
    if (event.key === "Enter") {
      consume(event);
      enterActionMode();
      return;
    }
    if (direction && tile) {
      consume(event);
      focusTile(directionalCandidate(tile, tiles, direction) || tile);
    }
  }, true);

  const observer = new MutationObserver(() => {
    if (mode === "actions" && !currentAction?.isConnected) {
      refreshActionFocus();
    }
  });
  setTileMode(true);
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
