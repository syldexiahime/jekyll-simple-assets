module Jekyll
module SimpleAssets

def self.generate_esbuild_config_file ()
	source_path = Jekyll::SimpleAssets::site.config['source']

	tsconfig_path = File.join(source_path, 'jsconfig.json')
	jsconfig_path = File.join(source_path, 'tsconfig.json')

	config = {}

	if File.file?(tsconfig_path)
		config = JSON.parse(File.read(tsconfig_path))
	elsif File.file?(jsconfig_path)
		config = JSON.parse(File.read(jsconfig_path))
	end

	f = Tempfile.new([ 'jsconfig.esbuild.', '.json' ])

	config['compilerOptions'] = {} unless config['compilerOptions']

	base_url = source_path
	if config['compilerOptions']['baseUrl']
		base_url = File.join(source_path, config['compilerOptions']['baseUrl'])
	end
	config['compilerOptions']['baseUrl'] = Pathname.new(base_url).relative_path_from(Pathname.new(f.path))

	config['compilerOptions']['paths'] = {} unless config['compilerOptions']['paths']

	relative_path = Pathname.new(source_path).relative_path_from(Pathname.new(base_url))

	config['compilerOptions']['paths']['@simple-assets/*'] = [
		File.join(relative_path, '_js/*'),
		File.join(relative_path, '_ts/*'),
	]

	f.write config.to_json
	f.close

	Jekyll::SimpleAssets::esbuild_config_file(f)

	Jekyll.logger.debug("SimpleAssets:", "esbuild: using tsconfig #{ f.path }")
end

def self.esbuild_bundle_file (page, payload, config_path)
	if page.data['bundle'] == false
		return
	end

	bundle_cmd = "npx esbuild --bundle --tsconfig=#{ config_path }"

	if page.data['esbuild_flags']
		bundle_cmd = "#{ bundle_cmd } #{ page.data['esbuild_flags'] }"
	end

	dir = File.dirname(page.path)

	Jekyll.logger.info("SimpleAssets:", 'bundling: ' + page.path)
	Jekyll.logger.debug("SimpleAssets:", 'running command: ' + bundle_cmd)

	Open3.popen3(bundle_cmd, :chdir => dir) do |stdin, stdout, stderr, wait_thr|
		stdin.write(page.output)
		stdin.close

		bundled = stdout.read

		if !wait_thr.value.success? || stderr.read != ''
			Jekyll.logger.error("SimpleAssets:", 'esbuild error:')
			stderr.each do |line|
				Jekyll.logger.error("", line)
			end
		elsif stderr.read != ''
			Jekyll.logger.error("SimpleAssets:", 'esbuild error:')
			stderr.each do |line|
				Jekyll.logger.error("", line)
			end
		end

		page.output = bundled
	end
end

end
end
