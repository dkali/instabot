require "#{File.dirname(__FILE__)}/instagram_manager.rb"

im = InstagramManager.new
im.authentication_explicit

pronin_id = 5876503

media_list = im.get_users_recent_media(pronin_id)

ids = []
media_list.each do |media|
  puts "media: #{media["id"]}, liked? #{media["user_has_liked"]}"
  if media["user_has_liked"] == false
    puts "send like to #{media["id"]}"
    im.post_like(media["id"])
  end
end
