# pimatic-bluelink
Plugin for Bluelink connected cars

The plugin can be installed via the plugins page of Pimatic.
This plugin works for Kia and Hyundia bluelink connected cars.

### Config of the plugin
```
{
  username:  "The username of your Kia / Hyundai account"
  password:  "The password of your Kia / Hyundai account"
  region:    "The region ('EU', US or 'CA') only tested for 'EU'
  pin:       "The pin for get access to the car"
  brand:     "The used brand: Kia or Hyundai (default kia)"
  debug:     "Debug mode. Writes debug messages to the Pimatic log, if set to true."
}
```

### Config of a KiaDevice or HyundaiDevice

Devices are added via the discovery function. Per registered Kia a KiaDevice or per registered Hyundai a HyundaiDevice is discovered unless the device is already in the config.
The automatic generated Id must not change. Its the unique reference to your car. You can change the Pimatic device name after you have saved the device. For the Pimatic KiaDevice ID and Name the Kia Nickname is used. The vin and attributes are generated automaticaly and should not be changed.

There are 2 timers, pollTimePassive and pollTimeAtive. The polling switches to pollTimeActive when the engine is set to on or the airco is turned on or when te battery is charging. If all those 3 conditions are false the polling switches to pollTimePassive. This mechanism prevents unnecessary status polls.

```
{
  vin: "The car identiciation number, a unique number for your car"
  vehicleId: "The car id"
  type: "The car type"
  defrost: "default value for remote start"
  windscreenHeating: "default value for remote start"
  temperature: "default value for remote start"
  optionsVariable: "variable name for the airo+ options"
  pollTimePassive: "The time between status poll in passive mode (default 3600000 ms (is 1 hour))"
  pollTimeActive:  "The time between status poll in active mode (default 600000 ms (is 10 minutes))"
}
```
### The gui
![](/assets/bluelink.png)

The following attributes are updated and visible in the Gui.

```
Buttons:
 airco | aico+ | off   "Status of airco (default values), airco+ (optionsVariable values) or off"
 lock | unlocked       "Doors are locked or unlocked"
 charge | stop         "Vehicle is charging"
 refresh               "refresh the car status"
```

```
Attributes:
 engine: "Status of engine (on/off)"
 doors: "Status of car doors (open/closed)"
 pluggedIn: "If vehicle is pluggedIn"
 battery: "The battery level (0-100%)"
 odo: "The car odo value (km)"
 speed: "The car speed (km/h)"
 remaining: "The remaining distance (km)"
 maximum: "The maximum distance if fully loaded (km)"
 lat: "The cars latitude"
 lon: "The cars longitude"
```

### Rules

The car can be controlled via rules

The action syntax:
```
  bluelink <KiaDevice/Hyundai Id> [start $startOptionsVariable | startDefault | stop |
      lock | unlock | chargeStart | chargeStop | refresh ]
```
Commands:
- start: this command starts the climate control of the car with options defrost, windscreenHeating and temperature
- stop: ends the start action
- lock: locks the doors
- unlock: unlocks the doors
- chargeStart: start charging (when pluggedIn)
- chargeStop: stop charging
- refresh: refresh the car status data

The $startOptionsVariable syntax is a string variable with the following format:
```
[defrost:[true|false]] | [windscreenHeating:[true|false] | [temperature:number]
```
You can change by name the default settings, for 1, 2 or all 3 options.
Use 'startDefault' is you want to remote start the airco with the device defaults.
You can use an expression for the $startOptionsVariable. In this expression variables can be used.

An example: $startOptionsVariable: 
```
"temperature:$temp-variable,defrost:$defrost-variable,windscreenHeating:$windscreenHeating-variable"
```
(use the double quotes when you add the expression in the startOptionsVariable)


----
This plugin needs node version 10!
