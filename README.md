# pimatic-bluelink
Plugin for Bluelink connected cars

The plugin can be installed via the plugins page of Pimatic.
For now this plugin works only for Kia 'Uvo' cars

## Config of the plugin
```
{
  username:     "The username of your Kia Uvo account"
  password:     "The password of your Kia Uvo account"
  region:  		"The region ('EU', US or 'CA') only tested for 'EU'
  pin:			" The Uvo pin for get access to the car"
  pollTime:		"The time between status poll (default 2 minutes)"
  debug:        "Debug mode. Writes debug messages to the Pimatic log, if set to true."
}
```

## Config of a KiaDevice

Devices are added via the discovery function. Per registered Kia a KiaDevice is discovered unless the device is already in the config.
The automatic generated Id must not change. Its the unique reference to your car. You can change the Pimatic device name after you have saved the device. For the Pimatic KiaDevice ID and Name the Kia Nickname is used. The vin and attributes are generated automaticaly and should not be changed. 

```
{
  vin: "The car identiciation number, a unique number for your car"
  vehicleId: "The car id"
  type: "The car type"
  defrost: "default value for remote start"
  windscreenHeating: "default value for remote start"
  temperature: "default value for remote start"
}
```

The following attributes are updated and visible in the Gui. 

```
engine: "Status of engine (on/off)"
airco: "Status of airco (on/off)"
door: "Status of car door (lock/unlocked)"
charging: "If vehicle is charging"
pluggedIn: "If vehicle is pluggedIn"
battery: "The battery level (0-100%)"
odo: "The car odo value (km)"
lat: "The cars latitude"
lon: "The cars longitude"
```

The car can be controlled via rules

The action syntax:
```
  bluelink <KiaDevice Id> [start $startOptionsVariable | startDefault | stop | lock | unlock | chargeStart | chargeStop ]
```
The $startOptionsVariable syntax is a string with the following format
[defrost:[true|false]] | [windscreenHeating:[true|false] | [temperature:number]
You can change by name the default settings, for 1, 2 or all 3 options.
Use 'startDefault' is you want to remote start the airco with the device defaults

