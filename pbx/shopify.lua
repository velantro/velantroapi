debug["info"] = true;
local json
if (debug["info"]) then
    json = require "resources.functions.lunajson"
end



function request(path)
    local cmd = "curl -k 'https://15a24d3cd32140671569ec08b1c24e58:726d5b90f6fb1a6072d8a032555c7cbe@velantrodev.myshopify.com" .. path .. "'";
    if (debug["info"]) then
        freeswitch.consoleLog("notice", "[shopify.lua] CMD: " .. cmd .. "\n");
    end
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    if (debug["info"]) then
        freeswitch.consoleLog("notice", "[shopify.lua] CURL Returns: " .. result .. "\n");
    end
    
    local response = json.decode(result);
    return response;
end

function dotts(tts_text)
    if (debug["info"]) then
        freeswitch.consoleLog("notice", "[shopify.lua] tts_text: " .. tts_text .. "\n");
    end
    local filename = api:execute("system", "php /var/www/api/pbx/polly_bin.php '" .. tts_text .. "'");
    return filename;
end



local response = request("/admin/api/2019-07/customers/search.json?query=phone:18185784000&fields=first_name,last_name,id");

customer_id = response["customers"][1]["id"];
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
    
    
    min_digits=1;
    max_digits=1;
    max_tries = 2;
    digit_timeout=15000;
    
    filename = dotts("Are you calling to check on the status of your order. If yes press 1, if no press 2. ");
    dtmf = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", filename, "", "\\d");
    if (not customer_id) then
        dtmf = '2';
    end
    if (dtmf == '1') then
        local response = request("/admin/api/2019-07/customers/" .. customer_id .. ".json");
        last_order_id = response["customer"]["last_order_id"];
        if (last_order_id) then
            response = request("/admin/api/2019-07/orders/" .. last_order_id .. ".json");
            order_at = response["order"]["created_at"];
            
            filename = dotts("Your last order was on " .. string.sub(order_at, 1, 10) .. ", "  .. string.sub(order_at, 12, -1) ..  ". if yes press 1 if no press 2.")
            dtmf = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", filename, "", "\\d");
            if (dtmf == '1') then
                status = response["order"]["financial_status"];
                filename = dotts("Your order status is " .. status ..
                                 ".  the shipping carrier is " .. ". it will arrive on  ." )
                session:streamFile(filename);
                
                filename = dotts("Press 5 to email you the tracking number of your shipment." .. "To return to main menu press star");
                session:streamFile(filename);

            end
        end
    end
end

