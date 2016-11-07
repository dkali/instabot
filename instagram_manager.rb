require 'rest-client'
require 'json'
require 'selenium-webdriver'
require 'yaml'
require 'uri'
require 'cgi'

class InstagramManager
  attr_accessor :client_id, :redirect_uri, :token, :cfg, :cfg_path
  attr_accessor :credentials_server_url

  INSTAPI = "https://api.instagram.com/v1"

  def initialize
    cfg_file = "#{File.dirname(__FILE__)}/cfg.yaml"
    raise "ERROR: config file is missed" if (not File.exist?(cfg_file))
    self.cfg_path = "#{File.dirname(__FILE__)}/cfg.yaml"
    self.cfg = YAML::load(File.open(self.cfg_path))
    
    self.client_id = "edf7562f1f5a4f27bcf8da570f594dec"
    self.credentials_server_url = "http://192.168.1.105:8000"
    self.redirect_uri = "http://127.0.0.1"
    self.token = self.cfg["token"]
  end

  def get_secret
    # return "f6eb2ed1543b4de18e1c42d3617822f3"
    resp = RestClient.get "#{self.credentials_server_url}/secret", {params: {clientID: self.client_id}}
    j = JSON.parse(resp.body)

    raise "ERROR: credentials server has returned ErrorCode #{j["status"]}: #{j["reason"]}" if j["status"] != 0
    return j["secret"]
  end

  # OAuth2.0
  # @param [Symbol] arg
  def authentication_explicit(arg = nil)
    if self.token.nil? || arg == :renew_token
      driver = Selenium::WebDriver.for :chrome
      driver.manage.timeouts.implicit_wait = 3 # seconds
      # puts driver.public_methods(true)

      login_into_instagram(driver)
      code = authorize_app(driver)
      obtain_token(code)

      driver.quit
    end
  end

  def get_self
    call_instagram_api{ 
                        resp = RestClient.get "#{INSTAPI}/users/self", {params: {access_token: self.token}}
                        JSON.parse(resp.body)["data"]
                      }
  end

  def get_user_info(id)
    call_instagram_api{
                        resp = RestClient.get "#{INSTAPI}/users/#{id}", {params: {access_token: self.token}}
                        JSON.parse(resp.body)["data"]
                      }
  end

  # while in sandbox mode functionaluty is limited to approved sandbox user list
  def get_followed_by
    call_instagram_api{
                        resp = RestClient.get "#{INSTAPI}/users/self/followed-by", {params: {access_token: self.token}}
                        JSON.parse(resp.body)["data"]
                      }
  end

  def get_users_recent_media(user_id)
    call_instagram_api{
                        resp = RestClient.get "#{INSTAPI}/users/#{user_id}/media/recent", {params: {access_token: self.token}}
                        JSON.parse(resp.body)["data"]
                      }
  end

  def post_like(media_id)
    call_instagram_api{
                        resp = RestClient.post "#{INSTAPI}/media/#{media_id}/likes", {access_token: self.token}
                        JSON.parse(resp.body)["data"]
                      }
  end

  # decorator for API calls, to track down outdated token
  def call_instagram_api
    begin
      return yield
    rescue => e
      puts "Exception rescued: #{e}"
      # renew token
      self.authentication_explicit(:renew_token)

      # try again
      return yield
    end
  end

private
  # @param [Selenium::WebDriver] driver
  def login_into_instagram(driver)
    driver.navigate.to "https://www.instagram.com/"
    puts "1: #{driver.current_url}"

    element = driver.find_element(:name, 'username')
    element.send_keys self.cfg["login"]

    element = driver.find_element(:name, 'password')
    element.send_keys self.cfg["pswd"]

    element.submit
    # wait fo page loaded
    driver.find_elements(:xpath, "//*[@href='/#{self.cfg["login"]}/']")
  end

  # @param [Selenium::WebDriver] driver
  def authorize_app(driver)
    driver.navigate.to "https://api.instagram.com/oauth/authorize/?client_id=#{self.client_id}&redirect_uri=#{self.redirect_uri}&response_type=code&scope=basic+public_content+follower_list+comments+relationships+likes"
    puts "2: #{driver.current_url}"

    if (not driver.current_url.include?("/?code"))
      # authorize app
      el = driver.find_element(:xpath, "//*[@name='allow' and @value='Authorize']")
      el.click
      puts "3: #{driver.current_url}"
    end
    
    # we authorized, grab the code
    uri = URI(driver.current_url)
    params = CGI::parse(uri.query)
    return params["code"].first
  end

  # @param [String] code - OAuth2.0 code
  def obtain_token(code)
    access_token_endpoint = "https://api.instagram.com/oauth/access_token"
    resp = RestClient.post access_token_endpoint, {client_id: self.client_id,
                                                   client_secret: get_secret,
                                                   grant_type: "authorization_code",
                                                   redirect_uri: self.redirect_uri,
                                                   code: code}
    j = JSON.parse(resp.body)
    self.token = j["access_token"]
    
    # save token to NVM
    self.cfg["token"] = j["access_token"]
    file = File.open(self.cfg_path, 'w')
    file.write self.cfg.to_yaml
    file.close
  end
end