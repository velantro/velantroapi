debug["info"] = true;
local json
if (debug["info"]) then
    json = require "resources.functions.lunajson"
end


cmd =" curl -k 'https://15a24d3cd32140671569ec08b1c24e58:726d5b90f6fb1a6072d8a032555c7cbe@velantrodev.myshopify.com/admin/api/2019-07/customers/search.json?query=phone:7474779513&fields=first_name,last_name'";
if (debug["info"]) then
    freeswitch.consoleLog("notice", "[sms] CMD: " .. cmd .. "\n");
end
local handle = io.popen(cmd)
local result = handle:read("*a")
handle:close()
if (debug["info"]) then
    freeswitch.consoleLog("notice", "[sms] CURL Returns: " .. result .. "\n");
end

response = json.decode(result);

freeswitch.consoleLog("notice", "first_name:" .. response["first_name"] .. " last_name:" .. response["last_name"] .."\n");

