# Changelog

## [0.1.0] - 2026-11-12

Initial release.

### Added

- `{% lucide "name" %}` template tag rendering Lucide icons as inline SVG, with `size`, `stroke_width`, `class`,
  `color`, `aria_label` and `data_*` / `aria_*` pass-through options, separated by spaces or commas.
- Accessible defaults: decorative icons get `aria-hidden="true"`. Labelled icons get `role="img"`, `aria-label` and
  a `<title>`.
- `config.lucide` settings: `version` (exact releases only), `sha256`, `cache_dir`, `release_url`,
  `raise_on_unknown_icon`.
- `marten lucide sync [--force] [--archive=PATH]`: downloads the pinned `lucide-icons-<version>.zip`, verifies its
  sha256 before unzipping, sanitizes every icon with a strict allowlist parser, and writes one atomic per-version
  cache file.
- Deprecated Lucide names render their current icon through the release's alias metadata.
- In-memory icon registry: no file IO or network at render time.
- `MartenLucide::Renderer.render` for rendering from Crystal code.
- `MartenLucide::Registry.use_svg_directory` for application test suites.
- Unknown icons raise with a "did you mean" suggestion outside production. In production they are logged and render
  nothing.
