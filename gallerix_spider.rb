require 'rest-client'
require 'rubygems'
require 'nokogiri'
require 'fileutils'
require 'SecureRandom'
require 'yaml'


class GallerixSpider
  attr_accessor :pics_folder

  def initialize
    self.pics_folder = File.join(Dir.pwd, "downloaded_pics")
    FileUtils.rm_r self.pics_folder if Dir.exist? self.pics_folder
    Dir.mkdir(self.pics_folder, 777)
  end

  def steal_all_pictures
    t1 = Time.now
    artists = get_artists_list
    # puts artists

    artists.each do |artist_url|
      download_gallery(artist_url)
      # break # !!!!!!!!!!!!!!!!!!!!
    end

    puts "download complete in #{Time.now - t1} sec"
  end

private

  # get the complete list of links to artist galleries
  def get_artists_list
    response = RestClient.get 'http://gallerix.ru/storeroom/'
    # raise "Network ERROR, response code #{response.code}" if response.code != 200

    page = Nokogiri::HTML(response.body)
    artist_urls = []
    page.css("a").each do |a|
      artist_urls << a['href'] if (not (a['href'] =~ /\/storeroom\//).nil?) && ((a['href'] =~ /gallerix/).nil?) && ((a['href'] =~ /letter/).nil?)
    end
    artist_urls.map! do |href|
      href = href[0..-2] if href[-1] == "/"
      "http://gallerix.ru" + href
    end
    return artist_urls.uniq
  end

  # download all the pictures from the artist's gallerry
  def download_gallery(artist_url)
    begin
      puts "artist_url: #{artist_url}"
      response = RestClient.get artist_url
    rescue => ex
      puts "EXCEPTION on getting URL '#{artist_url}'"
      puts ex.backtrace.join("\n")
      return
    end
    # raise "Network ERROR, response code #{response.code} for #{artist_url}" if response.code != 200

    page = Nokogiri::HTML(response.body)
    artist_name = page.css("td[id='n_mainleft']").css('h1')[0].text.rstrip
    validate_file_name(artist_name)
    puts "===#{artist_name}==="
    artist_gallery_path = File.join(self.pics_folder, artist_name)
    Dir.mkdir(artist_gallery_path, 7777)

    artist_id = decode_id(artist_url)
    puts "artist_id: '#{artist_id}"

    pic_page_urls = []
    page.css("td[id='n_mainleft']").css('a').each do |href|
      pic_page_urls << href['href'] if (not (href['href'] =~ /#{artist_id}/).nil?)
    end

    cfg_hash = {}
    cfg_hash["artist"] = artist_name
    pic_page_urls.each do |pic_page_url|
      pic_page_url = pic_page_url[0..-2] if pic_page_url[-1] == "/"
      pic_page_url = "http://gallerix.ru" + pic_page_url if (pic_page_url =~ /http:\/\/gallerix.ru\//) != 0
      download_picture(pic_page_url, artist_gallery_path, cfg_hash)
      # break #!!!!!!!!!!!!!!!!!!!!!!!!!
    end

    file = File.open(File.join(self.pics_folder, artist_name, "gallery_cfg.yaml"), 'w')
    file.write cfg_hash.to_yaml
    file.close
    puts "==================="
  end

  # get artist id from a links like http://gallerix.ru/storeroom/1917286519
  def decode_id(artist_link)
    anchor = artist_link =~ /\/\d+$/
    anchor = artist_link =~ /\/[A-Z]|[a-z]+$/ if anchor.nil?
    id = artist_link[anchor+1..-1]
    return id
  end

  def download_picture(pic_page_url, artist_gallery_path, cfg_hash)
    begin
      puts "   pic_page_url: #{pic_page_url}"
      response = RestClient.get pic_page_url
    rescue => ex
      puts "EXCEPTION on getting URL '#{pic_page_url}'"
      puts ex.backtrace.join("\n")
      return
    end
    # raise "Network ERROR, response code #{response.code} for #{pic_page_url}" if response.code != 200

    page = Nokogiri::HTML(response.body)
    pic_name = page.css("h4[itemprop='caption']").text.rstrip
    # pic_name = validate_file_name(pic_name)
    pic_id = SecureRandom.uuid

    image_id = decode_id(pic_page_url)

    # #full size
    # pic_urls = []
    # page.css("td[id='n_mainleft']").css('a').each do |href|
    #   pic_urls << "http://gallerix.ru" + href['href'] if (not (href['href'] =~ /pic\/.+\/#{image_id}/).nil?)
    # end

    # medium size
    pic_urls = []
    page.css("td[id='n_mainleft']").css('img').each do |img|
      pic_urls << img['src'] if (not (img['src'] =~ /\/#{image_id}/).nil?)
    end

    pic_urls.uniq!
    if pic_urls.size > 1
      puts "error detected, picture URL out of pattern, only 1 expected: #{pic_urls}"
    elsif pic_urls.empty?
      puts "no picture found on URL #{pic_page_url}, skip it"
    else
      pic_url = pic_urls[0]
      puts "   pic_url: #{pic_url}"

      begin
        resp = RestClient.get(pic_url)
        # RestClient.get(pic_url, :user_agent => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36")
      rescue => ex
        puts "EXCEPTION on getting URL '#{pic_url}'"
        puts ex.backtrace.join("\n")
        return
      end
      # raise "Network ERROR, response code #{resp.code} for #{pic_url}" if resp.code != 200
      file = File.open(File.join(artist_gallery_path, "#{pic_id}.jpg"), 'wb' ) do |output|
        output.write resp
      end
      puts "   downloaded: #{pic_name}"
      puts "   -----------"
      cfg_hash[pic_id] = pic_name
    end

  end

  def validate_file_name(pic_name)
    while pic_name.include?":" do
      pic_name.sub!(":", "-")
    end
    pic_name.delete!("/")
    pic_name.delete!("\\")
    pic_name.delete!("*")
    pic_name.delete!("?")
    pic_name.delete!("\"")
    pic_name.delete!("<")
    pic_name.delete!(">")
    pic_name.delete!("|")

    return pic_name
  end
end


gs = GallerixSpider.new
gs.steal_all_pictures