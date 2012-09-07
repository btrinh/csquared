db       = require '../config/db'
mongoose = require 'mongoose'
Schema   = mongoose.Schema

# connect to db
db.init()

module.exports =
  _schema: null

  _schemaDef:
    currentTerm: [String]
  
  schema: () ->
    # if schema has not been defined, create one
    if not module.exports._schema
      module.exports._schema = new mongoose.Schema(module.exports._schemaDef)
    return module.exports._schema
    
  _model: null
  
  model: (newInstance) ->
    if not module.exports._model
      module.exports._model = mongoose.model 'meta', module.exports.schema()
    if newInstance?
      return new module.exports._model()
    else
      return module.exports._model