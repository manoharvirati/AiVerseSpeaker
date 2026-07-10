# Offline English Tutor Content Architecture

The app uses normalized JSON files in `data_source/` as authoring data.
Build tools compile those files into `assets/database/content.db`.

At runtime, the app reads the compiled SQLite content database asset instead of
parsing JSON content files. User progress remains in the writable app database.

Build command:

```powershell
python tools/build_content_database.py
```

Generated artifacts:

- `assets/database/content.db`
- `assets/database/content.db.sha256`
