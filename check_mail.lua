--needed modules:
--mqtt, gpio, wifi, node, rtcmem

--define pins
local ldr_pin=1 --GPIO5
local led_pin=6 --GPIO12
local stop_pin=2 --GPIO4
local tsl257_power_pin=5 --GPIO14
local sleep_seconds=60

local TOO_MUCH_LIGHT=1
local MAIL=2
local NO_MAIL=3
local ERROR=4 --general unkown error

local MODEM_AFTER_SLEEP=2
--1, RF_CAL after deep-sleep wake up, there will belarge current
--2, no RF_CAL after deep-sleep wake up, there will only be small current
--4, disable RF after deep-sleep wake up, just like modem sleep, there will be the smallest current
--NOTE https://github.com/nodemcu/nodemcu-firmware/issues/1225
local status=0

--set pin modes
gpio.mode(ldr_pin, gpio.INPUT)
gpio.mode(stop_pin, gpio.INPUT,gpio.PULLUP)
gpio.mode(led_pin, gpio.OUTPUT)
gpio.write(led_pin, gpio.LOW) --led off
--Moving tsl257 power from 3.3v rail to gpio prevents
--sensors from draining battery when not needed.
gpio.mode(tsl257_power_pin, gpio.OUTPUT)

function check_mail()
  gpio.write(tsl257_power_pin, gpio.HIGH) --TSL257 on

  state=gpio.read(ldr_pin)
  if state==1 then
    --there is too much light to know if led is on
    print("Too much light")
    return TOO_MUCH_LIGHT
  else
    --dark, next we will check if we see led
    print("It's dark, lets see if we have mail.")
    gpio.write(led_pin, gpio.HIGH) --led on
    state=gpio.read(ldr_pin)  --read ldr
    gpio.write(led_pin, gpio.LOW) --led off
    if state==1 then  --we see led, no mail
      print("No mail")
      return NO_MAIL
    else  --we don't see led, there is something between led and ldr -> mail
      print("Mail")
      return MAIL
    end
  end
  return ERROR --we should newer get to here
end

--sleep function, so we can add some cleanup here if we need to.
function sleep()
  wifi.sta.autoconnect(0)
  node.dsleep(sleep_seconds*1000000,MODEM_AFTER_SLEEP) --sleep for x seconds
end

--mqtt connection is ready, check for mail
function mqtt_connect(client)
  print("Connected to MQTT broker")
  if status==TOO_MUCH_LIGHT then
    --there is too much light to know if led is on
    print("Too much light")
    m:publish("/house/mail","too much light",0,0,mqtt_puback)
  elseif status==NO_MAIL then
    print("No mail")
    m:publish("/house/mail","no mail:(",0,0,mqtt_puback)
  elseif status==MAIL then
    print("Mail")
    m:publish("/house/mail","you have mail",0,0,mqtt_puback)
  else
    print("Error")
    m:publish("/house/mail","error",0,0,mqtt_puback)
  end
end

--callback when we get mqtt close
function mqtt_close (client)
  print("Connection to MQTT broker closed. Sleeping.")
  sleep()
end
--callback when we get mqtt puback
function mqtt_puback(client)
  rtcmem.write32(127,status) --write status only if we have published it
  print("message published")
  m:on("offline", mqtt_close)
  m:close()
end

--callback if mqtt connection fails
function mqtt_fail(client, reason)
  print("MQTT broker connection failed reason: "..reason)
  sleep()
end

--wifi status callback
function wifi_status(previous_state)
  --when we get an ip connect to mqtt broker
  if wifi.sta.status()==wifi.STA_GOTIP then
    print("Got IP.")
    print("Connect to MQTT server.")
    m:connect("192.168.0.106", 1883, 0, mqtt_connect, 
                                        mqtt_fail)
  else --else we have an error -> sleep and try again
    print("Wifi connection error, status "..wifi.sta.status().." previous "..previous_state)
    sleep()
  end
end

--if stop pin has been pulled to ground then stop
--this is so you can update lua scripts without flashing again
if gpio.read(stop_pin)==1 then
  print("Create timer for sleeping, in case something goes wrong")
  if not tmr.alarm(0, 10000, tmr.ALARM_SINGLE,
                   function()
                     print("Error, forced sleep")
                     sleep()
                   end) then
    print("Could not start timer!")
  end

  status=check_mail()
  last_status=rtcmem.read32(127)
  if status~=last_status then
    print("Status changed, connect to wifi.")
    --register callbacks so we know wifi status
    wifi.sta.eventMonReg(wifi.STA_GOTIP,wifi_status)
    wifi.sta.eventMonReg(wifi.STA_WRONGPWD,wifi_status)
    wifi.sta.eventMonReg(wifi.STA_APNOTFOUND,wifi_status)
    wifi.sta.eventMonReg(wifi.STA_FAIL,wifi_status)
    wifi.sta.eventMonStart()
    wifi.setmode(wifi.STATION)
    print(wifi.sta.getip())

    wifi.sta.sethostname("YouHaveMail")
    wifi.sta.connect()
    m=mqtt.Client("MailESP", 120)
  else
    print("No change, sleep")
    sleep()
  end
else
  print("Stop pin pulled to ground.")
end
print("end")
