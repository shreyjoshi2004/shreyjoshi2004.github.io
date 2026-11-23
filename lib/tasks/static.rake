# Renders the app to plain files in dist/ for static hosting (GitHub Pages).
# Usage: RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile static:build
namespace :static do
  desc "Render routes and copy public/ into dist/"
  task build: :environment do
    dist = Rails.root.join("dist")
    FileUtils.rm_rf(dist)
    FileUtils.mkdir_p(dist)
    FileUtils.cp_r(Rails.public_path.children, dist)

    pages = { "/" => "index.html" }
    request = Rack::MockRequest.new(Rails.application)
    pages.each do |path, file|
      response = request.get(path, "HTTPS" => "on", "HTTP_HOST" => "shreyjoshi.com")
      abort "static:build: GET #{path} returned #{response.status}" unless response.status == 200
      File.write(dist.join(file), response.body)
    end
    puts "Wrote #{pages.size} page(s) and public/ to #{dist}"
  end
end
