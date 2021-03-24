# frozen_string_literal: true

require 'digest'
require 'pathname'
require 'open3'
require 'shellwords'

require 'jekyll-simple-assets/content-hash'
require 'jekyll-simple-assets/critical'
require 'jekyll-simple-assets/esbuild'
require 'jekyll-simple-assets/terser'

module Jekyll
	module SimpleAssets
		def self.site (site = nil)
			@@site = site if site

			@@site
		end

		def self.config
			@@config ||= @@site.config['simple_assets']
		end

		def self.hashing_enabled?
			config['hashing_enabled'] || ENV['JEKYLL_ENV'] == 'production'
		end

		def self.critical_css_enabled?
			config.key?('critical_css')
		end

		def self.esbuild_enabled?
			config.key?('bundle') && config['bundle'] != false
		end

		def self.esbuild_config_file (file = nil)
			@@esbuild_config_file ||= file
		end

		def self.terser_enabled?
			config['terser_enabled'] || ENV['JEKYLL_ENV'] == 'production'
		end

		def self.source_maps_enabled?
			config['source_maps_enabled']
		end

		module SimpleAssetsFilters
			def md5 (input)
				Digest::MD5.hexdigest(input)
			end
		end

		class BundleTag < Jekyll::Tags::IncludeTag
			def tag_includes_dirs(context)
				[ "_js", "_javascript", "_assets" ].freeze
			end
		end

		class BundleRawTag < Jekyll::Tags::IncludeTag
			def tag_includes_dirs(context)
				[ "_js", "_javascript", "_assets" ].freeze
			end

			def render(context)
				site = context.registers[:site]

				file = render_variable(context) || @file
				validate_file_name(file)

				path = locate_include_file(context, file, site.safe)
				return unless path

				add_include_to_dependency(site, path, context)

				return unless File.file? path

				content = File.read path

				content
			end
		end
	end
end

Liquid::Template.register_tag('bundle', Jekyll::SimpleAssets::BundleTag)
Liquid::Template.register_tag('bundle_raw', Jekyll::SimpleAssets::BundleRawTag)

Liquid::Template.register_filter(Jekyll::SimpleAssets::SimpleAssetsFilters)

Jekyll::Hooks.register :site, :post_render, priority: :low do |site, payload|
	Jekyll::SimpleAssets::site(site)

	potential_assets = []

	potential_assets += site.pages
	potential_assets += site.static_files

	potential_pages = potential_assets

	site.collections.each do |collection_name, collection|
		potential_pages = potential_pages + collection.docs
	end

	if Jekyll::SimpleAssets::critical_css_enabled?
		potential_assets.each do |asset|
			Jekyll::SimpleAssets::make_temp_css_files_for_critical(asset)
		end

		potential_pages.each do |doc|
			Jekyll::SimpleAssets::get_html_input_for_critical(doc, site)
		end

		Jekyll::SimpleAssets::generate_critical_css(site)
	end

	if Jekyll::SimpleAssets::hashing_enabled?
		potential_assets.each do |asset|
			Jekyll::SimpleAssets::resolve_asset_content_hashes(asset, site)
		end

		if Jekyll::SimpleAssets::critical_css_enabled?
			Jekyll::SimpleAssets::resolve_critical_css_content_hashes(site)
		end

		potential_pages.each do |doc|
			page_path = doc.path.sub("#{ site.config['source'] }/", '')

			if Jekyll::SimpleAssets::page_assets_map[page_path]
				doc.output = Jekyll::SimpleAssets::replace_placeholders_for_path(page_path, doc.output)
			end

			if doc.extname =~ /^\.(j|t)s$/i and Jekyll::SimpleAssets::should_minify_file?(doc)
				min_path, minified = Jekyll::SimpleAssets::minify_file(doc)

				if min_path and Jekyll::SimpleAssets::page_assets_map[page_path]
					minified = Jekyll::SimpleAssets::replace_placeholders_for_path(page_path, minified)
				end

				File.write(File.join(Jekyll::SimpleAssets::site.config['destination'], min_path), minified)
			end
		end
	end
end

Jekyll::Hooks.register :pages, :post_render do |page, payload|
	unless Jekyll::SimpleAssets::esbuild_config_file
		Jekyll::SimpleAssets::generate_esbuild_config_file()
	end

	if page.extname =~ /^\.(j|t)s$/i
		if Jekyll::SimpleAssets::esbuild_enabled?
			Jekyll::SimpleAssets::esbuild_bundle_file(page, payload, Jekyll::SimpleAssets::esbuild_config_file.path)
		end

		if Jekyll::SimpleAssets::should_minify_file?(page)
			min_path = page.path.sub(/\.(j|t)s$/i, '.min.js')
			File.write(File.join(Jekyll::SimpleAssets::site.config['destination'], min_path), '')
		end
	end
end

Jekyll::Hooks.register :site, :post_read do |site|
	css_pages = [];

	site.pages.each do |doc|
		if doc.extname == '.scss'
			css_pages << doc
			site.pages = site.pages - [ doc ]
		end
	end

	site.pages = css_pages + site.pages
end

# Jekyll::Hooks.register :pages, :post_render do |document|
# 	puts 'rendered:' + document.path
# end

