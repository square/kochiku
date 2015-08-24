xml.rss({:version => "2.0"}) do
  xml.channel do
    xml.title("Kochiku RSS Feed")
    xml.link(repository_branch_url(@repository, @branch))
    xml.language("en")
    xml.ttl(10)

    @builds.each do |build|
      xml.item do
        xml.title("Build Number #{build.id} #{build_success_in_words(build)}")
        xml.pubDate(build.created_at.to_s)
        xml.guid(repository_build_url(@repository, build))
        xml.link(repository_build_url(@repository, build))
      end
    end
  end
end
