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
        createCallback: (config, lastState) => new KiaDevice(config, lastState, @, @client)
      })

      #@framework.ruleManager.addActionProvider(new BluelinkActionProvider(@framework))

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
                  class: "BluelinkDevice"
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
      location:
        description: "The cars location"
        type: "string"
        acronym: "lat/lon"

    
    constructor: (config, lastState, @plugin, client) ->
      @config = config
      @id = @config.id
      @name = @config.name
      @client = @plugin.client

      @statusPolltime = 60000

      @_engine = laststate?.engine?.value ? false
      @_door = laststate?.door?.value ? false
      @_charging = laststate?.charging?.value ? false
      @_battery = laststate?.battery?.value
      @_odo = laststate?.odo?.value
      @_location = laststate?.location?.value

      @plugin.on 'clientReady', () =>
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
        else
          env.logger.debug "requesting status, client not ready"
        @statusTimer = setTimeout(getStatus, @statusPolltime)

      super()

    handleLocation: (status) =>
      _location = status.latitude + ", "+ status.longitude
      env.logger.debug "Location: " + _location
      @setLocation(_location)

    handleOdo: (status) =>
      env.logger.debug "Odo status " + status.value
      @setOdo(Math.round status.value)

    handleStatus: (status) =>

      env.logger.debug "Status: " + JSON.stringify(status,null,2)

      if status.doorLock?
        @setDoor(status.doorLock)
      if status.engine?
        @setEngine(status.engine)
      if status.evStatus?.batteryCharge?
        @setCharging(status.evStatus.batteryCharge)
      if status.evStatus?.batteryStatus?
        @setBattery(status.evStatus.batteryStatus)

      #@vehicleStatus
      ###
      export interface VehicleStatus {
        engine: {
          ignition: boolean;
          batteryCharge?: number;
          charging?: boolean;
          timeToFullCharge?: unknown;
          range: number;
          adaptiveCruiseControl: boolean;
        };
        climate: {
          active: boolean;
          steeringwheelHeat: boolean;
          sideMirrorHeat: boolean;
          rearWindowHeat: boolean;
          temperatureSetpoint: number;
          temperatureUnit: number;
          defrost: boolean;
        };
        chassis: {
          hoodOpen: boolean;
          trunkOpen: boolean;
          locked: boolean;
          openDoors: {
            frontRight: boolean;
            frontLeft: boolean;
            backLeft: boolean;
            backRight: boolean;
          };
          tirePressureWarningLamp: {
            rearLeft: boolean;
            frontLeft: boolean;
            frontRight: boolean;
            rearRight: boolean;
            all: boolean;
          };
        };
      }
      ###

    execute: (command) =>
      return new Promise((resolve,reject) =>
        ### start options
        - airCtrl, string,  Turn on the HVAC
        - igniOnDuration, string,  How long to run (max 10)
        - airTempvalue,  region,  Temp in Fahrenheit
        - defrost, boolean, Turn on defrosters, side mirrors, etc
        - heating1,  string,  yes (EU)

        VehicleStartOptions {
          airCtrl?: boolean | string;
          igniOnDuration: number;
          airTempvalue?: number;
          defrost?: boolean | string;
          heating1?: boolean | string;
        }

        body: {
          action: 'start',
          hvacType: 0,
          options: {
            defrost: config.defrost,
            heating1: config.windscreenHeating ? 1 : 0,
          },
        tempCode: getTempCode(config.temperature),
        unit: config.unit, ('C')
        },
        ###
        climateOptions = {}
        switch command
          when "start"
            @vehicle.start(climateOptions)
            .then (resp)=>
              resolve()
            .catch (err) =>
              env.logger.debug "Error start car: " + JSON.stringify(err,null,2)
              reject()
          when "stop"
            @vehicle.stop(climateOptions)
            .then (resp)=>
              resolve()
            .catch (err) =>
              env.logger.debug "Error stop car: " + JSON.stringify(err,null,2)
              reject()
            resolve()
          when "lock"
            @vehicle.lock()
            .then (resp)=>
              resolve()
            .catch (err) =>
              env.logger.debug "Error lock car: " + JSON.stringify(err,null,2)
              reject()
            resolve()
          when "unlock"
            @vehicle.unlock()
            .then (resp)=>
              resolve()
            .catch (err) =>
              env.logger.debug "Error unlock car: " + JSON.stringify(err,null,2)
              reject()
            resolve()
          when "startCharge"
            @vehicle.startCharge()
            .then (resp)=>
              resolve()
            .catch (err) =>
              env.logger.debug "Error startCharge car: " + JSON.stringify(err,null,2)
              reject()
            resolve()
          when "stopCharge"
            @vehicle.stopCharge()
            .then (resp)=>
              resolve()
            .catch (err) =>
              env.logger.debug "Error stopCharge car: " + JSON.stringify(err,null,2)
              reject()
            resolve()
          else
            env.logger.debug "Unknown command " + command
            reject()
        resolve()
      )

    getEngine: -> Promise.resolve(@_engine)
    getDoor: -> Promise.resolve(@_door)
    getCharging: -> Promise.resolve(@_charging)
    getBattery: -> Promise.resolve(@_battery)
    getOdo: -> Promise.resolve(@_odo)
    getLocation: -> Promise.resolve(@_location)

    setEngine: (_status) =>
      @_engine = Boolean _status
      @emit 'engine', _status

    setDoor: (_status) =>
      @_door = Boolean _status
      @emit 'door', _status

    setCharging: (_status) =>
      @_charging = Boolean _status
      @emit 'charging', _status

    setBattery: (_status) =>
      @_battery = Number _status
      @emit 'battery', _status

    setOdo: (_status) =>
      @_odo = Number _status
      @emit 'odo', _status

    setLocation: (_location) =>
      @_location = _location
      @emit 'location', _location


    destroy:() =>
      clearTimeout(@statusTimer) if @statusTimer?
      super()

  class BluelinkActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>

      bluelinkDevice = null
  
      bluelinkDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class == "KiaDevice"
      ).value()

      setCommand = (command) =>
        @command = command

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
            return m.match(' start', (m) =>
              setCommand('start')
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
          )])

      match = m.getFullMatch()
      if match? #m.hadMatch()
        env.logger.debug "Rule matched: '", match, "' and passed to Action handler"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new BluelinkActionHandler(bluelinkDevice, @command)
        }
      else
        return null


  class BluelinkActionHandler extends env.actions.ActionHandler

    constructor: (@bluelinkDevice, @command) ->

    executeAction: (simulate) =>
      if simulate
        return __("would have cleaned \"%s\"", "")
      else

        @bluelinkDevice.execute(@command)
        .then(()=>
          return __("\"%s\" Rule executed", @command)
        ).catch((err)=>
          return __("\"%s\" Rule not executed", "")
        )

  bluelinkPlugin = new BluelinkPlugin
  return bluelinkPlugin
