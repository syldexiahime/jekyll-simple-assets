require 'uglifier'

module Jekyll

module SimpleAssets
	def self.symbolize_keys (hash)
		return {} if hash.nil?

		hash.inject({}) do |result, (key, value)|

			new_key = case key
				when String then key.to_sym
				else key
			end
			new_value = case value
				when Hash then symbolize_keys(value)
				else value
			end

			if new_value.is_a?(String) and new_value.match(/^\/.*\/$/)
				new_value = /#{ Regexp.quote(new_value[1..-2]) }/
			end

			result[new_key] = new_value

			result
		end
	end

	module UglifyFilter
		def uglify (input)
			return if input.nil?

			return input.split('\n').join('\\\n') unless SimpleAssets::uglifier_enabled?

			config = @context.registers[:site].config['simple_assets']

			uglifier_config = SimpleAssets::symbolize_keys(config['uglifier'])

			Uglifier.new(uglifier_config).compile input
		end
	end
end

module Converters

class SimpleAssetsUglify < Converter
	safe true
	priority :lowest

	def initialize (config={})
		super(config)

		@config = SimpleAssets::symbolize_keys(config['simple_assets']['uglifier'])

		Jekyll::Hooks.register :pages, :pre_render do |page|
			ext = '.' + page.path.split('.').last

			if matches(ext)
				@meta = SimpleAssets::symbolize_keys(page.data['uglifier'])
			end
		end 

		Jekyll::Hooks.register :pages, :post_render do |page|
			ext = '.' +  page.path.split('.').last

			if matches(ext)
				@meta = nil
			end
		end
	end

	def merge_recursively(a, b)
		a.merge(b) {|key, a_item, b_item| merge_recursively(a_item, b_item) }
	end

	def get_config ()
		merge_recursively(@config || {}, @meta || {})
	end

	def matches (ext)
		return nil unless ext

		ext.downcase == '.js'
	end

	def output_ext (ext)
		'.js'
	end

	def convert (content)
		return content unless SimpleAssets::uglifier_enabled?

		config = get_config

		return content if config[:do_not_compress] == true

		Uglifier.new(config).compile content
	end
end

end
end

Liquid::Template.register_filter(Jekyll::SimpleAssets::UglifyFilter)
