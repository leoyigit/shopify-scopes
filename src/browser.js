/* Talks to your browsers through macOS (JavaScript for Automation). Used by bin/all and install.sh.
     osascript -l JavaScript src/browser.js run "<page script>" [browser]   run the page script in the Shopify tab
     osascript -l JavaScript src/browser.js status                         one line per installed browser
   Only reads tab addresses, and runs the page script only in tabs on shopify.com. */
ObjC.import('AppKit');

// bundle id, name, kind, Chromium profile folder under ~/Library/Application Support (for the setting check)
const BROWSERS = [
  ['com.google.Chrome', 'Google Chrome', 'chromium', 'Google/Chrome'],
  ['com.google.Chrome.beta', 'Google Chrome Beta', 'chromium', 'Google/Chrome Beta'],
  ['com.google.Chrome.dev', 'Google Chrome Dev', 'chromium', 'Google/Chrome Dev'],
  ['com.google.Chrome.canary', 'Google Chrome Canary', 'chromium', 'Google/Chrome Canary'],
  ['org.chromium.Chromium', 'Chromium', 'chromium', 'Chromium'],
  ['com.brave.Browser', 'Brave Browser', 'chromium', 'BraveSoftware/Brave-Browser'],
  ['com.microsoft.edgemac', 'Microsoft Edge', 'chromium', 'Microsoft Edge'],
  ['com.vivaldi.Vivaldi', 'Vivaldi', 'chromium', 'Vivaldi'],
  ['company.thebrowser.Browser', 'Arc', 'chromium', 'Arc/User Data'],
  ['com.apple.Safari', 'Safari', 'safari', ''],
  ['com.apple.SafariTechnologyPreview', 'Safari Technology Preview', 'safari', ''],
];
// Browsers macOS can't run page scripts in: these use the bookmark (`all --bookmarklet`).
const UNSUPPORTED = {
  'org.mozilla.firefox': 'Firefox', 'org.mozilla.firefoxdeveloperedition': 'Firefox Developer Edition',
  'org.mozilla.nightly': 'Firefox Nightly', 'app.zen-browser.zen': 'Zen', 'com.operasoftware.Opera': 'Opera',
};
const SHOPIFY = /^https:\/\/[^\/]*shopify\.com(\/|$)/;
const DENIED = /-1743|Not authori[sz]ed|not allowed to send/i;
const JS_OFF = /turned off|Allow JavaScript from Apple Events/i;

const ws = $.NSWorkspace.sharedWorkspace;
const runningIds = () => (ObjC.deepUnwrap(ws.runningApplications.valueForKey('bundleIdentifier')) || []).filter(Boolean);
const frontId = () => { try { return ObjC.unwrap(ws.frontmostApplication.bundleIdentifier) || ''; } catch (e) { return ''; } };
const installed = id => { try { return !ws.URLForApplicationWithBundleIdentifier(id).isNil(); } catch (e) { return false; } };

const exec = (app, kind, tab, js) => kind === 'safari' ? app.doJavaScript(js, { in: tab }) : tab.execute({ javascript: js });
const titleOf = (kind, tab) => { try { return String((kind === 'safari' ? tab.name() : tab.title()) || ''); } catch (e) { return ''; } };
const urlOf = tab => { try { return String(tab.url() || ''); } catch (e) { return ''; } };
const activeIndex = (kind, w) => { try { return (kind === 'safari' ? w.currentTab().index() : w.activeTabIndex()) - 1; } catch (e) { return -1; } };

function runPageScript(code, only) {
  const ids = runningIds();
  const front = frontId();
  let list = BROWSERS.filter(b => ids.includes(b[0]));
  if (only) list = list.filter(b => b[1].toLowerCase().includes(only.toLowerCase()));
  list.sort((a, b) => (b[0] === front) - (a[0] === front)); // the browser in front first
  if (!list.length) {
    const other = [...new Set(ids.map(id => UNSUPPORTED[id]).filter(Boolean))];
    return other.length ? 'ERR_UNSUPPORTED ' + other.join(', ') : 'ERR_NO_BROWSER' + (only ? ' ' + only : '');
  }
  let shopifyTabs = 0;
  let firstError = '';
  for (const [id, name, kind] of list) {
    const app = Application(id);
    let wins;
    try { wins = app.windows(); } catch (e) {
      if (DENIED.test(String(e))) return 'ERR_DENIED ' + name;
      firstError = firstError || name + ': ' + e;
      continue;
    }
    for (const w of wins) {
      let tabs;
      try { tabs = w.tabs(); } catch (e) { continue; }
      const a = activeIndex(kind, w);
      const order = a >= 0 && a < tabs.length ? [a, ...tabs.map((_, i) => i).filter(i => i !== a)] : tabs.map((_, i) => i);
      for (const i of order) {
        const tab = tabs[i];
        if (!SHOPIFY.test(urlOf(tab))) continue;
        shopifyTabs++;
        let r;
        try { r = exec(app, kind, tab, code); } catch (e) {
          const s = String(e);
          if (JS_OFF.test(s)) return 'ERR_APPLE_EVENTS ' + name;
          if (DENIED.test(s)) return 'ERR_DENIED ' + name;
          firstError = firstError || name + ': ' + s;
          continue;
        }
        if (r !== 'STARTED') continue;
        for (let k = 0; k < 60; k++) { // wait up to 15 s for the page script to finish
          const res = exec(app, kind, tab, 'window.__selectAllScopesResult');
          if (res) return 'OK ' + res + '\n' + titleOf(kind, tab) + ' · ' + name;
          delay(0.25);
        }
        return 'ERR_TIMEOUT ' + titleOf(kind, tab) + ' · ' + name;
      }
    }
  }
  if (firstError && !shopifyTabs) return 'ERR_OTHER ' + firstError;
  return shopifyTabs ? 'ERR_NO_POPUP ' + shopifyTabs : 'ERR_NO_TAB ' + list.map(b => b[1]).join(', ');
}

// One line per installed browser: name|kind|status|profile folder. Status: on, off, denied, unknown, notrunning.
function status() {
  const ids = runningIds();
  const lines = [];
  for (const [id, name, kind, dir] of BROWSERS) {
    if (!installed(id)) continue;
    let st = 'notrunning';
    if (ids.includes(id)) {
      st = 'unknown';
      try {
        const app = Application(id);
        scan: for (const w of app.windows()) {
          for (const tab of w.tabs()) {
            if (!/^https?:/.test(urlOf(tab))) continue; // browser pages (chrome://, new tab) can't run scripts
            try { if (exec(app, kind, tab, '"js-on"') === 'js-on') { st = 'on'; break scan; } } catch (e) {
              const s = String(e);
              st = JS_OFF.test(s) ? 'off' : DENIED.test(s) ? 'denied' : 'unknown';
              break scan;
            }
          }
        }
      } catch (e) { st = DENIED.test(String(e)) ? 'denied' : 'unknown'; }
    }
    lines.push([name, kind, st, dir].join('|'));
  }
  for (const id of new Set(ids)) if (UNSUPPORTED[id]) lines.push([UNSUPPORTED[id], 'unsupported', 'running', ''].join('|'));
  return lines.join('\n');
}

function run(argv) {
  if (argv[0] === 'status') return status();
  if (argv[0] === 'run') return runPageScript(argv[1] || '', argv[2] || '');
  return 'ERR_OTHER usage: browser.js run <code> [browser] | status';
}
