/* Select every scope in Shopify's "Select scopes" popup, then press Done.
   If the popup is closed, it first clicks the page's "Select from list" button to open it.
   Runs three ways: through the `all` command, as a bookmarklet, or pasted in the browser's DevTools console.
   Returns 'NO_DIALOG' or 'STARTED' straight away; the final message lands in
   window.__selectAllScopesResult (and the console) once the work is done. */
(() => {
  const dryRun = window.__selectAllScopesDryRun === true;
  window.__selectAllScopesDryRun = false;
  window.__selectAllScopesResult = null;

  /* Look in the page and in any same-origin iframes */
  const docs = [document];
  for (const f of document.querySelectorAll('iframe')) {
    try { if (f.contentDocument) docs.push(f.contentDocument); } catch (e) { /* cross-origin */ }
  }
  const findDialog = () => docs
    .flatMap(d => [...d.querySelectorAll('dialog')])
    .find(d => d.open && d.textContent.includes('Select scopes'));
  const findTrigger = () => docs
    .map(d => d.querySelector('[aria-controls="select_scopes-dialog"], [commandfor="select_scopes-dialog"]'))
    .find(Boolean) || docs
    .flatMap(d => [...d.querySelectorAll('button')])
    .find(b => /^\s*select from list\s*$/i.test(b.textContent));

  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const finish = msg => {
    window.__selectAllScopesResult = msg;
    console.log('[select-all-scopes] ' + msg);
  };
  const boxesOf = dialog => [...dialog.querySelectorAll('input[type="checkbox"]')];

  let dialog = findDialog();
  const trigger = dialog ? null : findTrigger();
  if (!dialog && !trigger) {
    console.warn('[select-all-scopes] No "Select scopes" popup or "Select from list" button on this page.');
    return 'NO_DIALOG';
  }

  if (dryRun) {
    if (dialog) {
      const b = boxesOf(dialog);
      finish(`Dry run: popup found, ${b.filter(c => c.checked).length}/${b.length} selected. Nothing changed.`);
    } else {
      finish('Dry run: popup is closed; would open it with "Select from list". Nothing changed.');
    }
    return 'STARTED';
  }

  (async () => {
    let opened = '';
    if (!dialog) {
      trigger.click();
      for (let i = 0; i < 40 && !(dialog = findDialog()); i++) await sleep(100);
      if (!dialog) return finish('Error: clicked "Select from list", but the popup did not open.');
      opened = 'Opened the list. ';
      await sleep(300);
    }

    /* Clear the search box so every scope is listed (native setter, so the page's scripts see it) */
    const search = dialog.querySelector('input[type="search"], input[placeholder*="Search"]');
    if (search && search.value) {
      const proto = search.ownerDocument.defaultView.HTMLInputElement.prototype;
      Object.getOwnPropertyDescriptor(proto, 'value').set.call(search, '');
      search.dispatchEvent(new Event('input', { bubbles: true }));
      await sleep(300);
    }

    let n = 0;
    for (const cb of boxesOf(dialog)) {
      if (!cb.checked && !cb.disabled) { cb.click(); n++; }
    }
    await sleep(300);

    const all = boxesOf(dialog);
    const picked = all.filter(c => c.checked).length;
    const doneBtn = [...dialog.querySelectorAll('button')].find(b => b.textContent.trim() === 'Done');
    doneBtn?.click();
    finish(`${opened}Checked ${n} more (${picked}/${all.length} selected).${doneBtn ? ' Pressed Done.' : ' No Done button found.'}`);
  })().catch(e => finish('Error: ' + e.message));

  return 'STARTED';
})();
