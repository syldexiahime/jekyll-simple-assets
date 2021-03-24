require 'fileutils'
require 'terser'

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

	def self.merge_recursively(a, b)
		a.merge(b) {|key, a_item, b_item| SimpleAssets::merge_recursively(a_item, b_item) }
	end

	def self.should_minify_file? (page)
		return false unless page.respond_to? :output
		return false unless SimpleAssets::terser_enabled?
		return false if page.data['do_not_compress'] == true
		return true
	end

	def self.minify_file (page)
		return unless SimpleAssets::should_minify_file?(page)

		site_config = symbolize_keys(SimpleAssets::site.config['simple_assets']['terser'])
		page_config = symbolize_keys(page.data['terser'])

		config = SimpleAssets::merge_recursively(site_config || {}, page_config || {})

		map_path = page.path + '.map'
		if SimpleAssets::source_maps_enabled?
			config = SimpleAssets::merge_recursively(config, {
				:source_map => { :filename => page.path[/[^\/]*$/], :url => true },
			})

			minified, source_map = Terser.new(config).compile_with_map(page.output)
		else
			minified = Terser.new(config).compile(page.output)
		end

		min_path = page.path.sub(/\.(j|t)s$/i, '.min.js')
		Jekyll.logger.info("SimpleAssets:", 'minified: ' + min_path)

		if source_map
			File.write(File.join(SimpleAssets::site.config['destination'], map_path), source_map)
			minified = minified.gsub(/^\/\/#\s*?source(Mapping)?URL=.*$/, '')
			minified += "\n//# sourceMappingURL=#{ SimpleAssets::relative_url(map_path) }"

			Jekyll.logger.debug("SimpleAssets:", 'created source map: ' + map_path)

			SimpleAssets::site.config['keep_files'] << map_path
		end

		if SimpleAssets::page_assets_map[page.path]
			SimpleAssets::page_assets_map[min_path] = SimpleAssets::page_assets_map[page.path]
		end

		SimpleAssets::site.config['keep_files'] << min_path

		return min_path, minified
	end

	module UglifyFilter
		def uglify (input)
			return if input.nil?

			return input.split('\n').join('\\\n') unless SimpleAssets::terser_enabled?

			config = @context.registers[:site].config['simple_assets']

			terser_config = SimpleAssets::symbolize_keys(config['terser'])

			Terser.new(terser_config).compile(input)
		end
	end
end

end

Liquid::Template.register_filter(Jekyll::SimpleAssets::UglifyFilter)
