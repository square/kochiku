xml.rss({:version => "2.0"}) do
  xml.channel do
    xml.title("Square Build Server RSS Feed")
    xml.link(builds_url)
    xml.language("en")
    xml.ttl(10)
    
    @builds.each do |build|
      xml.item do
        xml.title("Build Number #{build.id} #{build_success_in_words(build)}")
        xml.pubDate(build.created_at.to_s)
        xml.guid(build_url(build))
        xml.link(build_url(build))
      end
    end
  end
end