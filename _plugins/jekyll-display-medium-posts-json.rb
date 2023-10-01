require 'uri'
require 'net/http'
require 'json'
require 'nokogiri'

module Jekyll
  class JekyllDisplayMediumPosts < Jekyll::Generator
    safe true
    priority :high

def thumb_b64(thumbnail)  
  ext = thumbnail.split('.')[-1]

  # download thumbnail and convert to base64
  # follow redirects if necessary
  while true
    uri = URI(thumbnail)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.code == '301'
      thumbnail = "#{uri.scheme}://#{uri.host}#{response['location']}"
      puts "redirecting to #{thumbnail}"
    else
      break
    end
  end

  # convert image to base64
  thumb_b64 = Base64.encode64(response.body)
  thumb_b64 = "data:image/#{ext};base64,#{thumb_b64}"

  return thumb_b64
end

def generate(site)
      uri = URI("https://api.rss2json.com/v1/api.json?rss_url=https://medium.com/feed/@jaquesy")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      data = JSON.parse(response.read_body)

      data['items'].each do |item|
        title = item['title']
        
        date_str = item['pubDate']
        date = Time.parse(date_str)
        
        categories = item['categories']
        thumbnail = item['thumbnail']
        link = item['link']


        path = "./_posts/#{title.gsub(' ', '-').gsub(/[^\w-]/, '')}.md"
        path = site.in_source_dir(path)

        # Create a new post document
        doc = Jekyll::Document.new(path, { :site => site, :collection => site.collections['posts'] })
        doc.data['title'] = title
        doc.data['layout'] = 'post'
        doc.data['tags'] = categories
        doc.data['last_modified_at'] = date 
        doc.data['date'] = date 
        doc.data['link'] = link
        
        # download thumbnail and convert to base64
        thumb_b64_str = thumb_b64(thumbnail)
        doc.data["image"] = {
          "path" => thumbnail,
          "alt" => title,
          "lqip" => thumb_b64_str
        }
        

        # Set the document's content to the post's content

        description = item['description']
        # prepend description saying that the original post is on Medium
        description = "<p>Originally published on <a href=\"#{link}\">Medium</a></p>" + description
        doc.content = description

        # Add the document to the 'posts' collection
        site.collections['posts'].docs << doc
      end
    end
  end
end