
ldr=1
led=8

gpio.mode(ldr, gpio.INPUT)
gpio.mode(led, gpio.OUTPUT)

if not tmr.alarm(0, 5000, tmr.ALARM_AUTO,
  function()
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
    else
      print("alhaalla")
    end
    gpio.write(led, gpio.LOW)
  end)
then
  print("whoopsie")
end
