# frozen_string_literal: true

module Jekyll
module SimpleAssets


def self.critical_css_source_files
	@@critical_css_source_files ||= []
end

def self.make_temp_css_files_for_critical (asset)
	SimpleAssets::config['critical_css']['css_files'].each do |path|
		next unless asset.path == path || asset.path == path.sub(/\.css$/, '.scss')

		f = Tempfile.new('css-source')
		f.write asset.output
		f.close

		SimpleAssets::critical_css_source_files << { 'file' => f, 'page' => asset }
	end
end

def self.get_html_input_for_critical (doc, site)
	SimpleAssets::config['critical_css']['files'].each do |file|
		page_path = doc.path.sub("#{ site.config['source'] }/", '')

		next unless page_path == file['input_page_path']

		file['html'] = doc.output
	end
end

def self.generate_critical_css (site)
	css_files_str = ''

	SimpleAssets::critical_css_source_files.each do |f|
		css_files_str += "--css #{ f['file'].path } "
	end

	SimpleAssets::config['critical_css']['files'].each do |file|
		css_path = File.join(site.config['destination'], file['output_file'])

		html = file['html']

		critical_cmd = "npx critical #{ css_files_str }"

		Jekyll.logger.debug("SimpleAssets:", "Running command: #{ critical_cmd }")

		Open3.popen3(critical_cmd) do |stdin, stdout, stderr, wait_thr|
			stdin.write(html)
			stdin.close

			err = stderr.read
			unless wait_thr.value.success?
				Jekyll.logger.error("SimpleAssets:", 'Critical:' + err || stdout.read)

				next
			else
				Jekyll.logger.warn("SimpleAssets:", 'Critical:' + err) if err
			end

			critical_css = stdout.read

			asset_path = file['output_file'].sub(/^\//, '')

			base64hash = Digest::MD5.base64digest(critical_css)

			hash = base64hash[0, SimpleAssets::hash_length].gsub(/[+\/]/, '_')

			SimpleAssets::asset_contenthash_map[asset_path] = hash

			IO.write(css_path, critical_css)

			site.keep_files << asset_path
		end
	end
end

def self.resolve_critical_css_content_hashes (site)
	SimpleAssets::critical_css_source_files.each do |source_file|
		page = source_file['page']
		page_path = page.path.sub("#{ site.config['source'] }/", '')

		page.output = IO.read(source_file['file'].path)

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
