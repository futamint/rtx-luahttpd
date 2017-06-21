--
-- rtx-luahttpd (for YAMAHA RTX Series)
--
-- Copyright (C) futamint
--

local host = "192.168.100.1"
local port = 11111

local debug = nil
--local debug = true

local http_status = {
  [200] = "OK",
  [400] = "Bad Request",
  [401] = "Unauthorized",
  [403] = "Forbidden",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [500] = "Internal Server Error",
  [502] = "Bad Gateway",
  [503] = "Service Unavailable"
}

-- LAN1のインターフェースIPアドレスを返す
local function getLocalAddress(host)
  local rtn, str = rt.command("show status lan1 | grep IP")
  if rtn then
    return string.match(str, "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\/[0-9]+")
  end
  return host
end

-- 初期化
local function init()
  local tcp = rt.socket.tcp()
  tcp:setoption("reuseaddr", true)

  local res, err = tcp:bind(getLocalAddress(host), port)
  if not res and err then
    print(err)
    os.exit(1)
  end
  if debug then
    print("tcp bind success. host:" .. host .. " port:" .. port)
  end

  local res, err = tcp:listen()
  if not res and err then
    print(err)
    os.exit(1)
  end
  if debug then
    print("tcp listen ready.")
  end

  return tcp
end

-- リクエスト受信
local function receive(tcpc)
  -- 1行目だけ読むんじゃよ
  line, err = tcpc:receive()
  if err then
    print("receive error(" .. err .. ")")
  end
  -- URI解析
  for uri in string.gmatch(line, "GET (/[^ ]*) HTTP/[0-9].[0-9]") do
    -- HTTPヘッダ取得
    local headers = {}
    while true do
      line, err = tcpc:receive()
      if err then
        print("receive error(" .. err .. ")")
        break
      end
      -- ヘッダが空のためループを抜ける
      if (line == "") then
        break
      end
      if debug then
        print(line)
      end

      local key, value = string.split(line, ":", 1)
      key = string.lower(key)
      headers[key] = value
    end
    return uri, headers
  end
  -- GETメソッド以外
  return nil
end

-- レスポンス生成
local function response(code, body, content_type)
  if not content_type then
    content_type = "text/html"
  end

  local len = string.len(body)
  local res = {
    $"HTTP/1.1 ${code} ${http_status[code]}",
    "Connection: close",
    $"Content-Length: ${len}",
    $"Content-Type: ${content_type}",
    $"Host: ${host}",
    "",
    body
  }
  return table.concat(res, "\n")
end

-- DHCPリーステーブルを返す
local function getDhcpTable(macvendor)
  local rtn, str = rt.command("show status dhcp summary")
  if not rtn then
    return nil
  end

  dhcp = {}
  for ip, macaddr in string.gmatch(str, "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):[ ]*([0-9a-f]+:[0-9a-f]+:[0-9a-f]+:[0-9a-f]+:[0-9a-f]+:[0-9a-f]+),") do
    dhcp[macaddr] = ip
    if debug then
      print("DHCP Client: " .. ip, macaddr)
    end
  end
  return dhcp
end

-- メイン
local function main(tcp)
  while true do
    local tcpc = assert(tcp:accept())
    tcpc:settimeout(5)

    local raddr, rport = tcpc:getpeername()
    local uri, headers = receive(tcpc)

    rt.syslog("info", "[LuaHTTPD] host=" .. raddr .. " port=" .. rport .. " uri=" .. uri)

    -- URIルーティング
    if uri then
      -- ドキュメントルート
      if (string.match(uri, "^/$")) then
        tcpc:send(response(200, "OK"))

      -- DHCPリーステーブルを json で返す
      elseif (string.match(uri, "^/show/status/dhcp/summary.json$")) then
        local dhcp = getDhcpTable()
        if dhcp then
          -- json を整形する
          local json = {}
          for macaddr, ip in pairs(dhcp) do
            table.insert(json, $"{\"ip\": \"${ip}\", \"macaddr\": \"${macaddr}\"}")
          end
          tcpc:send(response(200, "[" .. table.concat(json, ", ") .. "]", 'application/json'))
        else
          tcpc:send(response(500, 500))
        end

      -- show hogehoge を表示する
      elseif (string.match(uri, "^/show/.*")) then
        local cmd = string.gsub(uri, "\/", " ")
        local rtn, str = rt.command(cmd)
        if rtn then
          tcpc:send(response(200, "<pre>" .. str .. "</pre>"))
        else
          tcpc:send(response(500, 500))
        end

      -- エラーページ
      elseif (string.match(uri, "^/errors/[45][0-9]+$")) then
        local code = string.match(uri, "^/errors/([45][0-9]+)$")
        code = tonumber(code)
        if http_status[code] then
          tcpc:send(response(code, code))
        else
          tcpc:send(response(404, 404))
        end

      -- 未定義は 404
      else
        tcpc:send(response(404, 404))
      end
    end

    tcpc:close()
  end
end

main(init())
