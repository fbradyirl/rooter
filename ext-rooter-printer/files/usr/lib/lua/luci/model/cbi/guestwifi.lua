local utl = require "luci.util"

m = Map("guestwifi", "Create a Guest Wifi Network",
	translate("Create a Guest Wifi Network with Optional Bandwidth Speed Limiting"))

m.on_after_commit = function(self)
	luci.sys.call("/usr/lib/rooter/luci/guestwifi.sh &")
end

gw = m:section(TypedSection, "guestwifi", translate("Select Wireless Radio"))
gw.anonymous = true

luci.sys.call("/usr/lib/rooter/luci/wifiradio.sh")

radio = gw:option(ListValue, "radio", translate("Wifi Radio for Network"))
radio.rmempty = true
local file = io.open("/tmp/wifi-device", "r")
if file ~= nil then
	ix=0
	repeat
		local line = file:read("*line")
		if line == nil then
			break
		end
		if ix == 0 then
			radio.default=line
		end
		ix=1
		radio:value(line)
	until 1==0
	file:close()
end

gw1 = m:section(TypedSection, "guestwifi", translate("Guest Network Information"))
gw1.anonymous = true

ssid = gw1:option(Value, "ssid", translate("Network Name :")); 
ssid.optional=false; 
ssid.rmempty = true;
ssid.default="guest"

ip = gw1:option(Value, "ip", translate("Network IP Address :")); 
ip.rmempty = true;
ip.optional=false;
ip.default="192.168.3.1";
ip.datatype = "ipaddr"

file = io.open("/etc/config/qos", "r")
if file ~= nil then
	file:close()
	gw2 = m:section(TypedSection, "guestwifi", translate("Bandwidth Speed Limiting"))
	gw2.anonymous = true
	bl = gw2:option(ListValue, "limit", "Enable Bandwidth Speed Limiting :");
	bl:value("0", "Disable")
	bl:value("1", "Enable")
	bl.default=0

	dl = gw2:option(Value, "dl", "Download Speed (kbit/s) :");
	dl.optional=false; 
	dl.rmempty = true;
	dl.datatype = "and(uinteger,min(1))"
	dl:depends("limit", "1")
	dl.default=1024

	ul = gw2:option(Value, "ul", "Upload Speed (kbit/s) :");
	ul.optional=false; 
	ul.rmempty = true;
	ul.datatype = "and(uinteger,min(1))"
	ul:depends("limit", "1")
	ul.default=128
else
	gw2 = m:section(TypedSection, "guestwifi", translate("Bandwidth Speed Limiting Not Supported"))
	gw2.anonymous = true
end

return m
