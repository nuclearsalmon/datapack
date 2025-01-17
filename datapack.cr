require "./splay_tree_map"

module Datapack
  # A `Resource` represents a single file. It is a simple structure, composed of four fields.
  struct Resource
    getter namespace : String = "default"
    getter mimetype : String
    getter data : String
    getter path : Path

    def initialize(path, @data, @mimetype = nil)
      @path = Path.new(path)
    end
  end

  class Store
    getter index
    @index = SplayTreeMap(String, SplayTreeMap(String, Array(Path))).new do |s1, k1|
      s1[k1] = SplayTreeMap(String, Array(Path)).new do |s2, k2|
        s2[k2] = [] of Path
      end
    end

    def initialize
      @data = SplayTreeMap(String, SplayTreeMap(Path, Resource)).new do |s, k|
        s[k] = SplayTreeMap(Path, Resource).new
      end
    end

    def parse_key(key : Path)
      if key.parts.first =~ /:$/
        namespace = key.parts.first.rstrip(':')
        actual_key = Path[key.parts[1..-1]]
      else
        namespace = "default"
        actual_key = key
      end
      {namespace: namespace, actual_key: actual_key}
    end

    # Get a value indexed by the given path in the datapack. If the path is prefixed with a
    # namespace:
    #
    # ```
    # namespace:/path/to/file.txt
    # ```
    #
    # The path will be searched for within that namespace. Otherwise, it will be searched
    # for within the `default` namespace.
    def []?(key : Path)
      parsed_key = parse_key(key)
      namespace = parsed_key[:namespace]
      actual_key = parsed_key[:actual_key]

      @data[namespace][actual_key]?
    end

    def [](key : Path)
      parsed_key = parse_key(key)
      namespace = parsed_key[:namespace]
      actual_key = parsed_key[:actual_key]
      
      @data[namespace][actual_key]
    end

    def []?(key : String)
      self[Path.new(key)]?
    end

    def [](key : String)
      self[Path.new(key)]
    end

    # Set a value within the the datapack. As with getting a value, the path can be prefixed
    # with a namespace, and if no namespace is provided, `default` will be used. The value to be
    # stored must be an instance of `Resource`.
    def []=(key : Path, value)
      if key.parts.first =~ /:$/
        namespace = key.parts.first.rstrip(':')
        actual_key = Path[key.parts[1..-1]]
      else
        namespace = "default"
        actual_key = key
      end

      @data[namespace][actual_key] = value

      add_to_index(namespace, actual_key)
    end

    def []=(key : String, value)
      self[Path.new(key)] = value
    end

    private def add_to_index(namespace, key)
      key.each_part do |part|
        @index[namespace][part] << key
      end
    end

    # Find and return an array of all keys which match the key fragment provided as an argument.
    # A key fragment is expressed as a path. Each of the elements of the path will be matched
    # against an index of fragments, and all keys which contain all elements of the key fragment
    # will be returned.
    def find_all_keys(key_fragment : Path)
      parts = key_fragment.parts
      if parts.first =~ /:$/
        namespace = parts.first.rstrip(':')
        actual_parts = parts[1..-1]
      else
        namespace = "default"
        actual_parts = parts
      end
      first = actual_parts.first
      rest = actual_parts[1..-1]?
      r = @index[namespace][first]
      if rest
        rest.each { |part| r = r & @index[namespace][part] }
      end
      r
    end

    def find_all_keys(key_fragment : String)
      find_all(Path.new(key_fragment))
    end

    # Find the first key which matches all of the elements of a key fragment.
    # An exception will be raised if no key is found.
    def find_key(key_fragment : Path)
      find_all_keys(key_fragment).first
    end

    def find_key(key_fragment : String)
      find_key(Path.new(key_fragment))
    end

    # Find the first key which matches all of the elements of a key fragment.
    # A `nil` will be returned if no key is found.
    def find_key?(key_fragment : Path)
      possible_keys = find_all_keys(key_fragment)
      possible_keys.empty? ? nil : possible_keys.first
    end

    def find_key?(key_fragment : String)
      find_key?(Path.new(key_fragment))
    end

    # Return all of the `Resource` values for all keys which match all of the elements of the
    # key fragment.
    def find_all(key_fragment : Path)
      find_all_keys(key_fragment).map { |k| @data[k] }
    end

    def find_all(key_fragment : String)
      find_all_keys(Path.new(key_fragment))
    end

    # Return the `Resource` value for the first key which matches all of the elements of the
    # key fragment. An exception will be raised if no key is found.
    def find(key_fragment : Path)
      if key_fragment.parts.first =~ /:$/
        namespace = key_fragment.parts.first.rstrip(':')
      else
        namespace = "default"
      end
      @data[namespace][find_key(key_fragment)]
    end

    def find(key_fragment : String)
      find(Path.new(key_fragment))
    end

    # Return the `Resource` value for the first key which matches all of the elements of the
    # key fragment. A `nil` will be returned if no key is found.
    def find?(key_fragment : Path)
      if key_fragment.parts.first =~ /:$/
        namespace = key_fragment.parts.first.rstrip(':')
      else
        namespace = "default"
      end

      possible_key = find_key?(key_fragment)
      possible_key.nil? ? nil : @data[namespace][possible_key]
    end

    def find?(key_fragment : String)
      find?(Path.new(key_fragment))
    end
  end

  Data = Store.new

  # The `#add` macro takes a path to a file, and optionally a namespace and a mimetype, and
  # adds it to the datapack. If no namespace is provided, it defaults to the "default"
  # namespace. If no mimetype is provided, the macro will make a modest attempt to apply a
  # correct mimetype, but the macro supports only a very small set of mime-types.
  #
  # The current set of extensions and mime types applied:
  #
  # ```
  # | Extension |            Mime Type            |
  # |-----------|---------------------------------|
  # |    bz2    | application/bzip2               |
  # |    cr     | text/crystal                    |
  # |    css    | text/css; charset=utf-8         |
  # |    csv    | text/csv; charset=utf-8         |
  # |    eot    | application/vnd.ms-fontobject   |
  # |    gif    | image/gif                       |
  # |    gz     | application/gzip                |
  # |    htm    | text/html; charset=utf-8        |
  # |    html   | text/html; charset=utf-8        |
  # |    ico    | image/x-icon                    |
  # |    jpg    | image/jpeg                      |
  # |    jpeg   | image/jpeg                      |
  # |    js     | text/javascript; charset=utf-8  |
  # |    json   | application/json                |
  # |    map    | application/json                |
  # |    otf    | application/font-sfnt           |
  # |    pdf    | application/pdf                 |
  # |    png    | image/png                       |
  # |    rb     | text/ruby                       |
  # |    svg    | image/svg+xml                   |
  # |    tar    | application/tar                 |
  # |    ttf    | application/font-sfnt           |
  # |    txt    | text/plain; charset=utf-8       |
  # |    xml    | text/xml; charset=utf-8         |
  # |    wasm   | application/wasm                |
  # |    webp   | image/webp                      |
  # |    woff   | application/font-woff           |
  # |    woff2  | application/font-woff2          |
  # |    yml    | text/yaml                       |
  # |    yaml   | text/yaml                       |
  # |    zip    | application/zip                 |
  # ```
  #
  macro add(path, namespace = "default", mimetype = nil)
    {% if file_exists? path %}
      {%
        unless mimetype
          mimemap = {
            "bz2"   => "application/bzip2",
            "cr"    => "text/crystal",
            "css"   => "text/css; charset=utf-8",
            "csv"   => "text/csv; charset=utf-8",
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
            "rb"    => "text/ruby",
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
          }

          extension = path.id.split(".").last.downcase
          mimetype = mimemap[extension] || "application/octet-stream"
        end
      %}

      Datapack::Data[Path.new({{ "#{namespace.id}:/#{path.id}" }})] = Datapack::Resource.new(
        path: {{ path }},
        data: {{ read_file(path) }},
        mimetype: {{ mimetype }})
      {% debug if flag?(:DEBUG) %}
    {% end %}
  end

  macro add_path(path, *globs, **options)
    {%
      namespace = options[:namespace] || "default"
      lines = run("./find", path).split("\n")
      files = lines.map(&.split("\t"))
    %}
    {% for file in files %}
      {% unless file[0] == "" %}
        relative_path = \
          Path.new({{ "#{ file[0].id }" }}) \
          .relative_to({{ path }})
        fragment = \
          Path.new({{ namespace }} + ":/#{ relative_path }")
        
        #pp fragment
        #pp relative_path

        Datapack::Data[fragment] = Datapack::Resource.new(
          path: relative_path,
          data: {{ read_file(file[0]) }},
          mimetype: {{ file[1] }})
      {% end %}
    {% end %}
    {% debug if flag?(:DEBUG) %}
  end

  def self.get(path)
    Datapack::Data[Path.new(path)]
  end
end
