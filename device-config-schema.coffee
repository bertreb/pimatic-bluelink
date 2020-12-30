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
    }
  }
}
