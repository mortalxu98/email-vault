# App resources

`BrandIcons/brand-*.pdf` — vector logos extracted from `BrandIcons/_brand_icons.html`.

Regenerate (requires `librsvg2-bin`):

```bash
python3 scripts/extract_brand_icons.py
```

Monochrome marks (Apple/iCloud, X, GitHub, …) are filled black and rendered as template images in `AvatarView` so they adapt to light/dark mode. Wide logos (`okx`, `meta`) use a tighter crop via `PlatformCatalog.wideLogos`.
