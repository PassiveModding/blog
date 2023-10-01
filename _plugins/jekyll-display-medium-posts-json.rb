require 'uri'
require 'net/http'
require 'json'
require 'nokogiri'

module Jekyll
  class JekyllDisplayMediumPosts < Jekyll::Generator
    safe true
    priority :high

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
        description = Nokogiri::HTML(item['description']).search('p').text
        thumbnail = item['thumbnail']
        link = item['link']


        path = "./_posts/#{title.gsub(' ', '-').gsub(/[^\w-]/, '')}.md"
        path = site.in_source_dir(path)

        # Create a new post document
        doc = Jekyll::Document.new(path, { :site => site, :collection => site.collections['posts'] })
        doc.data['title'] = title

        # medium has a list of categories but we only want the first one
        doc.data['category'] = categories[0]
        doc.data['categories'] = categories
        # tags
        doc.data['tags'] = categories

        doc.data['thumbnail'] = thumbnail
        doc.data['link'] = link
        doc.data["image"] = thumbnail
        doc.data['last_modified_at'] = date 
        doc.data['date'] = date 
        
        # set content
        # truncate description to 200 characters and remove all html tags, cut last word, add ...
        description = description[0..200]
        description = description.split[0...-1].join(' ') + '...'
        # add read more and set link to medium post
        description += "\n\n[Read more](#{link})"
        doc.content = description

        # Add the document to the 'posts' collection
        site.collections['posts'].docs << doc
      end
    end
  end
end