require "file_utils"
require "mime"

# This is an exceptionally simple script that exists only to provide an easy way to
# generate a list of file names and mime types if one is compiling a full directory tree
# of files into the executable.
{
  "bz2"   => "application/bzip2",
  "cr"    => "text/crystal",
  "css"   => "text/css; charset=utf-8",
  "eot"   => "application/vnd.ms-fontobject",
  "gif"   => "image/gif",
  "gz"    => "application/gzip",
  "htm"   => "text/html; charset=utf-8",
  "html"  => "text/html; charset=utf-8",
  "ico"   => "image/x-icon",
  "jpg"   => "image/jpeg",
  "jpeg"  => "image/jpeg",
  "js"    => "text/javascript; charset=utf-8",
  "json"  => "application/json",
  "map"   => "application/json",
  "otf"   => "application/font-sfnt",
  "pdf"   => "application/pdf",
  "png"   => "image/png",
  "svg"   => "image/svg+xml",
  "tar"   => "application/tar",
  "ttf"   => "application/font-sfnt",
  "txt"   => "text/plain; charset=utf-8",
  "xml"   => "text/xml; charset=utf-8",
  "wasm"  => "application/wasm",
  "webp"  => "image/webp",
  "woff"  => "application/font-woff",
  "woff2" => "application/font-woff2",
  "yml"   => "text/yaml",
  "yaml"  => "text/yaml",
  "zip"   => "application/zip",
}.each do |ext, mime|
  MIME.register ".#{ext}", mime
end

path = Path.new(ARGV[0]).to_posix.to_s
globs = ARGV[1..-1]?
globs = ["**/*"] if globs.nil? || (globs && globs.empty?)
globs = globs.map { |glob| File.join(path, glob) }

Dir.glob(globs).each do |file|
  next if File.directory?(file)
  print "#{file}\t#{MIME.from_filename(file, "application/octet-stream")}\n"
end
