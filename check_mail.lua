--define pins
local ldr_pin=1 --GPIO5
local led_pin=6 --GPIO12
local stop_pin=2 --GPIO4
local sleep_seconds=60

--set pin modes
gpio.mode(ldr_pin, gpio.INPUT)
gpio.mode(stop_pin, gpio.INPUT,gpio.PULLUP)
gpio.mode(led_pin, gpio.OUTPUT)
gpio.write(led_pin, gpio.LOW) --led off

--mqtt connection is ready, check for mail
function mqtt_connect(client)
  print("Connected to MQTT broker")
  --Check for ldr, if there is light without the led being on
  --then mailbox lid is open and we don't know if there is mail.
  state=gpio.read(ldr_pin)
  if state==1 then
    --there is too much light to know if led is on
    print("Too much light")
    m:publish("/house/mail","too much light",0,0,mqtt_puback)
  else
    --dark, next we will check if we see led
    print("It's dark, lets see if we have mail.")
    gpio.write(led_pin, gpio.HIGH) --led on
    state=gpio.read(ldr_pin)  --read ldr
    if state==1 then  --we see led, no mail
      print("No mail")
      m:publish("/house/mail","no mail:(",0,0,mqtt_puback)
    else  --we don't see led, there is something between led and ldr -> mail
      print("Mail")
      m:publish("/house/mail","you have mail",0,0,mqtt_puback)
    end
  end
  gpio.write(led_pin, gpio.LOW) --led off
end

--callback when we get mqtt close
function mqtt_close (client)
  print("Connection to MQTT broker closed. Sleeping.")
  node.dsleep(sleep_seconds*1000000) --sleep for 20 seconds
end
--callback when we get mqtt puback
function mqtt_puback(client)
  print("message published")
  m:on("offline", mqtt_close)
  m:close()
end

--callback if mqtt connection fails
function mqtt_fail(client, reason)
  print("MQTT broker connection failed reason: "..reason)
end

--when we get an ip connect to mqtt broker
function wifi_status(previous_state)
  print("Got IP.")
  print("Connect to MQTT server.")
  m:connect("192.168.0.106", 1883, 0, mqtt_connect, 
                                      mqtt_fail)
end

--if stop pin has been pulled to ground then stop
--this is so you can update lua scripts without flashing again
if gpio.read(stop_pin)==1 then
  -- init mqtt client with keepalive timer 120sec
  print("Create MQTT client.")
  m = mqtt.Client("mailESP", 120, nil, nil)

  --check if we have and ip, if we have just started then probably not
  if wifi.sta.getip() ~= nil then
    print("Connect to MQTT server.")
    m:connect("192.168.0.106", 1883, 0, mqtt_connect, 
                                        mqtt_fail)
  else --register a listener for wifi events
    print("Not connected to wifi, connect.")
    wifi.sta.eventMonReg(wifi.STA_GOTIP,wifi_status)
    wifi.sta.eventMonStart()
  end
else
  print("Stop pin pulled to ground.")
end
print("end")
