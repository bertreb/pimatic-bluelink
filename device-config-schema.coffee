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
    }
  }
}
