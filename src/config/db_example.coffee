mongoose = require 'mongoose'

db =
  _db: null,
  user: username
  pass: password
  host: host
  port: 10087
  name: "csquared"
  init: () ->
    if not @_db
      @_db = mongoose.connect "mongodb://" +
        "#{@user}:#{@pass}@#{@host}:#{@port}/#{@name}"

module.exports = db