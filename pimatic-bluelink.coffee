module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  fs = require('fs')
  path = require('path')
  #Bluelinky = require('kuvork')

  class BluelinkPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-bluelink-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @brand = @config.brand ? "kia"
      if @brand is "hyundai"
        Bluelinky = require('bluelinky')
        @_discoveryClass = "HuyndaiDevice"
      else
        Bluelinky = require('kuvork')
        @_discoveryClass = "KiaDevice"

      @username = @config.username # "email@domain.com";
      @password = @config.password #"a1b2c3d4";
      @region = @config.region ? 'EU'
      @pin = @config.pin

      @client = null
      @clientReady = false

      @framework.on 'after init', ()=>
        @client = new Bluelinky(
          username: @username
          password: @password
          region: @region
          pin: @pin
        )

        @client.on 'ready',() =>
          env.logger.debug "Plugin emit clientReady"
          @clientReady = true
          @emit "clientReady"

        @client.on 'error',(err) =>
          env.logger.debug "Bluelink login error: " + JSON.stringify(err,null,2)
          @clientReady = false


      @framework.deviceManager.registerDeviceClass('KiaDevice', {
        configDef: @deviceConfigDef.KiaDevice,
        createCallback: (config, lastState) => new KiaDevice(config, lastState, @, @client, @framework)
      })

      @framework.deviceManager.registerDeviceClass('HyundaiDevice', {
        configDef: @deviceConfigDef.HyundaiDevice,
        createCallback: (config, lastState) => new HyundaiDevice(config, lastState, @, @client, @framework)
      })

      @framework.ruleManager.addActionProvider(new BluelinkActionProvider(@framework))

      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-bluelink', 'Searching for new devices'

        if @clientReady
          @client.getVehicles()
          .then((vehicles) =>
            for vehicle in vehicles
              carConfig = vehicle.vehicleConfig
              env.logger.info "CarConfig: " + JSON.stringify(carConfig,null,2)
              _did = (carConfig.nickname).split(' ').join("_")
              if _.find(@framework.deviceManager.devicesConfig,(d) => d.id is _did)
                env.logger.info "Device '" + _did + "' already in config"
              else
                config =
                  id: _did #(carConfig.nickname).split(' ').join("_").toLowerCase()
                  name: carConfig.nickname
                  class: @_discoveryClass
                  vin: carConfig.vin
                  vehicleId: carConfig.id
                  type: carConfig.name
                @framework.deviceManager.discoveredDevice( "Bluelink", config.name, config)
          ).catch((e) =>
            env.logger.error 'Error in getVehicles: ' +  e.message
          )
      )


  class BluelinkDevice extends env.devices.Device

    attributes:
      engine:
        description: "Status of engine"
        type: "boolean"
        acronym: "engine"
        labels: ["on","off"]
      airco:
        description: "Status of airco"
        type: "boolean"
        acronym: "airco"
        labels: ["on","off"]
      door:
        description: "Status of doorlock"
        type: "boolean"
        acronym: "door"
        labels: ["locked","unlocked"]
      charging:
        description: "If vehicle is charging"
        type: "boolean"
        acronym: "charging"
        labels: ["on","off"]
      pluggedIn:
        description: "If vehicle is pluggedIn"
        type: "boolean"
        acronym: "pluggedIn"
        labels: ["on","off"]
      doorFrontLeft:
        description: "door fl"
        type: "boolean"
        acronym: "door fl"
        labels: ["opened","closed"]
      doorFrontRight:
        description: "door fr"
        type: "boolean"
        acronym: "door fr"
        labels: ["opened","closed"]
      doorBackLeft:
        description: "door bl"
        type: "boolean"
        acronym: "door bl"
        labels: ["opened","closed"]
      doorBackRight:
        description: "door br"
        type: "boolean"
        acronym: "door br"
        labels: ["opened","closed"]
      hood:
        description: "hood"
        type: "boolean"
        acronym: "hood"
        labels: ["opened","closed"]
      trunk:
        description: "trunk"
        type: "boolean"
        acronym: "trunk"
        labels: ["opened","closed"]
      battery:
        description: "The battery level"
        type: "number"
        unit: '%'
        acronym: "battery"
      odo:
        description: "The car odo value"
        type: "number"
        unit: 'km'
        acronym: "odo"
      speed:
        description: "Speed of the car"
        type: "number"
        acronym: "speed"
        unit: "km/h"
      remainingRange:
        description: "Remaining range basing on current battery resp. fuel level"
        type: "number"
        acronym: "remaining"
        unit: "km"        
      maximumRange:
        description: "Maximum range with fully charged battery resp. filled tank"
        type: "number"
        acronym: "maximum"
        unit: "km"        
      lat:
        description: "The cars latitude"
        type: "number"
        acronym: "lat"
      lon:
        description: "The cars longitude"
        type: "number"
        acronym: "lon"

    
    constructor: (config, lastState, @plugin, client, @framework) ->
      @config = config
      @id = @config.id
      @name = @config.name

      @client = @plugin.client

      @pollTimePassive = @config.pollTimePassive ? 3600000 # 1 hour
      @pollTimeActive = @config.pollTimeActive ? 600000 # 10 minutes
      @currentPollTime = @pollTimeActive

      @_engine = laststate?.engine?.value ? false
      @_speed = laststate?.speed?.value ? 0
      @_airco = laststate?.airco?.value ? false
      @_door = laststate?.door?.value ? false
      @_charging = laststate?.charging?.value ? false
      @_battery = laststate?.battery?.value ? 0
      @_pluggedIn = laststate?.pluggedIn?.value ? false
      @_odo = laststate?.odo?.value ? 0
      @_maximumRange = laststate?.maximumRange?.value ? 0
      @_remainingRange = laststate?.remainingRange?.value ? 0
      @_doorFrontLeft = laststate?.doorFrontLeft?.value ? 0
      @_doorFrontRight = laststate?.doorFrontRight?.value ? 0
      @_doorBackLeft = laststate?.doorBackLeft?.value ? 0
      @_doorBackRight = laststate?.doorBackRight?.value ? 0
      @_hood = laststate?.hood?.value ? 0
      @_trunk = laststate?.trunk?.value ? 0
      @_lat = laststate?.lat?.value ? 0
      @_lon = laststate?.lon?.value ? 0
      retries = 0
      maxRetries = 20

      @vehicle = null

      @plugin.on 'clientReady', @clientListener = () =>
        unless @statusTimer? 
          env.logger.debug "Plugin ClientReady, requesting vehicle"
          @vehicle = @plugin.client.getVehicle(@config.vin)
          env.logger.debug "From plugin start - starting status update cyle"
          @getStatus()
        else
          env.logger.debug "Error: plugin start but @statusTimer alredy running!"

      @framework.variableManager.waitForInit()
      .then ()=>
        if @plugin.clientReady and not @statusTimer?
          env.logger.debug "ClientReady ready, Device starting, requesting vehicle"
          @vehicle = @plugin.client.getVehicle(@config.vin)
          env.logger.debug "From device start - starting status update cyle"
          @getStatus()

      @getStatus = () =>
        if @plugin.clientReady
          env.logger.debug "requesting status"
          @vehicle.status()
          .then (status)=>
            @handleStatus(status)
            return @vehicle.location()
          .then (location)=>
            env.logger.debug "location " + JSON.stringify(location,null,2)
            @handleLocation(location)
            return @vehicle.odometer()
          .then (odometer) =>
            env.logger.debug "odo " + JSON.stringify(odometer,null,2)
            @handleOdo(odometer)
          .catch (e) =>
            env.logger.debug "getStatus error: " + JSON.stringify(e,null,2)
          @statusTimer = setTimeout(@getStatus, @currentPollTime)
          env.logger.debug "Next poll in " + @currentPollTime + " ms"
        else
          env.logger.debug "(re)requesting status in 5 seconds, client not ready"
          retries += 1
          if retries < maxRetries
            @statusTimer = setTimeout(@getStatus, 5000)
          else
            env.logger.debug "Max number of retries(#{maxRetries}) reached, Client not ready, stop trying"

      super()

    handleLocation: (location) =>
      @setLocation(location.latitude, location.longitude)
      @setSpeed(location.speed.value)

    handleOdo: (odo) =>
      @setOdo(odo.value)

    handleStatus: (status) =>
      env.logger.debug "Status: " + JSON.stringify(status,null,2)
      if status.doorLock?
        @setDoor(status.doorLock)
      if status.doorOpen?
        @setDoors(status)
      if status.engine?
        @setEngine(status.engine)
      if status.airCtrlOn?
        @setAirco(status.airCtrlOn)
      if status.evStatus?
        @setEvStatus(status.evStatus)


      #update polltime to active if engine is on, charging or airco is on 
      active = (Boolean status.engine) or (Boolean status.evStatus.batteryCharge) or (Boolean status.airCtrlOn)
      env.logger.debug "Car status PollTimeActive is " + active
      @setPollTime(active)

    parseOptions: (_options) ->
      climateOptions =
        defrost: false
        windscreenHeating: false
        temperature: 20
        unit: 'C'
      if _options?
        try
          parameters = _options.split(",")
          for parameter in parameters
            tokens = parameter.split(":")
            _key = tokens[0].trim()
            _val = tokens[1].trim()
            env.logger.debug "_key: " + _key + ", _val: " + _val
            switch _key
              when "defrost"
                climateOptions.defrost = (if _val is "false" then false else true)
              when "windscreenHeating"
                climateOptions.windscreenHeating = (if _val is "false" then false else true)
              when "temperature"
                # check if number
                unless Number.isNaN(Number _val)
                  climateOptions.temperature = Number _val
        catch err
          env.logger.debug "Handled error in parseOptions " + err

      return climateOptions

    execute: (command, options) =>
      return new Promise((resolve,reject) =>

        switch command
          when "start"
            env.logger.debug "Start with options: " + JSON.stringify(@parseOptions(options),null,2)
            @vehicle.start(@parseOptions(options))
            .then (resp)=>
              env.logger.debug "Started: " + JSON.stringify(resp,null,2)
              @setEngine(true)
              @setPollTime(true) # set to active poll
              resolve()
            .catch (err) =>
              env.logger.debug "Error start car: " + JSON.stringify(err,null,2)
              reject()
          when "stop"
            @vehicle.stop()
            .then (resp)=>
              @setEngine(false)
              env.logger.debug "Stopped: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error stop car: " + JSON.stringify(err,null,2)
              reject()
          when "lock"
            @vehicle.lock()
            .then (resp)=>
              @setDoor(true)
              env.logger.debug "Locked: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error lock car: " + JSON.stringify(err,null,2)
              reject()
          when "unlock"
            @vehicle.unlock()
            .then (resp)=>
              @setDoor(false)
              @setPollTime(true) # set to active poll
              env.logger.debug "Unlocked: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error unlock car: " + JSON.stringify(err,null,2)
              reject()
          when "startCharge"
            @vehicle.startCharge()
            .then (resp)=>
              @setCharge(true)
              @setPollTime(true) # set to active poll
              env.logger.debug "startCharge: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error startCharge car: " + JSON.stringify(err,null,2)
              reject()
          when "stopCharge"
            @vehicle.stopCharge()
            .then (resp)=>
              @setCharge(false)
              env.logger.debug "stopCharge: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error stopCharge car: " + JSON.stringify(err,null,2)
              reject()
          when "refresh"
            clearTimeout(@statusTimer) if @statusTimer?
            @getStatus()           
            env.logger.debug "refreshing status: " + JSON.stringify(resp,null,2)
            resolve()
          else
            env.logger.debug "Unknown command " + command
            reject()
        resolve()
      )

    getEngine: -> Promise.resolve(@_engine)
    getAirco: -> Promise.resolve(@_airco)
    getDoor: -> Promise.resolve(@_door)
    getDoorFrontLeft: -> Promise.resolve(@_doorFrontLeft)
    getDoorFrontRight: -> Promise.resolve(@_doorFrontRight)
    getDoorBackLeft: -> Promise.resolve(@_doorBackLeft)
    getDoorBackRight: -> Promise.resolve(@_doorBackRight)
    getHood: -> Promise.resolve(@_hood)
    getTrunk: -> Promise.resolve(@_trunk)
    getCharging: -> Promise.resolve(@_charging)
    getBattery: -> Promise.resolve(@_battery)
    getPluggedIn: -> Promise.resolve(@_pluggedIn)
    getOdo: -> Promise.resolve(@_odo)
    getSpeed: -> Promise.resolve(@_speed)
    getMaximumRange: -> Promise.resolve(@_maximumRange)
    getRemainingRange: -> Promise.resolve(@_remainingRange)
    getLat: -> Promise.resolve(@_lat)
    getLon: -> Promise.resolve(@_lon)

    setPollTime: (active) =>
      # true is active, false is passive
      if (active and @currentPollTime == @pollTimeActive) or (!active and @currentPollTime == @pollTimePassive) then return

      #env.logger.debug("Test for active " + active + ", @currentPollTime:"+@currentPollTime+", @pollTimePassive:"+@pollTimePassive+", == "+ (@currentPollTimer == @pollTimePassive))
      if (active) and (@currentPollTime == @pollTimePassive)
        clearTimeout(@statusTimer) if @statusTimer?
        @currentPollTime = @pollTimeActive
        env.logger.debug "Switching to active poll, with polltime of " + @pollTimeActive + " ms"
        setTimeout(@getStatus, @pollTimeActive)
        return

      if not active and @currentPollTime == @pollTimeActive
        clearTimeout(@statusTimer) if @statusTimer?
        @currentPollTime = @pollTimePassive
        env.logger.debug "Switching to passive poll, with polltime of " + @pollTimePassive + " ms"
        setTimeout(@getStatus, @pollTimePassive)

    setMaximumRange: (_range) =>
      @_maximumRange = Number _range
      @emit 'maximumRange', Number _range

    setRemainingRange: (_range) =>
      @_remainingRange = Number _range
      @emit 'remainingRange', Number _range

    setEngine: (_status) =>
      @_engine = Boolean _status
      @emit 'engine', Boolean _status

    setSpeed: (_status) =>
      @_speed = Number _status
      @emit 'speed', Number _status

    setDoor: (_status) =>
      @_door = Boolean _status
      @emit 'door', Boolean _status

    setDoors: (_status) =>
      if _status.doorOpen?
        @_doorFrontLeft = Boolean _status.doorOpen.frontLeft
        @emit 'doorFrontLeft', Boolean _status.doorOpen.frontLeft
        @_doorFrontRight = Boolean _status.doorOpen.doorFrontRight
        @emit 'doorFrontRight', Boolean _status.doorOpen.doorFrontRight
        @_doorBackLeft = Boolean _status.doorOpen.backLeft
        @emit 'doorBackLeft', Boolean _status.doorOpen.backLeft
        @_doorBackRight = Boolean _status.doorOpen.backRight
        @emit 'doorBackRight', Boolean _status.doorOpen.backRight
      if _status.trunkOpen?
        @_trunk = Boolean _status.trunkOpen
        @emit 'trunk', Boolean _status.trunkOpen
      if _status.hoodOpen?
        @_hood = Boolean _status.hoodOpen
        @emit 'hood', Boolean _status.hoodOpen

    setEvStatus: (evStatus) =>
      @_battery = Number evStatus.batteryStatus
      @emit 'battery', Number evStatus.batteryStatus
      @_pluggedIn = evStatus.batteryPlugin > 0
      @emit 'pluggedIn', (evStatus.batteryPlugin > 0)
      @_charging = Boolean evStatus.batteryCharge
      @emit 'charging', Boolean evStatus.batteryCharge
      if @_charging
        @_pluggedIn = true
        @emit 'pluggedIn', (evStatus.batteryPlugin > 0)
      if evStatus.reservChargeInfos.targetSOClist?[0]?.dte?.rangeByFuel?.totalAvailableRange?.value?
        _maximumRange = Number evStatus.reservChargeInfos.targetSOClist[0].dte.rangeByFuel.totalAvailableRange.value
        if _maximumRange > 0
          @setMaximumRange(_maximumRange)
      if evStatus.drvDistance?[0]?.rangeByFuel?.totalAvailableRange?.value?
        _remainingRange = Number evStatus.drvDistance[0].rangeByFuel.totalAvailableRange.value
        if _remainingRange > 0
          @setRemainingRange(_remainingRange)

    setAirco: (_status) =>
      @_airco = Boolean _status
      @emit 'airco', Boolean _status

    setOdo: (_status) =>
      @_odo = Number _status
      @emit 'odo', Number _status

    setLocation: (_lat, _lon) =>
      @_lat = _lat
      @_lon = _lon
      @emit 'lat', _lat
      @emit 'lon', _lon

    setCharge: (charging) =>
      @_charging = Boolean charging
      @emit 'charging', Boolean charging
      if charging
        @_pluggedIn = true # if charging, must be pluggedIn
        @emit 'pluggedIn', @_pluggedIn

    destroy:() =>
      clearTimeout(@statusTimer) if @statusTimer?
      @plugin.removeListener('clientReady', @clientListener)
      super()

  class BluelinkActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>

      bluelinkDevice = null
      @options = null
  
      bluelinkDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class == "KiaDevice"
      ).value()

      setCommand = (command) =>
        @command = command

      optionsString = (m,tokens) =>
        unless tokens?
          context?.addError("No variable")
          return
        @options = tokens
        setCommand("start")

      m = M(input, context)
        .match('bluelink ')
        .matchDevice(bluelinkDevices, (m, d) ->
          # Already had a match with another device?
          if bluelinkDevice? and bluelinkDevices.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          bluelinkDevice = d
        )
        .or([
          ((m) =>
            return m.match(' startDefault', (m) =>
              setCommand('start')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' start ')
              .matchVariable(optionsString)
          ),
          ((m) =>
            return m.match(' stop', (m) =>
              setCommand('stop')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' lock', (m) =>
              setCommand('lock')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' unlock', (m) =>
              setCommand('unlock')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' startCharge', (m) =>
              setCommand('startCharge')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' stopCharge', (m) =>
              setCommand('stopCharge')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' refresh', (m) =>
              setCommand('refresh')
              match = m.getFullMatch()
            )
          )
        ])

      match = m.getFullMatch()
      if match? #m.hadMatch()
        env.logger.debug "Rule matched: '", match, "' and passed to Action handler"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new BluelinkActionHandler(@framework, bluelinkDevice, @command, @options)
        }
      else
        return null


  class BluelinkActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @bluelinkDevice, @command, @options) ->

    executeAction: (simulate) =>
      if simulate
        return __("would have cleaned \"%s\"", "")
      else

        if @options?
          _var = @options.slice(1) if @options.indexOf('$') >= 0
          _options = @framework.variableManager.getVariableValue(_var)
          unless _options?
            return __("\"%s\" Rule not executed, #{_var} is not a valid variable", "")
        else
          _options = null

        @bluelinkDevice.execute(@command, _options)
        .then(()=>
          return __("\"%s\" Rule executed", @command)
        ).catch((err)=>
          return __("\"%s\" Rule not executed", "")
        )

  class KiaDevice extends BluelinkDevice

  class HyundaiDevice extends BluelinkDevice


  bluelinkPlugin = new BluelinkPlugin
  return bluelinkPlugin
