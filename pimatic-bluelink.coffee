module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  fs = require('fs')
  path = require('path')
  #Bluelinky = require('kuvork')
  Bluelinky = require('bluelinky')

  class BluelinkPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-bluelink-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @username = @config.username # "email@domain.com";
      @password = @config.password #"a1b2c3d4";
      @region = @config.region ? 'EU'
      @pin = @config.pin

      options = 
        username: @username
        password: @password
        region: @region
        pin: @pin
      @brand = @config.brand ? "kia"
      if @brand is "hyundai"
        #Bluelinky = require('bluelinky')
        @_discoveryClass = "HyundaiDevice"
        options["brand"] = "hyundai"
      else
        #Bluelinky = require('kuvork')
        @_discoveryClass = "KiaDevice"
        options["brand"] = "kia"
        options["vin"] = "KNA" #for detecting the Kia or Hyandai api, brand deduction: VIN numbers of KIA are KNA/KNC/KNE

      @client = null
      @clientReady = false

      @framework.on 'after init', ()=>
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js',   "pimatic-bluelink/app/bluelink.coffee"
          mobileFrontend.registerAssetFile 'html', "pimatic-bluelink/app/bluelink.jade"
          mobileFrontend.registerAssetFile 'css',  "pimatic-bluelink/app/bluelink.css"

        @client = new Bluelinky(options)
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

    template: "bluelink"

    actions:
      changeActionTo:
        description: "Sets the action"
        params:
          action:
            type: "string"
    attributes:
      engine:
        description: "Status of engine"
        type: "boolean"
        acronym: "engine"
        labels: ["on","off"]
        hidden: false
      airco:
        description: "Status of airco"
        type: "string"
        acronym: "airco"
        enum: ["start","startPlus","off"]
        hidden: true
      door:
        description: "Status of doorlock"
        type: "boolean"
        acronym: "door"
        labels: ["locked","unlocked"]
        hidden: true
      charging:
        description: "If vehicle is charging"
        type: "boolean"
        acronym: "charging"
        labels: ["on","off"]
        hidden: true
      pluggedIn:
        description: "If vehicle is pluggedIn"
        type: "string"
        acronym: "batteryPlugin"
      chargingTime:
        description: "Time left for charging"
        type: "string"
        acronym: "charging time"
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
      remainingRange:
        description: "Remaining range basing on current battery resp. fuel level"
        type: "number"
        acronym: "remaining"
        unit: "km"        
      twelveVoltBattery:
        description: "The 12 volt battery level"
        type: "number"
        unit: '%'
        acronym: "12V"
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
      maximum:
        description: "Maximum range basing on current battery resp. fuel level"
        type: "string"
        acronym: "maximum"
      lat:
        description: "The cars latitude"
        type: "number"
        acronym: "lat"
      lon:
        description: "The cars longitude"
        type: "number"
        acronym: "lon"
      status:
        description: "The connection status"
        type: "string"
        acronym: "status"


    getTemplateName: -> "bluelink"

    statusCodes =
      init: 0
      ready: 1
      getStatus: 2
      getStatusError: 3 
      commandSend: 4
      commandSuccess: 5
      commanderror: 6
    
    constructor: (config, lastState, @plugin, client, @framework) ->
      @config = config
      @id = @config.id
      @name = @config.name

      @client = @plugin.client

      @pollTimePassive = @config.pollTimePassive ? 3600000 # 1 hour
      @pollTimeActive = @config.pollTimeActive ? 600000 # 10 minutes
      @currentPollTime = @pollTimeActive

      @_defrost = @config.defrost ? false
      @_windscreenHeating = @config.windscreenHeating ? false
      @_temperature = @config.temperature ? 20
      @_optionsVariable = @config.optionsVariable ? ""

      @_engine = laststate?.engine?.value ? false
      @_speed = laststate?.speed?.value ? 0
      @_airco = laststate?.airco?.value ? "off"
      @_door = laststate?.door?.value ? false
      @_charging = laststate?.charging?.value ? false
      @_chargingTime = laststate?.chargingTime?.value ? 0
      @_battery = laststate?.battery?.value ? 0
      @_twelveVoltBattery = laststate?.twelveVoltBattery?.value ? 0
      @_pluggedIn = laststate?.pluggedIn?.value ? "unplugged"
      @_odo = laststate?.odo?.value ? 0
      @_maximum = laststate?.maximum?.value ? 0
      @_remainingRange = laststate?.remainingRange?.value ? 0
      @_doorFrontLeft = laststate?.doorFrontLeft?.value ? 0
      @_doorFrontRight = laststate?.doorFrontRight?.value ? 0
      @_doorBackLeft = laststate?.doorBackLeft?.value ? 0
      @_doorBackRight = laststate?.doorBackRight?.value ? 0
      @_hood = laststate?.hood?.value ? 0
      @_trunk = laststate?.trunk?.value ? 0
      @_lat = laststate?.lat?.value ? 0
      @_lon = laststate?.lon?.value ? 0
      @_status = statusCodes.init
      @setStatus(statusCodes.init)
      retries = 0
      maxRetries = 20

      @vehicle = null

      ###
      @config.xAttributeOptions = [] unless @config.xAttributeOptions?
      for i, _attr of @attributes
        do (_attr) =>
          if _attr.type is 'number'
            _hideSparklineNumber = 
              name: i
              displaySparkline: false
            @config.xAttributeOptions.push _hideSparklineNumber
      ###

      @plugin.on 'clientReady', @clientListener = () =>
        unless @statusTimer? 
          env.logger.debug "Plugin ClientReady, requesting vehicle"
          @vehicle = @plugin.client.getVehicle(@config.vin)
          env.logger.debug "From plugin start - starting status update cyle"
          @setStatus(statusCodes.ready)
          @getCarStatus(true) # actual car status on start
        else
          env.logger.debug "Error: plugin start but @statusTimer alredy running!"

      @framework.variableManager.waitForInit()
      .then ()=>
        if @plugin.clientReady and not @statusTimer?
          env.logger.debug "ClientReady ready, Device starting, requesting vehicle"
          @vehicle = @plugin.client.getVehicle(@config.vin)
          env.logger.debug "From device start - starting status update cyle"
          @setStatus(statusCodes.ready)
          @getCarStatus(true) # actual car status on start

      @getCarStatus = (_refresh=false) =>
        if @plugin.clientReady
          clearTimeout(@statusTimer) if @statusTimer?
          env.logger.debug "requesting status, refresh: " + _refresh
          @setStatus(statusCodes.getStatus)
          @vehicle.status({refresh:_refresh})
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
            @setStatus(statusCodes.ready)
          .catch (e) =>
            @setStatus(statusCodes.getStatusError)
            env.logger.debug "getStatus error: " + JSON.stringify(e.body,null,2)
          @statusTimer = setTimeout(@getCarStatus, @currentPollTime)
          env.logger.debug "Next poll in " + @currentPollTime + " ms"
        else
          env.logger.debug "(re)requesting status in 5 seconds, client not ready"
          retries += 1
          if retries < maxRetries
            @statusTimer = setTimeout(@getCarStatus, 5000)
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
        if status.airCtrlOn
          @setAirco("start")
        else
          @setAirco("off")
      if status.battery?.batSoc?
        @setTwelveVoltBattery(status.battery.batSoc)
      if status.evStatus?
        @setEvStatus(status.evStatus)

      #update polltime to active if engine is on, charging or airco is on 
      active = (Boolean status.engine) or (Boolean status.evStatus.batteryCharge) or (Boolean status.airCtrlOn)
      env.logger.debug "Car status PollTimeActive is " + active
      @setPollTime(active)

    parseOptions: (_options) ->
      climateOptions =
        defrost: @_defrost
        windscreenHeating: @_windscreenHeating
        temperature: @_temperature
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


    changeActionTo: (action) =>

      _action = action
      options = null
      if action is "startPlus"
        if @_optionsVariable isnt ""
          _optionsString = @framework.variableManager.getVariableValue(@_optionsVariable)
          if _optionsString?
            options = _optionsString
          else
            return Promise.reject("optionsVariable '#{@_optionsVariable}' does not exsist")
        else
          return Promise.reject("No optionsVariable defined")
      return @execute(_action, options)


    execute: (command, options) =>
      return new Promise((resolve,reject) =>

        unless @vehicle? then return reject("No active vehicle")

        @setStatus(statusCodes.commandSend, command)
        switch command
          when "start"
            env.logger.debug "Start with options: " + JSON.stringify(@parseOptions(options),null,2)
            @vehicle.start(@parseOptions(options))
            .then (resp)=>
              env.logger.debug "Started: " + JSON.stringify(resp,null,2)
              #@setEngine(true)
              @setAirco("start")
              @setPollTime(true) # set to active poll
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error start car: " + JSON.stringify(err,null,2)
              reject()
          when "startPlus"
            env.logger.debug "StartPlus with options: " + JSON.stringify(@parseOptions(options),null,2)
            @vehicle.start(@parseOptions(options))
            .then (resp)=>
              env.logger.debug "Started: " + JSON.stringify(resp,null,2)
              #@setEngine(true)
              @setAirco("startPlus")
              @setPollTime(true) # set to active poll
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error start car: " + JSON.stringify(err,null,2)
              reject()
          when "stop"
            @vehicle.stop()
            .then (resp)=>
              #@setEngine(false)
              @setAirco("off")
              env.logger.debug "Stopped: " + JSON.stringify(resp,null,2)
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error stop car: " + JSON.stringify(err,null,2)
              reject()
          when "lock"
            @vehicle.lock()
            .then (resp)=>
              @setDoor(true)
              env.logger.debug "Locked: " + JSON.stringify(resp,null,2)
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error lock car: " + JSON.stringify(err,null,2)
              reject()
          when "unlock"
            @vehicle.unlock()
            .then (resp)=>
              @setDoor(false)
              @setPollTime(true) # set to active poll
              env.logger.debug "Unlocked: " + JSON.stringify(resp,null,2)
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error unlock car: " + JSON.stringify(err,null,2)
              reject()
          when "startCharge"
            @vehicle.startCharge()
            .then (resp)=>
              @setCharge(true)
              @setPollTime(true) # set to active poll
              env.logger.debug "startCharge: " + JSON.stringify(resp,null,2)
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error startCharge car: " + JSON.stringify(err,null,2)
              reject()
          when "stopCharge"
            @vehicle.stopCharge()
            .then (resp)=>
              @setCharge(false)
              env.logger.debug "stopCharge: " + JSON.stringify(resp,null,2)
              @setStatus(statusCodes.commandSuccess, command)
              resolve()
            .catch (err) =>
              @setStatus(statusCodes.commandError, command)
              env.logger.debug "Error stopCharge car: " + JSON.stringify(err,null,2)
              reject()
          when "refresh"
            clearTimeout(@statusTimer) if @statusTimer?
            @getCarStatus(true)           
            env.logger.debug "refreshing status"
            @setStatus(statusCodes.commandSuccess, command)
            resolve()
          else
            @setStatus(statusCodes.commandError, command)
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
    getTwelveVoltBattery: -> Promise.resolve(@_twelveVoltBattery)
    getPluggedIn: -> Promise.resolve(@_pluggedIn)
    getOdo: -> Promise.resolve(@_odo)
    getSpeed: -> Promise.resolve(@_speed)
    getMaximum: -> Promise.resolve(@_maximum)
    getRemainingRange: -> Promise.resolve(@_remainingRange)
    getLat: -> Promise.resolve(@_lat)
    getLon: -> Promise.resolve(@_lon)
    getStatus: -> Promise.resolve(@_status)
    getChargingTime: -> Promise.resolve(@_chargingTime)


    setStatus: (status, command)=>
      switch status
        when statusCodes.init
          _status = "initializing"
        when statusCodes.ready
          _status = "ready"
        when statusCodes.getStatus
          _status = "get status"
        when statusCodes.getStatusError
          _status = "get status error"
        when statusCodes.commandSend
          _status = "execute " + command
        when statusCodes.commandSuccess
          _status = command + " executed"
          setTimeout(=> 
            @setStatus(statusCodes.ready)
          ,3000)
        when statusCodes.commandError
          _status = command + " error"
        else
          _status = "unknown status " + status

      @_status = _status
      @emit 'status', _status

    setPollTime: (active) =>
      # true is active, false is passive
      if (active and @currentPollTime == @pollTimeActive) or (!active and @currentPollTime == @pollTimePassive) then return

      #env.logger.debug("Test for active " + active + ", @currentPollTime:"+@currentPollTime+", @pollTimePassive:"+@pollTimePassive+", == "+ (@currentPollTimer == @pollTimePassive))
      if (active) and (@currentPollTime == @pollTimePassive)
        clearTimeout(@statusTimer) if @statusTimer?
        @currentPollTime = @pollTimeActive
        env.logger.debug "Switching to active poll, with polltime of " + @pollTimeActive + " ms"
        @statusTimer = setTimeout(@getCarStatus, @pollTimeActive)
        return

      if not active and @currentPollTime == @pollTimeActive
        clearTimeout(@statusTimer) if @statusTimer?
        @currentPollTime = @pollTimePassive
        env.logger.debug "Switching to passive poll, with polltime of " + @pollTimePassive + " ms"
        @statusTimer = setTimeout(@getCarStatus, @pollTimePassive)

    setMaximum: (_range) =>
      @_maximum = _range
      @emit 'maximum', _range

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

    setTwelveVoltBattery: (_status) =>
      @_twelveVoltBattery = Number _status # Math.round (_status / 2.55 )
      @emit 'twelveVoltBattery', Number _status # Math.round (_status / 2.55 )

    setChargingTime: (_status) =>
      @_chargingTime = _status
      @emit 'chargingTime', _status

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
      switch evStatus.batteryPlugin
        when 0
          @_pluggedIn = "unplugged"
          _chargingTime = "no value"
        when 1
          @_pluggedIn = "DC"
          _chargingTime = evStatus.remainTime2.etc1.value + "min (DC)"
        when 2
          #@_pluggedIn = "ACportable"
          #_chargingTime = evStatus.remainTime2.etc2.value + "min (ACport)"
          @_pluggedIn = "AC"
          _chargingTime = evStatus.remainTime2.etc3.value + "min (AC)"
        when 3
          @_pluggedIn = "AC"
          _chargingTime = evStatus.remainTime2.etc3.value + "min (AC)"
        else
          @_pluggedIn = "unknown"
          _chargingTime = ""
      @setChargingTime(_chargingTime)

      @emit 'pluggedIn', @_pluggedIn
      @_charging = Boolean evStatus.batteryCharge
      @emit 'charging', Boolean evStatus.batteryCharge
      #if @_charging
      #  @_pluggedIn = true
      #  @emit 'pluggedIn', (evStatus.batteryPlugin > 0)

      # DC maximum
      if evStatus.reservChargeInfos.targetSOClist?[0]?.dte?.rangeByFuel?.totalAvailableRange?.value?
        _maximumDC = Number evStatus.reservChargeInfos.targetSOClist[0].dte.rangeByFuel.totalAvailableRange.value
        _maximumDCperc = Number evStatus.reservChargeInfos.targetSOClist[0].targetSOClevel
      if evStatus.reservChargeInfos.targetSOClist?[1]?.dte?.rangeByFuel?.totalAvailableRange?.value?
        _maximumAC = Number evStatus.reservChargeInfos.targetSOClist[1].dte.rangeByFuel.totalAvailableRange.value
        _maximumACperc = Number evStatus.reservChargeInfos.targetSOClist[1].targetSOClevel
      if _maximumDC? and _maximumAC?
        _maximum = _maximumDC + "km (DC@" + _maximumDCperc + "%) " + _maximumAC + "km (AC@" + _maximumACperc + "%)"
        @setMaximum(_maximum)
      else
        @setMaximum("no value")
      if evStatus.drvDistance?[0]?.rangeByFuel?.totalAvailableRange?.value?
        _remainingRange = Number evStatus.drvDistance[0].rangeByFuel.totalAvailableRange.value
        if _remainingRange > 0
          @setRemainingRange(_remainingRange)


    setAirco: (_status) =>
      @_airco = _status
      @emit 'airco', _status

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
      #if charging
      #  @_pluggedIn = true # if charging, must be pluggedIn
      #  @emit 'pluggedIn', @_pluggedIn

    destroy:() =>
      clearTimeout(@statusTimer) if @statusTimer?
      @plugin.removeListener('clientReady', @clientListener)
      super()

  class BluelinkActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>

      bluelinkDevice = null
      @options = null
      supportedCarClasses = ["KiaDevice","HyundaiDevice"]
  
      bluelinkDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class in supportedCarClasses
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
            return m.match(' startPlus', (m) =>
              setCommand('startPlus')
              match = m.getFullMatch()
            )
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
