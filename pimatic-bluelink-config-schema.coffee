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
    pollTime:
      description: "The polltime in ms between status polls"
      type: "number"
      default: 120000
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
}
