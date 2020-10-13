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
		api = freeswitch.API();
		callback_number = "*91968888" .. caller_id_number;
		cmd_string = "originate {original_joined_epoch='" .. joined_epoch .. "',original_rejoined_epoch='" .. rejoined_epoch ..
				     "',original_caller_id_number='" .. caller_id_number .. "'}loopback/" .. callback_number .. "/" .. domain_name .. " " .. queue_extension .. "  XML " .. domain_name;
		freeswitch.consoleLog("NOTICE", "[queue_callback]: "..cmd_string.."\n");
		reply = api:executeString(cmd_string);
		session:hangup();	
	end
end
	