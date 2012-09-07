db       = require '../config/db'
mongoose = require 'mongoose'
Schema   = mongoose.Schema

# connect to db
db.init()

module.exports =
  _schema: null
  
  _schemaDef:
    courseId  : type: String, index: true, required: true
    subject   : type: String, index: true
    number    : String
    title     : String
    units     : String
    startDate : Date
    endDate   : Date
    days      : [String]
    startTime : String
    endTime   : String
    genStudy  : String
    instructor: [String]
    honors    : Boolean
    openSeats : [Number]  # last index is the latest update
    maxSeats  : Number
    lastClosed: [Date]    # DateTime logged when class just closes
    lastOpened: [Date]    # DateTime logged when class just opens
    status    : String    # Possible status - Open/Closed, Just Opened/Closed
  
  schema: () ->
    if not module.exports._schema
      module.exports._schema = new mongoose.Schema(module.exports._schemaDef)
    return module.exports._schema
    
  _model: null
  
  model: (newInstance) ->
    if not module.exports._model
      module.exports._model = mongoose.model 'course', module.exports.schema()
    if newInstance?
      return new module.exports._model()
    else
      return module.exports._model