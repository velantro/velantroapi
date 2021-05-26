--
-- Created by IntelliJ IDEA.
-- romon.zaman@gmail.com
-- mohammad kamruzzaman
-- Date: 7/13/15
-- Time: 9:29 AM
-- To change this template use File | Settings | File Templates.
--
--

sounds_dir = "";
recordings_dir = "";
pin_number = "";
max_tries = "3";
digit_timeout = "3000";

--define the explode function
function explode ( seperator, str )
    local pos, arr = 0, {}
    for st, sp in function() return string.find( str, seperator, pos, true ) end do -- for each divider found
        table.insert( arr, string.sub( str, pos, st-1 ) ) -- attach chars left of current divider
        pos = sp + 1 -- jump past current divider
    end
    table.insert( arr, string.sub( str, pos ) ) -- attach chars right of last divider
    return arr
end

--create the api object
api = freeswitch.API();


keypress = argv[1];
src = argv[2] or 'auto';
if (src ~= 'auto') then	
	dst = argv[3] or 'auto';
end

--check if the session is ready
caller_id_number = session:getVariable("caller_id_number");
if (dst == 'auto') then
	dst = caller_id_number;
end
ivr_menu_uuid    = session:getVariable("ivr_menu_uuid");
if ( session:ready() ) then
	cmd = "php /var/www/fusionpbx/secure/v_ivr_sms.php " .. ivr_menu_uuid .. ' ' .. keypress .. ' ' .. src .. ' ' .. dst;
	freeswitch.consoleLog("INFO", "send_sms.lua: ".. cmd .."\n");
	os.execute(cmd);
end
