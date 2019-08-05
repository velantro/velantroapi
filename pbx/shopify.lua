debug["info"] = true;
local json
if (debug["info"]) then
    json = require "resources.functions.lunajson"
end


cmd =" curl -k 'https://15a24d3cd32140671569ec08b1c24e58:726d5b90f6fb1a6072d8a032555c7cbe@velantrodev.myshopify.com/admin/api/2019-07/customers/search.json?query=phone:18185784000&fields=first_name,last_name'";
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

--freeswitch.consoleLog("notice", "first_name:" .. response["customers"][1]["first_name"] .. " last_name:" .. response["customers"][1]["last_name"]);
shop = "velantro"
if ( session:ready() ) then
--answer the call
    session:answer();
--get the dialplan variables and set them as local variables
    tts_text = "Hello " .. response["customers"][1]["first_name"] .. " " .. response["customers"][1]["last_name"] .. ". Thank You for calling " .. shop .. " shop. We appreciate your business. "
    freeswitch.consoleLog("info", "Polly tts: " .. tts_text .. "\n");
    api = freeswitch.API();

    filename = api:execute("system", "php /var/www/api/pbx/polly_bin.php '" .. tts_text .. "'");
    
    session:streamFile(filename);
end