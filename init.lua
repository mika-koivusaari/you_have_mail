
--define pins
ldr_pin=1
led_pin=8

--set pin modes
gpio.mode(ldr_pin, gpio.INPUT)
gpio.mode(led_pin, gpio.OUTPUT)

--timer function that is called every minute
timer = function()
  print("Alku")
  --Check for ldr, if there is light without the led being on
  --then mailbox lid is open and we don't know if there is mail.
  state=gpio.read(ldr_pin)
  if state==1 then
    --there is too much light to know if led is on
    print("ylhäällä")
    m:publish("/house/mail","too much light",0,0)
  else
    --dark, next we will check if we see led
    print("alhaalla")
    gpio.write(led_pin, gpio.HIGH) --led on
    state=gpio.read(ldr_pin)  --read ldr
    if state==1 then  --we see led, no mail
      print("ylhäällä")
      m:publish("/house/mail","no mail:(",0,0)
    else  --we don't see led, there is something between led and ldr -> mail
      print("alhaalla")
      m:publish("/house/mail","you have mail",0,0)
    end
  end
  gpio.write(led_pin, gpio.LOW) --led off
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

