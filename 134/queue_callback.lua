-- queue-callback,*,exec:execute_extension,callback-${caller_id_number}-${destination_number}1 XML ${domain_name}
	require "resources.functions.config";

	debug.sql = true;
	skip_cdr_analysis = true;

--define the trim function
	require "resources.functions.trim";

--add is_numeric
	function is_numeric(text)
		if type(text)~="string" and type(text)~="number" then return false end
		return tonumber(text) and true or false
	end

	caller_id_number = argv[1];
	queue_extension = argv[2];
	call_uuid 		= argv[3];
	domain_name 	= argv[4];
	

if ( session:ready() ) then
	queue_caller_id_number = session:getVariable("queue_caller_id_number");
	queue_original_id_number = session:getVariable("queue_original_id_number");
	queue_name = session:getVariable("cc_queue");
	member_uuid = session:getVariable("cc_member_uuid");
	--origination_caller_id_name = session:getVariable("origination_caller_id_name") or '15149991234';
	--origination_caller_id_number = session:getVariable("origination_caller_id_number") or '15149991234';
	domain_name = session:getVariable("domain_name");
	domain_uuid = session:getVariable("domain_uuid") or '';
	accountcode = session:getVariable("accountcode") or '';

	--detect time, by default 5 minutes
	require "resources.functions.database_handle";
	dbh = freeswitch.Dbh("sqlite://"..database_dir.."/callcenter.db");

	
	sql = [[select * from members where session_uuid=']] ..call_uuid .. [[']];
	
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[queue_callback] "..sql.."\n");
	end

	status = dbh:query(sql, function(row)
		joined_epoch = row.joined_epoch;
		rejoined_epoch = row.rejoined_epoch;
	end);

	if (joined_epoch == nil) then
		freeswitch.consoleLog("notice", "[queue_callback] joined epoch is nil, ignore\n");
	else
		min_digits = 1;
		max_digits = 15;
		max_tries  = 3;
		digit_timeout = 3000;
		session:streamFile(recordings_dir .. "/queue_callback_number.wav")
		session:execute('say', "en number iterated " .. caller_id_number);
		
		digits = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", recordings_dir .. "/queue_callback_main.wav", "", "\\d+");
		freeswitch.consoleLog("notice", "[queue_callback] keys: digits \n");

		if (digits == '0' or digits == nil) then
			freeswitch.consoleLog("NOTICE", "[queue_callback]: continue wait\n");
		else
			if (digits == '1') then
				callback_number = caller_id_number
			else
				callback_number = digits;
			end
			--digits = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", recordings_dir .. "/queue_callback_schedule.wav", "", "\\d+");
			if (false) then
				digits = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", recordings_dir .. "/queue_callback_scheduletime.wav", "", "\\d+");
				
				--cmd_string = "sched_api +1800 queue_callback originate {group_confirm_key=1,group_confirm_file=xxxx}sofia/internal/1000%${sip_profile} &echo()";
			else
				api = freeswitch.API();
				echo_number = "*91968888" .. callback_number;
				cmd_string = "originate {original_joined_epoch='" .. joined_epoch .. "',original_rejoined_epoch='" .. rejoined_epoch ..
							 "',original_caller_id_number='" .. callback_number .. "'}sofia/internal" .. echo_number .. "@" .. domain_name .. " " .. queue_extension .. "  XML " .. domain_name;
				freeswitch.consoleLog("NOTICE", "[queue_callback]: "..cmd_string.."\n");
				reply = api:executeString(cmd_string);
				session:hangup();
			end
		end
		
	end
end
	