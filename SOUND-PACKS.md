# Publish a sound pack without rebuilding the app

Installed Rainy Desk 1.5+ apps fetch this fixed endpoint:
`https://rainy-desk-sounds.shankao1008.chatgpt.site/sound-library/catalog.json`

1. Prepare mono PCM16 WAVs at 44,100 Hz, no longer than 10 seconds, below 1,000,000 bytes each, peak amplitude at most 0.60. Trim edge silence and use short fades. Use recordings you have permission to publish.
2. Run from this repository (change the example values):

```sh
python3 RainyDesk/Scripts/publish-sound-pack.py --site website \
  --id my-new-sound --version 1 \
  --title '新音效' --title-en 'New Sound' \
  --letters /path/to/letters.wav --other /path/to/other.wav
```

3. Commit the changed `website/sound-library` files to GitHub. **A GitHub push alone does not deploy the Sites website.** Update the existing Rainy Desk Sites project with those exact sound-library files and publish it. Do not rename/move the origin or endpoint, and do not create a new site. The Sites checkout uses `dist/` where this repository uses `website/`.
4. Open an installed 1.5 app and click Sound library → Check now. The pack appears without replacing the app. Automatic checks happen at launch and every 6 hours while running. Select the new pack yourself; the updater preserves your existing selection.

Use a new stable ID for a new option. Increase `--version` to revise an existing option; never change assets/metadata under an already published ID/version. Existing removed listings remain cached so users keep their chosen sound. Asset filenames are content hashes.

The script creates a `voice` mapping (physical A–Z/0–9 vs all other keys, single voice retrigger). The schema also accepts `standard` mapping with `letter`, `space`, `enter`, `delete` sample arrays and the original shortcut rules. No executable scripts/plugins are supported. Catalog schema is 1; maximum 50 packs, 20 assets/pack, 5 MB/pack and 20 MB total declared samples.

New playback behaviors or catalog schema changes require an app update. Keep the public host available for existing users; cached audio continues working offline.
