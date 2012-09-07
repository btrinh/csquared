request   = require 'request'
jsdom     = require 'jsdom'
Models    = require '../models/models'   # Schemas Container
Subjects  = Models.subjects
Meta      = Models.meta
Courses   = Models.courses
baseUrl   = 'https://webapp4.asu.edu/catalog'
jQueryUrl = ['https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js']
class Crawler
  @jsession
  
  getJSession: (cb) ->
    cookieJar = request.jar()
    jsessionid = ''
    that = @
    
    cookie = request.cookie 'onlineCampusSelection=C'
    cookie.value = 'C'
    cookie.path = '/catalog'
    cookieJar.add cookie
    
    options =
      "url": "https://webapp4.asu.edu/catalog/"
      "jar": cookieJar
      "followRedirect": false

    request options, (error, response, body) ->
      if error?
        console.log "Error: #{error}"
      else
        for prop,i  in cookieJar.cookies
          if cookieJar.cookies[i].name == 'JSESSIONID'
            jsessionid = cookieJar.cookies[i].value

      cookie = request.cookie 'JSESSIONID=' + jsessionid
      cookie.value = jsessionid
      cookieJar.add cookie
      that.jsession = jsessionid
      
      cb(cookieJar)
  
  updateCurrentTerm: () ->
    request
      url: "https://webapp4.asu.edu/catalog/TooltipTerms.ext"
    , (error, response, body) ->
      jsdom.env body
      , ['https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js']
      , (errors, window) ->
        $ = window.jQuery
        termList =  $('#termList').find('span a')
        summerTermRegex = /(Summer|Sum)/i
        currentTerm = []
        
        # If first node is not summer, then just use first node
        if termList.eq(0).text()?
          if termList.eq(0).text().match(summerTermRegex) is null
            currentTerm.push termList.eq(0).attr('href').match(/\d+?$/)[0]
            #console.log "CurrentTermID: #{currentTerm}" 
        else
        # Since it is summer, check the next 3 nodes for additional summer terms
          for i in [0..3]
            term = termList.eq(i).text()
            if term?
              if term.match(summerTermRegex)?
                summerTerm = termList.eq(i).attr('href').match(/\d{4}[A-z]?/)[0]
              
                # check if term matches with current year
                summerTermYr = summerTerm.match(/\d(\d{2})\d[A-z]?/)[1]
                currentYr = new Date().getFullYear()
                              .toString().match(/\d{2}$/)[0]
              
                if summerTermYr == currentYr
                  currentTerm.push summerTerm
        
        MetaModel = Meta.model()
        MetaModel.update({}, {currentTerm: currentTerm}
          , {multi:true}, (err, numAffected) ->
              if err?
                console.log "Error: #{err}"
              else
                console.log "Row(s) affected: #{numAffected}"
          )  
        
  getSubjects: () ->
    @getJSession (cookieJar) ->
      request
        url: "https://webapp4.asu.edu/catalog/Subjects.html"
        jar: cookieJar
      , (error, response, body) ->
        jsdom.env body, jQueryUrl, (errors, window) ->
          #String::trim = () -> @replace /^\s+|\s+$/g, ''
          
          $ = window.jQuery
          subjectsNodes = $('#subjectDivs').find('.row')
          
          subjects = []
          names = []
          nRows = subjectsNodes.length
          
          subjectsNodes.each () ->
            subject = $(this).find('div.subject').text()
            name    = $(this).find('div.subjectTitle').text()
            
            # read-only model instance
            SubjectsModel = Subjects.model()
            
            # check if subject already exists
            SubjectsModel.findOne
                subject: subject
              , ['subject']
              , (err, doc) ->
                if doc?
                  console.log "Skipping... #{doc.subject} @ #{new Date()}"
                else
                  console.log "Creating doc for... #{subject} @ #{new Date()}"
                  
                  SubjectsInstance         = Subjects.model(true)
                  SubjectsInstance.subject = subject
                  SubjectsInstance.name    = name
                  
                  SubjectsInstance.save (err, result) ->
                    if err? then console.log "Error: #{err}"
                
                # finished, close mongo connection
                if not --nRows
                  setTimeout(->
                    Models.close()
                  , 1000)
                  console.log "MongoDB connection closed... @ #{new Date()}"

  getCourseList: (subject, termID) ->
    @getJSession (cookieJar) ->
      request
        url: "#{baseUrl}/classlist?s=#{subject}&t=#{termID}&e=all"
        jar: cookieJar
      , (error, response, body) ->
        jsdom.env body, jQueryUrl, (errors, window) ->
          String::trim = () -> @replace /^\s+|\s+$/g, ''
          
          $ = window.jQuery
          courseNodes = $('#CatalogList > tbody > tr')
          nCourses = courseNodes.length
          
          courseNodes.each () ->
            # initial parsed values
            courseNode = $(this)
            courseId = courseNode.find('.classNbrColumnValue a').text().trim()
            number = courseNode.find('.subjectNumberColumnValue')
                        .text().trim().split(/\s/)[1]
            title = courseNode.find('.titleColumnValue a').text().trim()
            units = courseNode.find('.hoursColumnValue').text().trim()
            startDate = courseNode.find('.startDateColumnValue a')
                          .text().trim().split(/\s-\s/g)[0]
            endDate = courseNode.find('.startDateColumnValue a')
                        .text().trim().split(/\s-\s/g)[1].replace(/\(C\)/g, '')
            days = courseNode.find('.dayListColumnValue').text().trim()
            startTime = courseNode.find('.startTimeDateColumnValue')
                          .text().trim()
            endTime = courseNode.find('.endTimeDateColumnValue').text().trim()
            gstudy = courseNode.find('.tooltipRqDesDescrColumnValue .gstip')
                      .text().trim()
            location = courseNode.find('.locationBuildingColumnValue')
                        .text().trim()
            instructorsTmp = courseNode
                              .find('.instructorListColumnValue > span > span')
            openSeats = courseNode.find('.availableSeatsColumnValue')
                          .find('table> tr > td:eq(0)').text().trim()
            maxSeats = courseNode.find('.availableSeatsColumnValue')
                          .find('table> tr > td:eq(2)').text().trim()
            
            lastClosed = null
            lastOpened = null
            status = null
            instructors = []
            
            # further data processing/formatting
            instructorsTmp.each () ->
              #console.log $(this).find('span > span > a').attr('title')
              instructor = $(this).find('span > span > a').attr('title')
              
              if instructor?
                instructor = $(this).find('span > span > a').attr('title')
                              .split('|')[1]
              else
                instructor = $(this).text().trim()
              instructors.push instructor
            
              
            honors = if /Honor/gi.test(title) then true else false
            
            # CourseID given in Y{termID}Y{classId} format to help ensure
            # it is unique.
            courseId = "Y#{termID}Y#{courseId}"
            
            # read-only
            CoursesModel = Courses.model()
            
            CoursesModel.findOne
              courseId: courseId
            , ['courseId', 'openSeats']
            , (err, course) ->
              if course?
                prevOpen = parseInt \
                            course.openSeats[course.openSeats.length - 1]
                openSeats = parseInt openSeats            
                
                condition = courseId: courseId
                update = {}
                
                # class still open
                if openSeats > 0 and prevOpen > 0
                  update =
                    $push:
                      openSeats: openSeats
                      lastOpened: new Date()
                    $set:
                      status: 'Open'
                
                # class still closed
                if openSeats == 0 and prevOpen == 0
                  update =
                    $push:
                      openSeats: openSeats
                      lastClosed: new Date()
                    $set:
                      status: 'Closed'
                
                # class just closed, no available seats
                if openSeats == 0 and prevOpen > 0
                  update =
                    $push:
                      openSeats: openSeats
                      lastClosed: new Date()
                    $set:
                      status: 'Just closed'
                      
                # class just opened, available seats
                if openSeats >  0 and prevOpen == 0
                  update =
                    $push:
                      openSeats: openSeats
                      lastOpened: new Date()
                    $set:
                      status: 'Just opened' 

                CoursesModel.update(condition, update, {}, (err, nAffected) ->
                  if err?
                    console.log "Error updating: #{err}"
                  else
                    console.log "Updated #{courseId} @ #{new Date()}"
                  )
              else
                console.log "New #{courseId.trim()} @ #{new Date()}"
                
                CoursesInst = Courses.model(true)
                CoursesInst.courseId    = courseId
                CoursesInst.subject     = subject
                CoursesInst.number      = number
                CoursesInst.title       = title
                CoursesInst.units       = units
                CoursesInst.startDate   = startDate
                CoursesInst.endDate     = endDate
                CoursesInst.days        = days
                CoursesInst.startTime   = startTime
                CoursesInst.endTime     = endTime
                CoursesInst.gstudy      = gstudy
                CoursesInst.instructor  = instructors
                CoursesInst.honors      = honors
                CoursesInst.openSeats   = [openSeats]
                CoursesInst.maxSeats    = maxSeats
                CoursesInst.status      = status

                if parseInt(openSeats) == 0
                  CoursesInst.lastClosed = [new Date()]
                  CoursesInst.lastOpened = []
                  CoursesInst.status     = 'Closed'
                else
                  CoursesInst.lastClosed = []
                  CoursesInst.lastOpened = [new Date()]
                  CoursesInst.status     = 'Open'

                CoursesInst.save (err) ->
                  if err? then console.log "Error: #{err}"
                
              if not --nCourses
                setTimeout(->
                  Models.close()
                , 1000)
                console.log "MongoDB connection closed... @ #{new Date()}" 

  asyncBatch: (batch) ->
    console.log 'Using #{@jsession}'
    console.log 'working on the batch...'

module.exports = Crawler
