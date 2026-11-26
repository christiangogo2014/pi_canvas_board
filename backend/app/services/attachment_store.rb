# Stores uploaded attachments on disk under the persisted data volume.
module AttachmentStore
  ROOT = Pathname.new(ENV.fetch("ATTACHMENTS_DIR", Rails.root.join("data/attachments")))

  def self.save(pi_id, upload)
    dir = ROOT.join(pi_id)
    FileUtils.mkdir_p(dir)
    filename = File.basename(upload.original_filename.to_s).gsub(/[^\w.\- ]/, "_")
    filename = "file_#{Time.current.to_i}" if filename.blank?
    target = unique_path(dir.join(filename))
    File.binwrite(target, upload.read)
    target.basename.to_s
  end

  def self.path_for(pi_id, filename)
    ROOT.join(pi_id.to_s, File.basename(filename.to_s))
  end

  def self.delete(pi_id, filename)
    path = path_for(pi_id, filename)
    File.delete(path) if File.exist?(path)
  end

  private

  def self.unique_path(path)
    return path unless File.exist?(path)
    ext = path.extname
    base = path.sub_ext("")
    n = 1
    n += 1 while File.exist?(base.sub_ext("_#{n}#{ext}"))
    base.sub_ext("_#{n}#{ext}")
  end
end
