# SERP brand assets

The source of truth is [`source/serp-arrow.svg`](source/serp-arrow.svg), copied from the maintainer-owned file below with only a terminal newline normalized:

`/Users/devin/Brands/SERP/SERP - SVG/serp-arrow.svg`

The supplied `favicon.svg` and 1024px transparent PNG were also reviewed. They contain the same black arrow geometry; the standalone SVG was selected as the canonical derivation input so all raster sizes remain reproducible.

The source checksum is pinned in `scripts/generate-brand-assets.sh`. The script uses ImageMagick to place the black SERP arrow on an opaque white 1024×1024 field, then produces the complete macOS AppIcon raster set and the 1024×1024 App Store icon. The menu-bar and in-app marks retain the approved vector path and use template rendering so macOS supplies the correct light/dark foreground.

Run from the repository root:

~~~sh
scripts/generate-brand-assets.sh
~~~

No Keylume, Gitify, HeyClicky, OpenClicky, or other third-party identity asset is included.
