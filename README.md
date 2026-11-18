# Select all scopes

Creating a custom app in Shopify means ticking every scope in the **Select scopes** list, one checkbox at a time
(about 180 of them). This tool does it in one go. On your app's page, type `all` in a terminal or press your keyboard
shortcut: it opens the list, ticks every scope and presses **Done**.

```text
$ all
✓ Opened the list. Checked 179 more (179/179 selected). Pressed Done.
  in: Create an app · Dev Dashboard · Google Chrome
```

- **Mac only.** Works in Chrome, Safari, Brave, Edge, Arc, Vivaldi and Chromium. In any other browser (Firefox,
  Opera…), use the [bookmark](#bookmark-instead-any-browser-no-setup).
- **Tested** on the Shopify Dev Dashboard, **Create an app** page, in Google Chrome.
- **Updates itself on request.** When a new version is out, `all` tells you, and `all --update` installs it.

---

## Install (about 2 minutes)

You need access to this private repo (ask the repo owner) and the GitHub CLI, signed in:

```bash
brew install gh     # skip if you already have it
gh auth login       # skip if you're already signed in
```

Then paste this into Terminal:

```bash
gh api repos/leoyigit/shopify-scopes/contents/install.sh -H "Accept: application/vnd.github.raw" | bash
```

<details>
<summary>No GitHub CLI? Use git instead</summary>

```bash
git clone https://github.com/leoyigit/shopify-scopes.git ~/.local/share/shopify-scopes
bash ~/.local/share/shopify-scopes/install.sh
```
</details>

The installer walks you through five short steps and checks each one:

1. **Check this Mac**: macOS, and which of your browsers it can use.
2. **Install the command** `all` in `~/.local/bin`, adding that folder to your PATH if needed. If the name `all` is
   already taken on your Mac, it asks for another one.
3. **Let your browser accept the command**: it checks the one browser setting this needs and tells you where it is.
4. **Keyboard shortcut** (optional): opens the Shortcuts app and guides you through it.
5. **Try it**: a safe test that changes nothing.

Run it again any time with `all --setup`.

---

## Use it

1. Open your app's page in the browser: the one with the **Scopes** section (for example Dev Dashboard → **Create an
   app**). The **Select scopes** list can be open or closed.
2. Type `all` in a terminal, or press your keyboard shortcut.

It finds the right tab by itself, even when the browser isn't the window in front. If the list is closed, it clicks
**Select from list** first.

| Command | What it does |
|---|---|
| `all` | Open the list if needed, tick every scope, press **Done** |
| `all --check` | Look for the list and report, change nothing |
| `all --browser safari` | Use only this browser (any part of its name: `chrome`, `brave`, `edge`, `arc`…) |
| `all --bookmarklet` | Copy a bookmark version to the clipboard (see below) |
| `all --setup` | Run the guided setup again: checks and keyboard shortcut |
| `all --update` | Install the latest version and show what's new |
| `all --version` | Show the version and check for updates now |
| `all --uninstall` | Remove it from this Mac |
| `all --help` | Show all of this in the terminal |

---

## Updates

`all` checks for a new version quietly in the background, at most once a day. When there is one, you'll see this after
the result:

```text
  ↑ Update available: v1.0.0 → v1.1.0. Run all --update
```

When you use the keyboard shortcut, you get a macOS notification instead, once a day at most. Run `all --update` in a
terminal: it downloads the new version and lists what changed. To switch the check off, set
`SHOPIFY_SCOPES_NO_UPDATE_CHECK=1` in your shell.

---

## Keyboard shortcut

The installer guides you through this; here are the same steps.

1. Open the **Shortcuts** app, press **⌘N** and name the shortcut **Select all scopes**.
2. Add the action **Run Shell Script** and replace its text with the full path of the command, e.g.
   `/Users/<you>/.local/bin/all` (the installer copies it to your clipboard).
3. Open **ⓘ Details** on the right and tick **Use as Quick Action** and **Services Menu**.
4. At the top it now says **Receive Apps and 18 more**. Click the blue types and **untick all of them**, so the shortcut
   receives no input. Skip this and the key does nothing in the browser.
