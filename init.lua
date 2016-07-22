
--define pins
ldr_pin=1
led_pin=8

--set pin modes
gpio.mode(ldr_pin, gpio.INPUT)
gpio.mode(led_pin, gpio.OUTPUT)

--timer function that is called every minute
timer = function()
  print("Alku")
  state=gpio.read(ldr_pin)
  if state==1 then
    print("ylhäällä")
  else
    print("alhaalla")
  end
  gpio.write(led_pin, gpio.HIGH)
  state=gpio.read(ldr_pin)
  if state==1 then
    print("ylhäällä")
    m:publish("/house/mail","no mail:(",0,0)
  else
    print("alhaalla")
    m:publish("/house/mail","you have mail",0,0)
  end
  gpio.write(led_pin, gpio.LOW)
end

--init timer
init_timer = function(client)
  if not tmr.alarm(0, 5000, tmr.ALARM_AUTO,timer) then
    print("Timer failed.")
  else
    print("Timer set.")
  end
end

--callback if mqtt send fails
mqtt_fail = function(client, reason)
  print("failed reason: "..reason)
end

-- init mqtt client with keepalive timer 120sec
print("Create MQTT client.")
m = mqtt.Client("mailESP", 120, nil, nil)

print("Connect to MQTT server.")
m:connect("192.168.0.106", 1883, 0, init_timer, 
                                     mqtt_fail)

