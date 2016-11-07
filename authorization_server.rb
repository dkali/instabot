# http://192.168.1.105:8000/secret

require 'webrick'
require 'webrick/https'
require 'json'

server = WEBrick::HTTPServer.new(:Port => 8000)

server.mount_proc('/secret'){ |req, resp|
  resp_hash = {}
  expected_id = "edf7562f1f5a4f27bcf8da570f594dec"

  if not req.query.has_key? "clientID"
    resp_hash["status"] = 1
    resp_hash["reason"] = "mandatory request parameters are missing"
  elsif req.query["clientID"] != expected_id
    resp_hash["status"] = 2
    resp_hash["reason"] = "invalid client ID"
  else
    resp_hash = { "status" => 0,
                  "secret" => "f6eb2ed1543b4de18e1c42d3617822f3" }
  end
  
  resp['Content-Type'] = 'JSON'
  resp.body = JSON.generate(resp_hash)
}

server.start
