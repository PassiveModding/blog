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
        description = "<h2>Originally published on <a href=\"#{link}\">Medium</a></h2>" + description

        # update pre tags to use highlight tag, making sure to add newlines to the end of each line
        # use rules to detect the language of the code or default to text
        # medium doesn't use <code blocks
        description = description.gsub(/<pre>(.*?)<\/pre>/m) do |match|
          code = $1

          # detect language
          language = nil
          code = code.gsub(/<br>/, "\n")
          # fix less than and greater than
          code = code.gsub(/&lt;/, "<")
          code = code.gsub(/&gt;/, ">")
          if code.include?('<code class="language-')
            language = code.match(/<code class="language-(.*?)"/)[1]
          else
            if code.match(/(using|public class|public static void Main|namespace)/m) || code.match(/var.+ = new/m)
              language = 'csharp'
            # match csproj
            elsif code.match(/\<Project Sdk=\"Microsoft.NET.Sdk\"\>/m)
              language = 'xml'
            # match <script> tags
            elsif code.match(/\<script/m)
              language = 'javascript'
            # match <style> tags
            elsif code.match(/\<style/m)
              language = 'css'
            # match <html> tags
            elsif code.match(/\<html/m)
              language = 'html'
            elsif code.match(/public static void main|public class/m)
              language = 'java'
            elsif code.match(/\<\?php/m)
              language = 'php'
            # line starting with cd, curl, ls, mkdir, mv, rm, touch, wget, dotnet add, gcloud, kubectl, az
            elsif code.match(/^(cd|curl|ls|mkdir|mv|rm|touch|wget|dotnet add|gcloud|kubectl|az)/m)
              language = 'bash'
            end
          end

          # if language is still nil, default to text
          if language.nil?
            language = 'text'
          end

          # now that we have the language, we can wrap the code in { % highlight <language> % }
          code = "{% highlight #{language} %}\n#{code}\n{% endhighlight %}"
        end

        doc.content = description

        # Add the document to the 'posts' collection
        site.collections['posts'].docs << doc
      end
    end
  end
end