5. In Details, click **Run with** and press your keys, for example **⌃⌥⌘A**. Avoid **⌃\`** if you use VS Code: it
   opens VS Code's terminal there.
6. In the Shortcuts menu, go to **Settings → Advanced** and tick **Allow Running Scripts**.
7. Test it: on your app's page, press your keys. The first time, macOS asks to let Shortcuts control your browser:
   click **Allow**.

To check the shortcut is available, look for **Select all scopes** in your browser's app menu under **Services**.

---

## Bookmark instead (any browser, no setup)

`all --bookmarklet` copies a bookmark version to your clipboard. Add a bookmark to your bookmarks bar, name it
**Select all scopes** and paste as its address. Click it on your app's page. It works in every browser, Firefox
included, and needs neither the browser setting nor the terminal, but it can't have a keyboard shortcut.

---

## Troubleshooting

| You see | Fix |
|---|---|
| `Google Chrome is blocking scripts from outside.` (or Brave, Edge…) | In that browser's menu bar: **View → Developer → Allow JavaScript from Apple Events**, so it has a tick. |
| `Safari is blocking scripts from outside.` | **Safari → Settings → Advanced** → tick **Show features for web developers**, then **Develop → Allow JavaScript from Apple Events**. |
| `macOS hasn't allowed this app to control …` | **System Settings → Privacy & Security → Automation**: under your terminal app (or Shortcuts), turn the browser on. |
| `No Shopify tab is open in …` | Open your app's page first. |
| `… but no Select scopes popup or Select from list button.` | Go to the page with the **Scopes** section, then run it again. |
| `Firefox can't be controlled from the terminal.` | Use the bookmark: `all --bookmarklet`. |
| `command not found: all` | Open a new terminal tab (the PATH change applies to new tabs), or run `~/.local/bin/all`. |
| The keyboard shortcut does nothing | Check steps 3, 4 and 6 above: **receive no input**, **Services Menu** ticked, **Allow Running Scripts** on. |
| `Couldn't download the update.` | Check you're online and signed in: `gh auth status`. |

Still stuck? Run `all --setup`: it re-checks everything and tells you what's missing.

---

## How it works, and what it touches

- `all` asks your browser, through macOS, to run a small script ([`src/select-all-scopes.js`](src/select-all-scopes.js))
  in your open Shopify tab. If the **Select scopes** list is closed, the script clicks **Select from list**. Then it
  clears the list's search box, ticks every unticked checkbox that isn't greyed out, and clicks **Done**. Nothing else
  on the page changes, and nothing is sent anywhere.
- It only reads the addresses of your tabs, and only runs the script in tabs on `shopify.com` sites. `all --check`
  does the same search without clicking anything.
- The browser setting **Allow JavaScript from Apple Events** lets apps you've allowed to control the browser run
  scripts in its tabs. Turn it off whenever you like; only the terminal and keyboard routes need it.
- The update check runs `git fetch` on its own folder once a day, through your GitHub sign-in; it never changes your
  files until you run `all --update`.
- Installed files: the code in `~/.local/share/shopify-scopes`, a link at `~/.local/bin/all`, and one PATH line in
  `~/.zshrc` if your PATH didn't include `~/.local/bin`. `all --uninstall` removes the first two.
- If Shopify changes the page, the script may need an update: `all --update`.

---

## For maintainers

- **Release a new version:** change the code, raise the number in `VERSION` (e.g. `1.0.0` → `1.1.0`), commit with a
  clear message, and push to `main`. Everyone sees the update reminder within a day, and `all --update` lists the
  commit messages as "what's new".
- **Give a colleague access:** repo **Settings → Collaborators → Add people** (read access is enough).
- **Test without touching your own setup:** `HOME=$(mktemp -d) bash install.sh --yes` installs into a throwaway folder.

```text
bin/all                    the command
src/select-all-scopes.js   the script that runs in the Shopify tab (also works pasted into the DevTools console)
src/browser.js             finds the Shopify tab in each supported browser and runs the script there
install.sh                 guided installer: install, --update, --uninstall, --yes, --name <command>
VERSION                    the current version; raise it to trigger update reminders
```
