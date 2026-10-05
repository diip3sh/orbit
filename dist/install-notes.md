### Installing

Orbit isn't notarized by Apple yet, so macOS blocks the first launch. You only do this once;
later versions install themselves through the app's updater.

1. Download the **.dmg** below and open it.
2. Drag **Orbit** onto **Applications**.
3. Open Orbit from Applications. macOS says it can't verify the app: click **Done**, not
   *Move to Trash*.
4. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click
   **Open Anyway** next to *"Orbit" was blocked*. Enter your password, then click
   **Open Anyway** again.
5. Orbit appears in the menu bar. Allow **Screen Recording** when asked, then quit and reopen it.

Prefer Terminal? After step 2, run this instead of steps 3–4:

```sh
xattr -dr com.apple.quarantine /Applications/Orbit.app && open /Applications/Orbit.app
```

**Already installed?** Use **Settings → General → Check for Updates…** instead of downloading.

**Coming from Reco?** Orbit is the same app renamed: it updates your copy in place and keeps your
settings and permissions. To get the new name in Finder too, quit Reco, delete **Reco** from
Applications and install Orbit as above; then click **Reconnect** in **Settings → Agents** for any
connected agent.
