
ldr=1
led=8

gpio.mode(ldr, gpio.INPUT)
gpio.mode(led, gpio.OUTPUT)

timer = function()
  print("Alku")
  state=gpio.read(ldr)
  if state==1 then
    print("ylhäällä")
  else
    print("alhaalla")
  end
  gpio.write(led, gpio.HIGH)
  state=gpio.read(ldr)
  if state==1 then
    print("ylhäällä")
    m:publish("/house/mail","no mail:(",0,0)
  else
    print("alhaalla")
    m:publish("/house/mail","you have mail",0,0)
  end
  gpio.write(led, gpio.LOW)
end

init_timer = function(client)
  if not tmr.alarm(0, 5000, tmr.ALARM_AUTO,timer) then
    print("Timer failed.")
  else
    print("Timer set.")
  end
end

mqtt_fail = function(client, reason)
  print("failed reason: "..reason)
end

-- init mqtt client with keepalive timer 120sec
print("Create MQTT client.")
m = mqtt.Client("mailESP", 120, nil, nil)

print("Connect to MQTT server.")
m:connect("192.168.0.106", 1883, 0, init_timer, 
                                     mqtt_fail)

