---
description: How to fetch screen designs from Google Stitch
---

## Context

The user's Stitch projects are accessible at:
**https://stitch.withgoogle.com/projects/**

Do NOT attempt to use embed URLs, project-folder paths, appspot URLs, or any other variant.
The only correct base URL is `https://stitch.withgoogle.com/projects/`.

## Steps

1. Open the browser and navigate directly to:
   ```
   https://stitch.withgoogle.com/projects/
   ```

2. From the projects list, find the target project by name or ID and click it.

3. Once inside the project, click the target screen by name or ID in the left-hand screen panel.

4. Capture a screenshot of the rendered screen design.

5. Use the **Export / Code** panel (if available) to read Flutter/Dart code hints and color values.

6. Report back:
   - Full description of every visible UI element (layout, colors, typography, icons)
   - Any color hex values observed
   - Any code snippets visible in the export panel

## Important Rules

- **Never** guess or construct embed/appspot/project-folder URLs — always start from `https://stitch.withgoogle.com/projects/`.
- If the page requires a Google login, report that back to the user — do not try alternative URL schemes.
- Do not navigate away from `stitch.withgoogle.com`.
