# frozen_string_literal: true

module Jekyll
module SimpleAssets


def self.hash_length
	config['hash_length'] || 16
end

def self.page_assets_map
	@@page_assets_map ||= {}
end

def self.asset_placeholder_map
	@@asset_placeholder_map ||= {}
end

def self.asset_contenthash_map
	@@asset_contenthash_map ||= {}
end

def self.get_placeholder (asset_path)
	asset_placeholder_map[asset_path] ||= Digest::MD5.base64digest(asset_path)
end

def self.relative_url (path)
	"#{ @@site.config['baseurl'] || '' }/#{ path }".gsub(%r{/{2,}}, '/')
end

class AssetTag < Liquid::Tag
	def initialize (tag_name, text, tokens)
		super
		@text = text
	end

	def get_value (context, expression)
		result = nil

		unless expression.empty?
			lookup_path = expression.split('.')
			result = context
			lookup_path.each do |variable|
				result = result[variable] if result
			end
		end

		case result
		when 'true'
			result = true
		when 'false'
			result = false
		end

		result || expression
	end

	def render (context)
		site = SimpleAssets::site(context.registers[:site])

		page = context.environments.first['page']

		args = Shellwords.split(@text)

		page_path = context['page']['path'].sub(/^\//, '')

		asset_path = get_value(context, args[0]).sub(/^\//, '')

		if SimpleAssets::hashing_enabled?
			SimpleAssets::page_assets_map[page_path] ||= {}
			SimpleAssets::page_assets_map[page_path][asset_path] ||= {}
			SimpleAssets::page_assets_map[page_path][asset_path][@type] ||= []

			placeholder = SimpleAssets::get_placeholder(asset_path)

			unless SimpleAssets::page_assets_map[page_path][asset_path][@type].include? placeholder
				SimpleAssets::page_assets_map[page_path][asset_path][@type] << placeholder
			end

			"#{ @type }::#{ placeholder }"
		else
			if @type == 'path'
				SimpleAssets::relative_url(asset_path)
			else
				placeholder[0, SimpleAssets::hash_length]
			end
		end
	end
end

class PathTag < AssetTag
	def initialize (tag_name, text, tokens)
		super
		@type = 'path'
	end
end

class ContentHashTag < AssetTag
	def initialize (tag_name, text, tokens)
		super
		@type = 'contenthash'
	end
end

def self.resolve_asset_content_hashes (asset, site)
	asset_path = asset.path.sub("#{ site.config['source'] }/", '')

	if File.extname(asset_path) == '.scss'
		asset_path = Pathname.new(asset_path).sub_ext('.css').to_path()
	elsif File.extname(asset_path) == '.ts'
		asset_path = Pathname.new(asset_path).sub_ext('.js').to_path()
	end

	return unless SimpleAssets::asset_placeholder_map[asset_path]
	return if SimpleAssets::asset_contenthash_map[asset_path]

	content = ""

	# Prefer reading from output if available, because in theory should
	# be faster than from disk, but fall back to reading from disk for
	# static assets.
	if asset.respond_to? :output
		content = asset.output
	elsif File.file? asset_path
		content = File.read asset_path
	elsif File.file? asset.path
		content = File.read asset.path
	else
		Jekyll.logger.warn "SimpleAssets:", "File: #{ asset_path } not found"
	end

	if content.nil?
		Jekyll.logger.warn "SimpleAssets:", "#{ asset_path } has no content"
	end

	base64hash = Digest::MD5.base64digest(content)

	hash = base64hash[0, SimpleAssets::hash_length].gsub(/[+\/]/, '_')

	SimpleAssets::asset_contenthash_map[asset_path] = hash
end

def self.replace_placeholders_for_path (page_path, input)
	output = input

	SimpleAssets::page_assets_map[page_path].each do |asset_path, types|
		types.each do |type, placeholders|
			placeholders.each do |placeholder_hash|
				unless SimpleAssets::asset_contenthash_map[asset_path]
					Jekyll.logger.warn "SimpleAssets:", "No contenthash for: #{ asset_path } not found"

					next
				end

				replacement = SimpleAssets::asset_contenthash_map[asset_path]

				if type == 'path'
					replacement = "#{ asset_path }?v=#{ replacement }"

					replacement = SimpleAssets::relative_url(replacement)
				end

				placeholder = "#{ type }::#{ SimpleAssets::asset_placeholder_map[asset_path] }"

				output = output.gsub(placeholder, replacement)
			end
		end
	end

	output
end

def self.replace_placeholders_for_asset (doc, site)
	page_path = doc.path.sub("#{ site.config['source'] }/", '')

	return unless SimpleAssets::page_assets_map[page_path]

	doc.output = SimpleAssets::replace_placeholders_for_path(page_path, doc.output)
end


end
end

Liquid::Template.register_tag('asset', Jekyll::SimpleAssets::PathTag)
Liquid::Template.register_tag('contenthash', Jekyll::SimpleAssets::ContentHashTag)
