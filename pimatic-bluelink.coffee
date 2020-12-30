module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  Bluelinky = require('kuvork')

  class BluelinkPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-bluelink-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @username = @config.username # "email@domain.com";
      @password = @config.password #"a1b2c3d4";
      @region = @config.region ? 'EU'
      @pin = @config.pin

      @clientReady = false
      @pollTime = @config.pollTime ? 120000

      @framework.variableManager.waitForInit()
      .then ()=>
        @client = new Bluelinky(
          username: @username
          password: @password
          region: @region
          pin: @pin
        )
        @client.on 'ready',() =>
          env.logger.debug "Plugin bluelink client ready"
          @clientReady = true
          @emit "clientReady"
      .catch (err)=>
        env.logger.debug "Bluelink error client created: " + JSON.stringify(err,null,2)


      @framework.deviceManager.registerDeviceClass('KiaDevice', {
        configDef: @deviceConfigDef.KiaDevice,
        createCallback: (config, lastState) => new KiaDevice(config, lastState, @, @client, @framework)
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
              _did = (carConfig.nickname).split(' ').join("_").toLowerCase()
              if _.find(@framework.deviceManager.devicesConfig,(d) => (d.id).indexOf(_did)>=0)
                env.logger.info "Device '" + _did + "' already in config"
              else
                config =
                  id: (carConfig.nickname).split(' ').join("_")
                  name: carConfig.nickname
                  class: "KiaDevice"
                  vin: carConfig.vin
                  vehicleId: carConfig.id
                  type: carConfig.name
                @framework.deviceManager.discoveredDevice( "Bluelink", config.name, config)
          ).catch((e) =>
            env.logger.error 'Error in getVehicles: ' +  e.message
          )
      )

  class KiaDevice extends env.devices.Device

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
        labels: ["yes","no"]
      pluggedIn:
        description: "If vehicle is pluggedIn"
        type: "boolean"
        acronym: "pluggedIn"
        labels: ["yes","no"]
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

      @statusPolltime = @plugin.pollTime

      @_engine = laststate?.engine?.value ? false
      @_airco = laststate?.airco?.value ? false
      @_door = laststate?.door?.value ? false
      @_charging = laststate?.charging?.value ? false
      @_battery = laststate?.battery?.value
      @_pluggedIn = laststate?.plugedIn?.value
      @_odo = laststate?.odo?.value
      @_lat = laststate?.lat?.value
      @_lon = laststate?.lon?.value

      @plugin.on 'clientReady', () =>
        env.logger.debug "requesting vehicle"
        @vehicle = @plugin.client.getVehicle(@config.vin)
        env.logger.debug "starting status update cyle"

      @framework.variableManager.waitForInit()
      .then ()=>
        unless @plugin.clientReady and @statusTimer?
          env.logger.debug "requesting vehicle"
          @vehicle = @plugin.client.getVehicle(@config.vin)
          env.logger.debug "starting status update cyle"
          getStatus()

      getStatus = () =>
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
          @statusTimer = setTimeout(getStatus, @statusPolltime)
        else
          env.logger.debug "requesting status, client not ready"
          @statusTimer = setTimeout(getStatus, 5000)

      super()

    handleLocation: (location) =>
      @setLocation(location.latitude, location.longitude)

    handleOdo: (odo) =>
      @setOdo(odo.value)

    handleStatus: (status) =>
      env.logger.debug "Status: " + JSON.stringify(status,null,2)
      if status.doorLock?
        @setDoor(status.doorLock)
      if status.engine?
        @setEngine(status.engine)
      if status.airCtrlOn?
        @setAirco(status.airCtrlOn)
      if status.evStatus?
        @setEvStatus(status.evStatus)

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
            switch _key
              when "defrost"
                climateOptions.defrost = Boolean _val
              when "windscreenHeating"
                climateOptions.windscreenHeating = Boolean _val
              when "temperature"
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
              @setLock(true)
              env.logger.debug "Locked: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error lock car: " + JSON.stringify(err,null,2)
              reject()
          when "unlock"
            @vehicle.unlock()
            .then (resp)=>
              @setLock(false)
              env.logger.debug "Unlocked: " + JSON.stringify(resp,null,2)
              resolve()
            .catch (err) =>
              env.logger.debug "Error unlock car: " + JSON.stringify(err,null,2)
              reject()
          when "startCharge"
            @vehicle.startCharge()
            .then (resp)=>
              @setCharge(true)
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
          else
            env.logger.debug "Unknown command " + command
            reject()
        resolve()
      )

    getEngine: -> Promise.resolve(@_engine)
    getAirco: -> Promise.resolve(@_airco)
    getDoor: -> Promise.resolve(@_door)
    getCharging: -> Promise.resolve(@_charging)
    getBattery: -> Promise.resolve(@_battery)
    getPluggedIn: -> Promise.resolve(@_pluggedIn)
    getOdo: -> Promise.resolve(@_odo)
    getLat: -> Promise.resolve(@_lat)
    getLon: -> Promise.resolve(@_lon)

    setEngine: (_status) =>
      @_engine = Boolean _status
      @emit 'engine', _status

    setDoor: (_status) =>
      @_door = Boolean _status
      @emit 'door', _status

    setEvStatus: (evStatus) =>
      @_battery = Number evStatus.batteryStatus
      @emit 'battery', @_battery
      @_pluggedIn = evStatus.batteryPlugin > 0
      @emit 'pluggedIn', @_pluggedIn
      @_charging = Boolean evStatus.batteryCharge
      @emit 'charging', @_charging
      if @_charging
        @_pluggedIn = true
        @emit 'pluggedIn', @_pluggedIn

    setAirco: (_status) =>
      @_airco = Boolean _status
      @emit 'airco', _status

    setOdo: (_status) =>
      @_odo = Number _status
      @emit 'odo', _status

    setLocation: (_lat, _lon) =>
      @_lat = _lat
      @_lon = _lon
      @emit 'lat', _lat
      @emit 'lon', _lon

    setCharge: (charge) =>
      @_charging = Boolean charge
      @emit 'charging', @_charging
      if charge
        @_pluggedIn = true
        @emit 'pluggedIn', @_pluggedIn

    destroy:() =>
      clearTimeout(@statusTimer) if @statusTimer?
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
          )])

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

  bluelinkPlugin = new BluelinkPlugin
  return bluelinkPlugin
