---
status: accepted
---

# The web app lives in the personal site, in another repository and cloud

The user interface is a lazy-loaded route of the owner's existing personal site, an Angular application hosted on Azure Static Web Apps, and is not part of this repository. The site already has the visual identity, theme and language switch the funnel should share, and moving it would bring no benefit.

## Consequences

- The web app and the API deploy independently, so the API is versioned under `/v1` and stays backward compatible within a version.
- The API's OpenAPI document is the contract. The web app generates its types from it, so a breaking change fails the web app's build instead of failing in the browser.
- Requests are cross-origin; CORS and the real-time connection are configured for the site's origin.
