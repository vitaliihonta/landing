# vhonta.dev

Vitalii Honta’s personal homepage and technical writing. Hugo renders the site with the templates in `layouts/` and the stylesheet in `assets/css/site.css`. The archive content lives in `content/posts/`.

## Local development

Install the Hugo version in `.hugo-version`, then run `make hugo-dev` and open `http://localhost:1313/`. Run `make hugo-build` to build the production artifact in `dist/`. The mdoc target is only needed to regenerate a Scala tutorial from `mdoc/input/`.

## Hosting

Confirm the current provider and production branch before pushing deploy changes. Configure a source build from the repo root using the pinned Hugo version, `make hugo-build` (or its Hugo command), and publish `dist/`. The old tracked `public/` directory is historical and should be retired after confirming the host uses the new output directory.

`static/_redirects` supplies HTTP 301 redirects on platforms that support that format. On other hosts, configure equivalent rules for `/about/` and `/about/about/`. Hugo also emits HTML fallback redirects for both paths.

Before promotion, check the homepage, article URLs, `/posts/index.xml`, `/sitemap.xml`, and the 404 response on the preview host. See [the rebuild specification](PERSONAL-LANDING-SPEC.md) for the full migration and rollback checklist.
