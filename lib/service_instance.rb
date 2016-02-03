# This module is intended to be mixed into SolrWrapper::Instance and FcrepoWrapper::Instance
module ServiceInstance
  def env
    options.fetch(:env, {})
  end

  def binary_path
    raise NotImplementedError, "Implement binary_path in a subclass"
  end

  def default_download_url
    raise NotImplementedError, "Implement default_download_url in a subclass"
  end

  def default_instance_dir
    raise NotImplementedError, "Implement default_instance_dir in a subclass"
  end

  def md5url
    raise NotImplementedError, "Implement md5url in a subclass"
  end

  def download_path
    @download_path ||= options.fetch(:download_path, default_download_path)
  end

  def default_download_path
    File.join(Dir.tmpdir, File.basename(download_url))
  end

  def download_url
    @download_url ||= options.fetch(:url, default_download_url)
  end


  def verbose?
    !!options.fetch(:verbose, false)
  end

  def instance_dir
    @instance_dir ||= options.fetch(:instance_dir, default_instance_dir)
  end

  def extracted?
    File.exists?(binary_path) && extracted_version == version
  end

  def extracted_version
    File.read(version_file).strip if File.exists? version_file
  end

  def extracted_version=(version)
    File.open(version_file, "w") do |f|
      f.puts version
    end
  end

  def version_file
    options.fetch(:version_file, File.join(instance_dir, "VERSION"))
  end

  def expected_md5sum
    @md5sum ||= options.fetch(:md5sum, open(md5file).read.split(" ").first)
  end

  ##
  # Is the service running?
  def started?
    !!status
  end

  def download
    unless File.exists?(download_path) && validate?(download_path)
      fetch_with_progressbar download_url, download_path
      validate! download_path
    end

    download_path
  end

  def validate?(file)
     return true if options[:validate] == false
    Digest::MD5.file(file).hexdigest == expected_md5sum
  end

  def validate!(file)
    unless validate? file
      raise "MD5 mismatch" unless options[:ignore_md5sum]
    end
  end

  ##
  # Clean up any files fcrepo_wrapper may have downloaded
  # TODO: if this is used for solr_wrapper, we also need to remove tmp_save_dir
  def clean!
    stop
    remove_instance_dir!
    FileUtils.remove_entry(download_path) if File.exists? download_path
    FileUtils.remove_entry(md5sum_path) if File.exists? md5sum_path
    FileUtils.remove_entry(version_file) if File.exists? version_file
  end

  ##
  # Clean up any files in the Solr instance dir
  def remove_instance_dir!
    FileUtils.remove_entry(instance_dir, true) if File.exists? instance_dir
  end

  def fetch_with_progressbar(url, output)
    pbar = ProgressBar.create(title: File.basename(url), total: nil, format: "%t: |%B| %p%% (%e )")
    open(url, content_length_proc: lambda do|t|
      if t && 0 < t
        pbar.total = t
      end
    end,
              progress_proc: lambda do|s|
                pbar.progress = s
              end) do |io|
      IO.copy_stream(io, output)
    end
  end

  def md5file
    unless File.exists? md5sum_path
      fetch_with_progressbar md5url, md5sum_path
    end

    md5sum_path
  end

  def md5sum_path
    File.join(Dir.tmpdir, File.basename(md5url))
  end
end
