# vhonta.dev

Vitalii Honta’s personal homepage and technical writing. Hugo renders the site with the templates in `layouts/` and the stylesheet in `assets/css/site.css`. The archive content lives in `content/posts/`.

## Local development

Install the Hugo version in `.hugo-version`, then run `make hugo-dev` and open `http://localhost:1313/`. Run `make hugo-build` to build the production artifact in `dist/`. The mdoc target is only needed to regenerate a Scala tutorial from `mdoc/input/`.

## Hosting

Cloudflare Pages builds from the repo root using the pinned Hugo version, runs `make hugo-build`, and publishes `dist/`. The production branch is `main`.

`static/_redirects` supplies HTTP 301 redirects on platforms that support that format. On other hosts, configure equivalent rules for `/about/` and `/about/about/`. Hugo also emits HTML fallback redirects for both paths.

Before promotion, check the homepage, article URLs, `/posts/index.xml`, `/sitemap.xml`, and the 404 response on the preview host.
