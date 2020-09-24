# jekyll-simple-assets plugin

[![Gem Version](https://badge.fury.io/rb/jekyll-simple-assets.svg)](https://badge.fury.io/rb/jekyll-simple-assets)

## Usage

This plugin was created to do some simple asset bundling and creating
contenthashes for asset files, rather than needing complex toolchains such as
webpack.

### Tags

#### contenthash

Returns a base64 encoded md5 hash based on the contents of the path given.

```liquid
{% contenthash assets/js/app.js %}
// Mpz5BzLfDInvj7C36UFv4w==
```

#### asset

Returns a relative url to the path given, with a hash based on the content of
the file as a query string.

```liquid
{% asset assets/js/app.js %}
// /assets/js/app.js?v=Mpz5BzLfDInvj7C36UFv4w==
```

#### bundle

Used for bundling js files together, works the same as the include tag, but
looks for the file in the _js folder, and then the _assets folder if not found
there.

```liquid
{% bundle module.js %}
```

#### bundle_raw

The same as bundle, but does not process any liquid inside the file being
bundled.

```liquid
{% bundle module.js %}
```

### Filters

#### md5

Returns an md5 hash of the input string.

```liquid
{{ 'some text' | md5 }}
```

## Content hashes

How the content hashes work is by generating a placeholder string that is
passed to the template. Once all of the sites files and pages have been
processed and copied over, the content hashes are worked out, and the
placeholder string in the pages output is replaced with the hash.

Because of this you need to be careful with using capture tags around or trying
to manipulate the output of the contenthash or asset tags.

By default the generation of content hashes is only enabled for production
builds (if JEKYLL_ENV is set to 'production').

## Critical CSS

This plugin can also be used to generate critical css stylesheets. See
configuration for more information on doing this. To generate critical css,
[critical](https://github.com/addyosmani/critical) must be installed.

## Javascript/Typescript bundling

This plugin can also be used to bundle javascript and typescript files and
modules using esbuild. Node modules can be included just by requiring them.
Local modules can be required under the `@simple-assets` namespace, which
will look for js files in the `_js` and `_ts` directories.

For example:
```javascript
// assets/js/main.js

// require node_module
var leftpad = require('left-pad');

// will look for left-pad.js or left-pad.ts at _js/ or _ts/ in the
// project root
var rightpad = require('@simple-assets/right-pad');
```

You can also put variables in the liquid frontmatter of a js/ts file (that is
not under `_js` or `_ts`) to configure esbuild.

```liquid
---
bundle: false # don't bundle or run esbuild on this file
esbuild_flags: --target=es5 # pass any flags to esbuild for this file
---
```

To bundle javascript [esbuild](https://github.com/evanw/esbuild) must be
installed.

## Configuration

```
simple_assets:
  # If set to true generation of content hashes will be enabled, even in a non
  # production build.
  # default: false
  hashing_enabled: true

  # The length of the content hashes generated.
  # default: 16
  hash_length: 8

  # Options for generating a critical css file using the `critical` npm module
  critical_css:

    # Array of source css files used to take the critical css from
    css_files:
      - assets/css/style.css

    # Array of critical css files to generate
    files:
        # The path of the critical css file output
      - output_file: assets/css/critical.css
	# The path of the input page used to generate the critical css
        # either this option or layout can be used
        input_page_path: _drafts/webmentions-static-site.md
        # The layout to use to generate critical css
        # (will use the first page found with this layout)
        layout: post
        # If the rules should be removed from the original source css files
        extract: true

  # Options for bundling javascript/typescript with the `esbuild` npm module
  # Set to true to enable
  bundle: true
```
