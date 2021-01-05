# #pimatic-bluelink configuration options
module.exports = {
  title: "pimatic-bluelink configuration options"
  type: "object"
  properties:
    username:
      descpription: "The username of your Bluelink account"
      type: "string"
    password:
      descpription: "The password of your Bluelink account"
      type: "string"
    region:
      descpription: "Your region code"
      type: "string"
      enum: ["EU","US","CA"]
    pin:
      descpription: "The pin for unlocking"
      type: "string"
    brand:
      description: "The supported car brand"
      type: "string"
      enum: ["kia","hyundai"]
      default: "kia"
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
}
