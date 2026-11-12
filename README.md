# marten-lucide

[Lucide](https://lucide.dev) icons as inline SVG for [Marten](https://martenframework.com) apps. Pin a release, sync
it once, use the tag:

```html
{% lucide "search" %}
{% lucide "trash-2" size: 20 class: "danger" aria_label: "Delete item" %}
```

No icon font, no JavaScript, no CDN, and no 1,800 SVG files committed to your repository. The release you pin is
downloaded once, checked against its sha256, sanitized, and cached outside the project. At render time an icon is a
hash lookup in memory: no file reads, and never a network request.

Tested against Marten 0.6.4 and 0.7.1 and Crystal 1.19+.

## Installation

Add it to `shard.yml` and run `shards install`:

```yaml
dependencies:
  marten_lucide:
    github: treagod/marten-lucide
```

Require it in `src/project.cr`, and require its management command in `src/cli.cr`:

```crystal
# src/project.cr
require "marten_lucide"

# src/cli.cr
require "marten_lucide/cli"
```

Register the app in `config/settings/base.cr`:

```crystal
config.installed_apps = [
  # ...
  MartenLucide::App,
]
```

## Configuration

Pin an exact Lucide release and the sha256 of its `lucide-icons-<version>.zip`:

```crystal
config.lucide.version = "1.37.0"
config.lucide.sha256 = "d001ff465039224ad2936b5da7876d0549949bf81e648eb3cee50505f35822d8"
```

You can find the digest on the [GitHub release page](https://github.com/lucide-icons/lucide/releases), next to the
`lucide-icons-<version>.zip` asset. `sha256:<hex>` works too, so you can paste it as GitHub shows it. Or run
`marten lucide sync` without one: it downloads the archive, writes nothing, and prints the digest for you to compare
and pin.

The version must be exact. `latest`, `^1.0` and `1.x` are rejected: the icon set changes between releases, and a
floating version would change your pages without a commit.

| Setting | Default | |
|---|---|---|
| `version` | none (required) | Exact Lucide release, e.g. `"1.37.0"` |
| `sha256` | none (required for sync) | Digest of `lucide-icons-<version>.zip` |
| `cache_dir` | see [Cache](#cache) | Where synced versions live |
| `release_url` | GitHub releases | `%{version}` template. Point it at a mirror if GitHub is not reachable. |
| `raise_on_unknown_icon` | `nil`, which raises everywhere except production | See [Unknown icons](#unknown-icons) |

## Syncing icons

```bash
marten lucide sync                    # download, verify, cache; a no-op if already cached
marten lucide sync --force            # do it again anyway
marten lucide sync --archive=PATH     # use a local lucide-icons-<version>.zip instead of downloading
```

Sync checks the archive's sha256 **before** unzipping it. It refuses a mismatch and writes nothing. It then
sanitizes every icon and writes the cache in one atomic rename, so an interrupted run never leaves a cache that looks
complete.

Run it once after cloning, after changing `version`, and in every container build (see below). A `bin/setup` script is
a good place for it.

### Cache

Each version is a single file, `<cache_dir>/<version>.json` (about 370 KB for 1.37.0). Several projects and versions
share one cache without getting in each other's way. The directory is chosen in this order:

1. `config.lucide.cache_dir`
2. the `MARTEN_LUCIDE_CACHE_DIR` environment variable
3. `$XDG_CACHE_HOME/marten-lucide`
4. `~/Library/Caches/marten-lucide` on macOS, `~/.cache/marten-lucide` elsewhere

## Templates

```html
{% lucide "search" %}
{% lucide "search" size: 20 %}
{% lucide "search" size: "1em" stroke_width: 1.5 %}
{% lucide "search" class: "icon icon--muted" color: "#b45309" %}
{% lucide "search" data_controller: "search" data_action: "click->search#open" aria_controls: "results" %}
{% lucide icon_name aria_label: label %}
```

| Option | Renders as | Default |
|---|---|---|
| `size` | `width` and `height` | `24` |
| `stroke_width` | `stroke-width` | `2` |
| `class` | appended to `class="lucide lucide-<name>"` | |
| `color` | `stroke` | `currentColor` |
| `aria_label` | `role="img"`, `aria-label`, `<title>` | decorative (`aria-hidden="true"`) |
| `data_*` | `data-*` (`data_search_target` becomes `data-search-target`) | |
| `aria_*` | `aria-*` (except `aria_hidden`, which the tag manages) | |

Options can be separated by spaces or commas. The icon name and every value can be a literal or any template
expression. A value that resolves to `nil` or `""` leaves its attribute out, so `aria_label: maybe_label` works.
Everything is HTML-escaped. Unknown or repeated options are a template syntax error, raised when the template
compiles.

The output follows Lucide's own SVG attributes, so its CSS conventions apply:

```html
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none"
     stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
     class="lucide lucide-search" aria-hidden="true">…</svg>
```

`color` sets the `stroke` attribute rather than an inline `style`, so pages with a strict Content Security Policy stay
clean. The default `currentColor` follows the surrounding text color, which is usually what you want: color icons
from CSS.

Deprecated names that Lucide still lists as aliases render their current icon. For example, `home` renders `house`.

### Unknown icons

A name that isn't in the pinned release raises `MartenLucide::Errors::UnknownIcon` in development and test, with a
suggestion:

```text
Unknown Lucide icon "serach". Did you mean "search"?
```

In production it logs that message at error level and renders nothing, so one wrong name in a template doesn't turn
a page into a 500. Set `config.lucide.raise_on_unknown_icon = true` if you'd rather it did. A missing sync or a missing
version always raises, in every environment, because that's a broken deployment rather than a bad name.

### From Crystal

```crystal
MartenLucide::Renderer.render("circle-check", size: 18, css_class: "saved", attributes: {"data-turbo" => "false"})
```

It takes the same options as the tag (`css_class` for `class`; `attributes` for `data-*` / `aria-*`).

## Accessibility

- **Decorative by default.** An icon without `aria_label` gets `aria-hidden="true"`. That's right for icons next to
  text that already says the same thing: `{% lucide "trash-2" %} Delete`. Don't label those; screen readers would
  announce "Delete Delete".
- **Label icons that carry meaning on their own**, such as a status or warning shown without text:
  `{% lucide "triangle-alert" aria_label: "Warning" %}`. The icon gets `role="img"`, an `aria-label` and a `<title>`
  (which also shows as a tooltip).
- **Icon-only buttons and links: label the control, not the icon.** The control is what receives focus and gets
  announced:

  ```html
  <button type="button" aria-label="Close dialog">{% lucide "x" %}</button>
  ```

- Icons follow `currentColor`, so they inherit your text contrast. If you set `color`, check its contrast yourself
  (3:1 against the background for meaningful graphics).
- Labels are text: translate them like any other string.

## Containers

Sync during the image build and copy the cache into the runtime image. The running app never needs the network for
icons.

```dockerfile
FROM crystallang/crystal:1.21-alpine AS build
ENV MARTEN_LUCIDE_CACHE_DIR=/app/lucide
# ... install shards, build bin/server and bin/manage ...
RUN bin/manage lucide sync

FROM alpine:3
ENV MARTEN_LUCIDE_CACHE_DIR=/app/lucide
COPY --from=build /app/bin/server /app/server
COPY --from=build /app/lucide/ /app/lucide/
```

Without `MARTEN_LUCIDE_CACHE_DIR` the cache goes to the build user's home (`/root/.cache/marten-lucide` for root),
and copying that directory works just as well. Setting the variable just makes the path explicit. `bin/manage` boots
your settings, so give it whatever placeholder environment your settings require at build time.

The cache lives inside the image, so deploy tools such as Meridian, Kamal or plain Podman/Docker need nothing extra.
Just don't mount a volume over the cache directory. If you'd rather not run the sync in the image build, sync on the
host or in CI and `COPY` the `<version>.json` file in.

### Offline and air-gapped builds

- **No GitHub access:** fetch `lucide-icons-<version>.zip` once, store it wherever your build can reach (an artifact
  store, the build context), and run `marten lucide sync --archive=path/to/lucide-icons-<version>.zip`. It's checked
  against the same pinned sha256.
- **A mirror:** `config.lucide.release_url = "https://mirror.example/lucide/%{version}/lucide-icons-%{version}.zip"`.
- **CI caching:** cache the `MARTEN_LUCIDE_CACHE_DIR` directory keyed on the version, then run the sync (a no-op on a
  cache hit). For example, with GitHub Actions:

  ```yaml
  - uses: actions/cache@v4
    with:
      path: .lucide-cache
      key: lucide-1.37.0
  - run: MARTEN_LUCIDE_CACHE_DIR=.lucide-cache bin/manage lucide sync
  ```

## Testing your app

Templates that render icons need icons, but your specs don't need a sync. Keep the few icons your specs touch as
plain `.svg` files and load them before the suite:

```crystal
# spec/spec_helper.cr
Spec.before_suite { MartenLucide::Registry.use_svg_directory("spec/fixtures/lucide") }
```

They go through the same sanitizer as a sync. Alternatively, run `marten lucide sync` in CI as described above.

## Security

- **Pinned and verified.** An exact version plus a required sha256. The archive is verified before it's parsed.
  Downloads are capped at 50 MB, follow at most 5 redirects and never follow a redirect from HTTPS to HTTP. Zip
  entries are capped (10,000 entries, 64 KB each), and only `icons/<name>.svg` and `icons/<name>.json` are read.
- **Strict sanitizing.** An icon body may contain only self-closing `path`, `circle`, `rect`, `line`, `polyline`,
  `polygon` and `ellipse` elements, with geometry attributes whose values use only letters, digits, spaces and
  `.,-`. Anything else (scripts, event handlers, links, styles, groups, comments, CDATA, entities, text) rejects the
  icon and with it the whole sync. Sanitized icons are rebuilt from the parsed tokens, not copied, and the cache file
  is sanitized again when it's loaded.
- **No network at render time.** Rendering reads only the in-memory set loaded from the cache file. Icon names are
  looked up in a hash and never become file paths.

## Errors

| Error | When |
|---|---|
| `Errors::NotConfigured` | No `version`, or a version that isn't exact |
| `Errors::NotSynced` | The pinned version or sha256 isn't in the cache. Run `marten lucide sync`. |
| `Errors::UnknownIcon` | The name isn't in the pinned release (see [Unknown icons](#unknown-icons)) |
| `Errors::VerificationFailed` | No `sha256` pinned, or the archive doesn't match it |
| `Errors::InvalidIcon` | An icon failed sanitizing |
| `Errors::InvalidArchive` | Not a zip, no icons, or limits exceeded |
| `Errors::DownloadFailed` | HTTP error, unreachable host, too many redirects, HTTPS downgrade |
| `Marten::Template::Errors::InvalidSyntax` | Missing name, unknown or repeated option |

## Example

`example/` is a minimal Marten app that renders a few icons:

```bash
cd example
shards install
crystal run manage.cr -- lucide sync
crystal run src/server.cr   # http://127.0.0.1:8000
```

## Lucide license

The icons are not part of this shard. `marten lucide sync` downloads them from the Lucide project, which publishes
them under the [ISC License](https://github.com/lucide-icons/lucide/blob/main/LICENSE) (parts derived from Feather,
MIT). The ISC License requires its copyright and permission notice to be kept with copies. If you ship Lucide icons,
include that notice with your project's third-party notices.

## Development

```sh
crystal spec
crystal tool format --check src spec
./bin/ameba
```

The specs never touch the network. Sync runs against zips built in memory and a local HTTP server.

Issues and PRs welcome.

## License

MIT.
