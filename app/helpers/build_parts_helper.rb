module BuildPartsHelper
  def basename_with_extension(path)
    File.basename(path)
  end

  def basename_without_extension(path)
    File.basename(path, File.extname(path))
  end
end
