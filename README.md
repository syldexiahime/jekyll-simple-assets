# jekyll-simple-assets plugin

[![Gem Version](https://badge.fury.io/rb/jekyll-simple-assets.svg)](https://badge.fury.io/rb/jekyll-simple-assets)

## Usage

This plugin was created to do some simple asset bundling and creating
contenthashes for asset files, rather than needing complex toolchains such as
webpack.

### Tags

#### contenthash

Returns an (md5) hash based on the contents of the path given.

```liquid
{% contenthash assets/js/app.js %}
// 329CF90732DF0C89EF8FB0B7E9416FE3
```

#### asset

Returns a relative url to the path given, with a hash based on the content of
the file as a query string.

```liquid
{% asset assets/js/app.js %}
// /assets/js/app.js?v=329CF90732DF0C89EF8FB0B7E9416FE3
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
