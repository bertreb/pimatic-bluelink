module.exports = {
  title: "pimatic-bluelink devices config schemas"
  KiaDevice: {
    title: "KiaDevice config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:{
      vin:
        description: "The cars vin"
        type: "string"
      vehicleId:
        description: "The cars vehicleId"
        type: "string"
      type:
        description: "The cars type"
        type: "string"
      defrost: 
        description: "Deforsting the screen, when remote starting the airco"
        type: "boolean"
        default: false
      windscreenHeating: 
        description: "Windscreen heating, when remote starting the airco"
        type: "boolean"
        default: false
      temperature: 
        description: "Target car temperature (C), when remote starting the airco"
        type: "number"
        default: 20
      optionsVariable:
        description: "Options variable name (without $) when starting airco+"
        type: "string"
        default: ""
      pollTimePassive:
        description: "The polltime in ms between status polls in passive mode (1 hour)"
        type: "number"
        default: 3600000
      pollTimeActive:
        description: "The polltime in ms between status polls in active mode (10 minutes)"
        type: "number"
        default: 600000
    }
  }
  HyundaiDevice: {
    title: "HyundaiDevice config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:{
      vin:
        description: "The cars vin"
        type: "string"
      vehicleId:
        description: "The cars vehicleId"
        type: "string"
      type:
        description: "The cars type"
        type: "string"
      defrost: 
        description: "Deforsting the screen, when remote starting the airco"
        type: "boolean"
        default: false
      windscreenHeating: 
        description: "Windscreen heating, when remote starting the airco"
        type: "boolean"
        default: false
      temperature: 
        description: "Target car temperature (C), when remote starting the airco"
        type: "number"
        default: 20
      optionsVariable:
        description: "Options variable name (without $) when starting airco+"
        type: "string"
        default: ""
      pollTimePassive:
        description: "The polltime in ms between status polls in passive mode (1 hour)"
        type: "number"
        default: 3600000
      pollTimeActive:
        description: "The polltime in ms between status polls in active mode (10 minutes)"
        type: "number"
        default: 600000
    }
  }

}
