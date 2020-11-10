# frozen_string_literal: true

require 'css_parser'
require 'tempfile'

module Jekyll
module SimpleAssets


def self.critical_css_source_files ()
	@@critical_css_source_files ||= {}
end

def self.make_temp_css_files_for_critical (asset)
	SimpleAssets::config['critical_css']['css_files'].each do |path|
		next unless asset.path == path || asset.path == path.sub(/\.css$/, '.scss')

		f = Tempfile.new([ 'css-source', '.css' ])
		f.write asset.output
		f.close

		Jekyll.logger.debug("SimpleAssets:", "Created new temp file for css: #{ asset.path } at: #{ f.path }")

		SimpleAssets::critical_css_source_files[path] = { 'file' => f, 'page' => asset }
	end
end

def self.get_html_input_for_critical (doc, site)
	return unless doc.respond_to? '[]'

	SimpleAssets::config['critical_css']['files'].each do |file|
		next if file['html']

		page_path = doc.path.sub("#{ site.config['source'] }/", '')

		next unless page_path == file['input_page_path'] || file['layout'] == doc['layout']

		file['html'] = doc.output
	end
end

def self.generate_critical_css (site)
	css_files_str = ''

	SimpleAssets::critical_css_source_files.each do |_, f|
		css_files_str += "--css #{ f['file'].path } "

		f['css'] = CssParser::Parser.new
		f['css'].load_string! f['page'].output
	end

	SimpleAssets::config['critical_css']['files'].each do |file|
		css_path = File.join(site.config['destination'], file['output_file'])

		html = file['html']

		critical_cmd = "npx critical #{ css_files_str }"

		Jekyll.logger.debug("SimpleAssets:", "Running command: #{ critical_cmd }")

		Open3.popen3(critical_cmd) do |stdin, stdout, stderr, wait_thr|
			stdin.write(html)
			stdin.close

			if !wait_thr.value.success? || stderr.read != ''
				Jekyll.logger.error("SimpleAssets:", 'Critical (css) error:')
				stderr.each do |line|
					Jekyll.logger.error("", line)
				end
			elsif stderr.read != ''
				Jekyll.logger.error("SimpleAssets:", 'Critical (css) error:')
				stderr.each do |line|
					Jekyll.logger.error("", line)
				end
			end

			critical_css_str = stdout.read

			asset_path = file['output_file'].sub(/^\//, '')

			base64hash = Digest::MD5.base64digest(critical_css_str)

			hash = base64hash[0, SimpleAssets::hash_length].gsub(/[+\/]/, '_')

			SimpleAssets::asset_contenthash_map[asset_path] = hash

			IO.write(css_path, critical_css_str)

			site.keep_files << asset_path

			if file['extract']
				critical_css = CssParser::Parser.new

				critical_css.load_string! critical_css_str

				SimpleAssets::critical_css_source_files.each do |_, f|
					f['css'].each_rule_set do |source_rule_set, source_media_type|
						critical_css.each_rule_set do |critical_rule_set, critical_media_type|
							if critical_rule_set.selectors.join(',') == source_rule_set.selectors.join(',')
								f['css'].remove_rule_set! source_rule_set, source_media_type
								f['extract'] = true

								break
							end
						end
					end
				end
			end
		end
	end

	SimpleAssets::critical_css_source_files.each do |_, f|
		leftover_css = f['css'].to_s if f['extract']

		# css_parser leaves blank keyframes so fix them
		keyframes = f['page'].output.scan(/@keyframes\s+(?:.*?)\s*{(?:\s*\S*?\s*{.*?}\s*)+}/m)
		keyframes.each { |keyframe| leftover_css += keyframe }

		f['page'].output
	end
end

def self.resolve_critical_css_content_hashes (site)
	SimpleAssets::critical_css_source_files.each do |_, source_file|
		page = source_file['page']
		page_path = page.path.sub("#{ site.config['source'] }/", '')

		SimpleAssets::config['critical_css']['files'].each do |file|
			css_path  = File.join(site.config['destination'], file['output_file'])
			content = IO.read(css_path)

			critical = SimpleAssets::replace_placeholders_for_path(page_path, content)

			IO.write(css_path, critical)
		end
	end
end


end
end
