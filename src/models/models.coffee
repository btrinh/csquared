mongoose = require 'mongoose'

module.exports =
  courses: require './courses'
  subjects: require './subjects'
  meta: require './meta'
  close: () ->
    mongoose.disconnect()
