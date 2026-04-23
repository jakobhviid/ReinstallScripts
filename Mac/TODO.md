# TODO

## Brave Browser: Fix Cmd+W lukker vindue i stedet for tab

Brave har en intermittent Chromium-bug hvor "Close Tab" menupunktet forsvinder fra File-menuen over tid, og "Close Window" overtager Cmd+W genvejen.

Workaround via macOS App Shortcut der tvinger "Close Window" til Cmd+Shift+W:

```bash
defaults write com.brave.Browser NSUserKeyEquivalents -dict-add "Close Window" '@$w'
```

Fjernelse:

```bash
defaults delete com.brave.Browser NSUserKeyEquivalents
```
