---
title: "Introducing Poison"
date: 2022-11-23T13:43:53-06:00
draft: false
image: brand_image.jpg
tags: ["hugo","introduction"]
series: "How to use poison"
---

*Poison* is a **clean**, **professional** Hugo theme designed to **captivate** your readers.

It's also **tiny** and **privacy conscious** with *no external dependencies* (unless you opt to include comments).  No JavaScript frameworks, icon packs, or Google fonts.  No ads or trackers polluting your console window.  **We kept things simple**.  A little vanilla JavaScript, a dash of CSS, and the power of Hugo.

<!--more-->

## Features

In addition to the standard Built-in templates and shortcodes that come with Hugo, *Poison* offers some unique features of its own.

### Light & dark mode

Give readers the choice to read in light or dark mode.  The user's preference is remembered and saved in local storage.  Light mode is the default for first time visitors, but you can change this in your config file.

### Table of contents

Provide a floating table of contents for readers with large enough screens (i.e. *screen-width greater than 1600 pixels*).

### Comments

Facilitate discourse by allowing users to comment on your posts.  *Poison* currently supports two different commenting engines for this purpose -- [Disqus](https://disqus.com/) and [Remark42](https://remark42.com/).

**Note**: *Enabling comments will add external dependencies.*

- [Disqus Demo Site](https://about.disqus.com/disqus-demo-page) 
- [Remark42 Demo Site](https://remark42.com/demo/)

***Disqus*** is free and easy to use.  Checkout the [Hugo docs](https://gohugo.io/content-management/comments/) to get started.  Once you've created a *Disqus* account, you can activate it in the *Poison* theme by adding a single line to your `config.toml` file.

{{< highlight text >}}
disqusShortname = 'yourDisqusShortname'
{{</highlight >}}

This is a great option for people that don't want to bother with self-hosting their own commenting engine; however, it has some drawbacks.  Because *Disqus* provides this service for free, they recoup any financial loss by injecting third-party ad trackers onto your website.  These trackers help to collect and sell information about your users, while also negatively affecting your site's speed.

Even still, *Disqus* may be the best solution depending on your situation (we use it on this demo site).  The above paragraph is only meant to highlight its trade-offs and not meant to discourage its use entirely.

***Remark42*** is a lightweight, open source commenting engine that doesn't spy on your users.  The downside is that you must host it yourself.  Checkout the *Remark42* [documentation](https://remark42.com/) to get started.  I also found [this blog post](https://www.devbitsandbytes.com/setting-up-remark42-from-scratch/) helpful when setting it up on [my site](https://lukeorth.com).

Once everything is set up, you can activate it in the *Poison* theme by including the following in the `[params]` section of your `config.toml` file.

{{< highlight text >}}
[params]
    remark42 = true
    remark42_host = "https://yourhost.com"
    remark42_site_id = "your_site_id"
{{</highlight >}}

### Series

Sensibly link and display content in "series" (i.e. *Tutorial One*, *Tutorial Two*, etc.).
   
This is done with a custom taxonomy. Just add `series` to the frontmatter on any content you want to group together.

{{< highlight yaml >}}
---
title: "Example to demonstrate how to use series"
date: 2022-10-04
draft: false
series: "How to use poison"
tags: ["Hugo"]
---
{{</highlight >}}

### KaTeX

Make your mathematical notations pop.

For notations that should appear on their own line, use the block quotes `$$ ... $$`
    
$$ 5 \times 5 = 25 $$

For notations that should appear on the same line, use the inline quotes `$ ... $`
    
### Tabs

Some content is just better viewed in tabs.  There's a shortcode for that.

{{< tabs tabTotal="2" >}}

{{% tab tabName="First Tab" %}}
This is **markdown** content.
{{% /tab %}}

{{< tab tabName="Second Tab" >}}
{{< highlight text >}}
This is a code block.
{{</ highlight >}}
{{< /tab >}}

{{< /tabs >}}

---
Here's the code for the tabs above...

{{< highlight text >}}
{{</* tabs tabTotal="2" */>}}

{{%/* tab tabName="First Tab" */%}}
This is markdown content.
{{%/* /tab */%}}

{{</* tab tabName="Second Tab" */>}}
{{</* highlight text */>}}
This is a code block.
{{</* /highlight */>}}
{{</* /tab */>}}

{{</* /tabs */>}}
{{</ highlight >}}
   
### Mermaid diagrams

There's a shortcode for embedding Mermaid diagrams.

{{< mermaid >}}
sequenceDiagram
participant Alice
participant Bob
Alice->>John: Hello John, how are you?
loop Healthcheck
    John->>John: Fight against hypochondria
end
Note right of John: Rational thoughts <br>prevail!
John-->>Alice: Great!
John->>Bob: How about you?
Bob-->>John: Jolly good!
{{< /mermaid >}}

Here's the code for the diagram above:

{{< highlight text >}}
{{</* mermaid */>}}
sequenceDiagram
participant Alice
participant Bob
Alice->>John: Hello John, how are you?
loop Healthcheck
    John->>John: Fight against hypochondria
end
Note right of John: Rational thoughts <br>prevail!
John-->>Alice: Great!
John->>Bob: How about you?
Bob-->>John: Jolly good!
{{</* /mermaid */>}}
{{</ highlight >}}

### PlantUML diagrams

There's a shortcode for embedding PlantUML diagrams.

{{< plantuml id="foo" >}}
a -> b
b -> c
{{< /plantuml >}}

Here's the code for the diagram above:

{{< highlight text >}}
{{< plantuml id="foo" >}}
a -> b
b -> c
{{< /plantuml >}}
{{</ highlight >}}

## Installation

First, clone this repository into your `themes` directory:

{{< highlight text >}}
git clone https://github.com/lukeorth/poison.git themes/poison --depth=1
{{</highlight >}}

Next, specify `poison` as the default theme in your config.toml file by adding the following line:

{{< highlight text >}}
theme = "poison"
{{</highlight >}}

Lastly, if there are any future updates to this repository that you wish to include in your local copy, these can be retrieved by running:

{{< highlight text >}}
cd themes/poison

git pull
{{</highlight >}}

For more information on how to get started with Hugo and themes, read the official [quick start guide](https://gohugo.io/getting-started/quick-start/).

## How to Configure

After successfully installing *Poison*, the last step is to configure it.

### The Sidebar Menu

Any items you want displayed in your sidebar menu *must* satisfy two requirements.  They must:

1. Have a corresponding markdown file in your */content/* directory.
2. Be declared in your *config.toml* file (example below).

There are two types of menu items:

1. **Single Page** -- The *About* menu item (to the left) is a good example of this.  It displays a direct link to an individual page.
2. **List** -- The *Posts* menu item is a good example of this.  It displays a directory and dynamically lists the contents (i.e. pages) contained by date.  List items have two optional configurations: a subheading (like the *Recent* subheading that appears on the menu to the left), and a maximum number of items to display.

The sidebar menu items are configured with a dictionary value in your *config.toml* file.  I've included an example below.  Additionally, there is a placeholder for this in the *config.toml* file shown in the next section.

**Remember**: You must have a markdown file present at the path specified for the menu item to be displayed.

{{< highlight toml >}}
menu = [
        # Dict keys:
            # Name:         The name to display on the menu.
            # URL:          The directory relative to the content directory.
            # HasChildren:  If the directory's files should be listed.  Default is true.
            # Limit:        If the files should be listed, how many should be shown.

        # SINGLE PAGE
        # Note that you must put your markdown file 
        # inside of a directory with the same name.

        # Example:
        # ... /content/about/about.md
        {Name = "About", URL = "/about/", HasChildren = false},
        
        # LIST
        # This example has a subheading of "Recent"
        # and will display up to 5 items.

        # Example:
        # ... /content/posts/introducing-poison.md
        {Name = "Posts", URL = "/posts/", Pre = "Recent", HasChildren = true, Limit = 5},

        # Example of a list without a subheading or limit.
        {Name = "Projects", URL = "/projects/"},
    ]
{{</highlight >}}

### Example Config
I recommend starting by copying/pasting the following code into your config.toml file.  Once you see how it looks, play with the settings as needed.

**NOTE**: To display an image in your sidebar, you'll need to uncomment the `brand_image` path below and have it point to an image file in your project.  The path is relative to the `static` directory.  If you don't have an image, just leave this line commented out.

{{< highlight toml >}}
baseURL = "/"
languageCode = "en-us"
theme = "poison"
paginate = 10
pluralizelisttitles = false   # removes the automatically appended "s" on sidebar entries

# NOTE: If using Disqus as commenting engine, uncomment and configure this line
# disqusShortname = "yourDisqusShortname"

[params]
    brand = "Poison"                      # name of your site - appears in the sidebar
    # brand_image = "/images/test.jpg"    # path to the image shown in the sidebar
    description = "Update this description..." # Used as default meta description if not specified in front matter
    dark_mode = true                      # optional - defaults to false
    # favicon = "favicon.png"             # path to favicon (defaults to favicon.png)

    # MENU PLACEHOLDER
    # Menu dict keys:
        # Name:         The name to display on the menu.
        # URL:          The directory relative to the content directory.
        # HasChildren:  If the directory's files should be listed.  Default is true.
        # Limit:        If the files should be listed, how many should be shown.
    menu = [
        {Name = "About", URL = "/about/", HasChildren = false},
        {Name = "Posts", URL = "/posts/", Pre = "Recent", HasChildren = true, Limit = 5},
    ]

    # Links to your socials.  Comment or delete any you don't need/use. 
    github_url = "https://github.com"
    gitlab_url = "https://gitlab.com"
    linkedin_url = "https://linkedin.com"
    twitter_url = "https://twitter.com"
    mastodon_url = "https://mastodon.social"
    tryhackme_url = "https://tryhackme.com"
    discord_url = "https://discord.com"
    youtube_url = "https://youtube.com"
    instagram_url = "https://instagram.com"
    facebook_url = "https://facebook.com"
    flickr_url = "https://flickr.com"
    telegram_url = "https://telegram.org"
    email_url = "mailto://user@domain"

    # NOTE: If you don't want to use RSS, comment or delete the following lines
    # Adds an RSS icon to the end of the socials which links to {{ .Site.BaseURL }}/index.xml
    rss_icon = true
    # Which section the RSS icon links to, defaults to all content. See https://gohugo.io/templates/rss/#section-rss
    rss_section = "posts"

    # Hex colors for your sidebar.
    sidebar_bg_color = "#202020"            # default is #202020
    sidebar_img_border_color = "#515151"    # default is #515151
    sidebar_p_color = "#909090"             # default is #909090
    sidebar_h1_color = "#FFF"               # default is #FFF
    sidebar_a_color = "#FFF"                # default is #FFF
    sidebar_socials_color = "#FFF"          # default is #FFF
    moon_sun_color = "#FFF"                 # default is #FFF
    moon_sun_background_color = "#515151"   # default is #515151

    # Hex colors for your content in light mode.
    text_color = "#222"             # default is #222
    content_bg_color = "#FAF9F6"    # default is #FAF9F6
    post_title_color = "#303030"    # default is #303030
    list_color = "#5a5a5a"          # default is #5a5a5a
    link_color = "#268bd2"          # default is #268bd2
    date_color = "#515151"          # default is #515151
    table_border_color = "#E5E5E5"  # default is #E5E5E5
    table_stripe_color = "#F9F9F9"  # default is #F9F9F9

    # Hex colors for your content in dark mode
    text_color_dark = "#eee"                # default is #eee
    content_bg_color_dark = "#121212"       # default is #121212
    post_title_color_dark = "#DBE2E9"       # default is #DBE2E9
    list_color_dark = "#9d9d9d"             # default is #9d9d9d
    link_color_dark = "#268bd2"             # default is #268bd2
    date_color_dark = "#9a9a9a"             # default is #9a9a9a
    table_border_color_dark = "#515151"     # default is #515151
    table_stripe_color_dark = "#202020"     # default is #202020
    code_color = "#bf616a"                  # default is #bf616a
    code_background_color = "#E5E5E5"       # default is #E5E5E5
    code_color_dark = "#ff7f7f"             # default is #ff7f7f
    code_background_color_dark = "#393D47"  # default is #393D47

    # NOTE: If using Remark42 as commenting engine, uncomment and configure these lines
    # remark42 = true
    # remark42_host = "https://yourhost.com"
    # remark42_site_id = "your_site_id"
    
    # NOTE: The following three params are optional and are used to create meta tags + enhance SEO.
    # og_image = ""                       # path to social icon - front matter: image takes precedent, then og_image, then brand_url
                                          # this is also used in the schema output as well. Image is resized to max 1200x630
                                          # For this to work though og_image and brand_url must be a path inside the assets directory
                                          # e.g. /assets/images/site/og-image.png becomes images/site/og-image.png
    # publisher_icon = ""                 # path to publisher icon - defaults to favicon, used in schema

[taxonomies]
    series = 'series'
    tags = 'tags'
{{</highlight >}}

## Custom CSS

You can override any setting in Poison's static CSS files by adding your own `/assets/css/custom.css` file. For example, if you want to override the title font and font size, you could add this:

{{< highlight toml >}}
.sidebar-about h1 {
  font-size: 1.4em;
  font-family: "Monaco", monospace;
}
{{</highlight >}}

## Suggestions / Contributions

Please feel free to add suggestions for new features by opening a new issue in GitHub.  If you like the theme, let us know in the comments below!

A big shout out and *thank you* to these top contributors:

- [Darius Makovsky (traveltissues)](https://github.com/traveltissues)
- [Pierre Bourdon (delroth)](https://github.com/delroth)
- [Karl Austin (KarlAustin)](https://github.com/KarlAustin)
- [Diogo Almeida (Diogo-Almeida3)](https://github.com/Diogo-Almeida3)
- [Ayden Holmes (eyegog)](https://github.com/eyegog)
