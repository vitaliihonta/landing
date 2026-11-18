# Personal landing page rebuild specification

## Goal

Make [vhonta.dev](https://vhonta.dev/) a business card for Vitalii Honta. A visitor arriving from a referral, social profile, or talk should quickly learn who Vitalii is, find examples of his work, and know how to get in touch. Keep the existing technical writing available at its original URLs.

## Current site audit

| Area | Evidence and implications |
| --- | --- |
| Homepage | The public homepage lists three posts dated June–October 2023. The sidebar introduces the site as being about software engineering and repeats the post links under Recent. The year, feed structure, and lack of an immediate professional introduction explain why the site reads as an older blog. [Public homepage](https://vhonta.dev/) |
| About and contact | About contains the strongest bio material: Scala, functional programming, distributed systems, data engineering, and workflow orchestration. It names two open-source projects. Contact channels are configured as sidebar icons, and the source uses `mailto://` for email. [Public About](https://vhonta.dev/about/), [site configuration](config.toml) |
| Writing and speaking | Two substantial Temporal tutorials form a series. The welcome post duplicates much of About and contains three talk recordings from 2020–2022 that are difficult to discover from the homepage. [Writing source](content/posts/), [welcome post](https://vhonta.dev/posts/my-first-blog-post/) |
| Build | Hugo renders Markdown and front matter using a checked-in Poison theme, a site-level sidebar override, and static images. The theme's home template paginates posts. The Makefile provides local serving and an optional Coursier/mdoc process for regenerating Scala tutorial Markdown. A site build consumes the committed post Markdown directly. [Hugo config](config.toml), [home template](themes/poison/layouts/index.html), [Makefile](Makefile) |
| Checked-in output | `public/` is tracked and includes old Poison example pages such as `/posts/introducing-poison/`. Its contents differ from the public homepage and from current Markdown. Treat a fresh build as the release artifact and inventory the published URLs independently. |
| Build reproducibility | A fresh build to a temporary directory with local Hugo `0.170.0` failed in Poison's metadata pagination and `.Site.Author` templates. The production build version is unknown. Historical Netlify configuration pinned `0.115.0` before its removal in `0367f47`. That pin is a candidate for reproducing the old build and still needs verification. |
| Discovery and integrations | The repo includes a Google verification file and robots.txt pointing to the production sitemap. The theme provides canonical and social metadata, loads Google Analytics, and has a Disqus template with a theme-example shortname configured. The global header includes a United24 support link. [Static files](static/), [metadata template](themes/poison/layouts/partials/head/meta.html), [scripts](themes/poison/layouts/partials/head/scripts.html), [comments](themes/poison/layouts/partials/post/comments.html) |

Public checks confirmed HTTPS 200 for the homepage and sitemap and Cloudflare response headers. Cloudflare name servers were also confirmed. The homepage, About, and three post bodies were inspected via indexed public copies. The current origin, Cloudflare product, production branch, build settings, and full sitemap contents still require verification. Historical Netlify configuration is evidence of an earlier setup.

## Homepage content

Use a single English-language homepage. The opening should put the name, professional focus, and contact links together. Give each project, article, and talk a direct destination. Use short descriptions so visitors can decide what to open.

| Order | Content | Launch requirement |
| --- | --- | --- |
| 1 | **Vitalii Honta**. Draft intro: “I’m a software engineer interested in Scala, distributed systems, and workflow orchestration. I’ve authored open-source projects including ZIO Temporal and Scala QL.” | Confirm the wording reflects Vitalii's current focus. Add an employer, location, or availability only after Vitalii supplies and approves the details. The existing portrait is available if still suitable. |
| 2 | **Contact**. Label the links Email, GitHub, and LinkedIn. | Use `mailto:vitalii.honta@gmail.com` if Vitalii confirms that address is still suitable for public contact. Verify [GitHub](https://github.com/vitaliihonta) and [LinkedIn](https://www.linkedin.com/in/vitalii-honta-a70236129/) point to the intended profiles. Include the existing X/Twitter link only if Vitalii still wants to direct visitors there. |
| 3 | **Open source**. Feature ZIO Temporal as a Scala/ZIO SDK for Temporal workflows and Scala QL as a Scala library for querying collections. | Confirm each description and destination with the project documentation. Link directly to the [ZIO Temporal docs](https://zio-temporal.vhonta.dev/) and [Scala QL docs](https://scala-ql.vhonta.dev/). Keep status, adoption figures, and maintenance claims out until verified. |
| 4 | **Selected writing**. List the two Temporal articles by title with a short description and link to the full archive. | Present the introduction as an overview of Temporal and ZIO Temporal and the follow-up as a practical workflows-and-activities tutorial. Keep the original dates on the article pages. |
| 5 | **Selected talks**. List “Build Invincible Apps With ZIO And Temporal” (2022), “Stress-free DWH with Delta Lake” (2022, Ukrainian), and “Scala 3 in Action” (2020). | Verify each recording and use text links. Existing recording IDs are [8MUnEahr5tk](https://www.youtube.com/watch?v=8MUnEahr5tk), [CLL-4R_kx7Q](https://www.youtube.com/watch?v=CLL-4R_kx7Q), and [S2a57ddG5wQ](https://www.youtube.com/watch?v=S2a57ddG5wQ). |
| 6 | Footer | Ask Vitalii whether to carry forward the existing United24 link and where it should appear. A résumé, contact form, and separate talks page are outside the initial release. |

## URL and content migration

| Existing URL | Release behavior |
| --- | --- |
| `/` | Serve the personal landing page. Use a descriptive title such as “Vitalii Honta — Software Engineer” and a matching search description and share preview. |
| `/about/` | Permanently redirect to `/` once the bio is incorporated. Check `/about/about/` during inventory and give it the same redirect if publicly served as a legacy route. |
| `/posts/` | Keep the full writing archive, including the welcome post. |
| `/posts/zio-temporal-intro/` | Keep the published introduction at this URL. |
| `/posts/workflows-activities/` | Keep the published follow-up at this URL. |
| `/posts/my-first-blog-post/` | Keep the original welcome post as an archive entry. Surface its selected talks on the homepage. |
| Tags, series, feeds, and article media | Inventory actual production paths before implementation. Preserve the author’s Temporal series, article anchors, screenshots, diagrams, code blocks, video access, and feeds already in use. For other public archive paths, keep the route or map it to a relevant replacement. |

Preserve the domain and HTTPS, including canonical URLs under `https://vhonta.dev/`. Generate a sitemap with absolute production URLs, retain robots.txt and the existing Google verification file, and test that the Open Graph image is served at an absolute URL. Check real public URLs before assigning redirects. Give genuinely unknown paths a 404. Confirm whether analytics and comments are used before deciding what to carry forward. The proposed homepage uses ordinary outbound links and loads without a third-party script or embed.

## Deployment from this repository

### Identify the existing production pipeline

In the Cloudflare dashboard, identify the service behind `vhonta.dev` and whether Cloudflare also hosts the site. If DNS proxies another provider, inspect that provider’s project settings. Record the project, linked GitHub repository and production branch, build root and command, toolchain version, output directory, environment variable names, custom domains and redirects, preview settings, and the last known-good deployment or artifact. Keep credential values in the hosting provider's settings.

No deploy workflow, current provider manifest, or production Hugo pin is tracked at the reviewed branch base. The last `main` commit is a README update (`7b8df9b`). The precise relationship between that branch and the serving artifact is a dashboard check. Verify the existing project and branch settings before any push that could trigger a deploy.

### Build and preview

1. Use a static artifact and the existing hosting project if it supports building from this repository. Use Hugo as the first candidate because it already owns the writing pipeline and URLs. Verify a compatible version or update the templates and pin a version that passes a fresh build. A different static generator is acceptable if it preserves the URL and content contract.
2. Make the build contract explicit in the repo and mirror it in the provider where required. For Hugo, the expected build root is the repository root and the artifact is a fresh `public/` directory. A candidate production command is `hugo --baseURL https://vhonta.dev/ --destination public` run with a verified pinned Hugo version and an empty output directory. Remove the tracked stale output from the implementation branch once the confirmed host is configured to build from source. Keep the mdoc toolchain optional for site deploys.
3. Build from a clean checkout in CI or a provider preview. Publish the branch to a protected preview where available, or send a `noindex` directive on the preview host. Check that the preview stays out of the production sitemap and that its canonical settings and asset paths work when promoted.
4. Collect the production URL inventory from the sitemap, feeds, and known inbound links. Compare the preview against it and test each redirect on the serving platform. Confirm that existing project subdomains and any unrelated DNS records keep their current routing.

### Release and rollback

Record the current production deploy ID, source revision if available, and relevant dashboard settings. After the preview passes, merge into the confirmed production branch and observe the provider build through completion. Check the custom domain over HTTPS and smoke-test the homepage, archives, article media, redirects, 404, and sitemap. If core paths regress, restore the recorded known-good deployment in the provider or re-release the previous verified artifact. If the host uses Git as its only rollback mechanism, revert the implementation change and verify the restored build. The redesign does not require a DNS change if it can use the existing hosting project.

## Acceptance checks

- The homepage identifies Vitalii and his field, and gives visitors labeled contact links and direct access to projects, selected writing, and talks.
- Contact links work, biographies and project descriptions have owner approval, and video destinations match their titles and languages.
- The homepage and archive read comfortably on mobile and desktop. Navigation and links work by keyboard, and the main content and contact links work with JavaScript disabled.
- All three public article routes serve the original material and assets. The About redirect works, indexed routes and feeds have explicit dispositions, and missing routes return an appropriate 404.
- A clean checkout produces the same release layout in local verification and on the host using the pinned toolchain. The artifact contains no stale Poison example pages.
- Production HTTPS, sitemap, robots, verification file, canonical tags, and share image work. The deployed revision and rollback path are recorded.
