library(shiny)
#TidyVerse packages
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
#Other packages
library(RODBC) # for read ms access databases (32 bit R)
library(gdata) # for write fixed width format

source("R functions/01-replicate NTEM_NTS_Link spreadsheet.R")
source("R functions/02-replicate P1_UKC_NTEMv2R spreadsheet.R")


shinyServer(function(input, output, session) {
  observeEvent(input$go_button, {
    #Set up the progress bar
    progress <- Progress$new(session, min=1, max=4)
    on.exit(progress$close())
    progress$set(message = 'Converting NTEM to ULC files',
                 detail = 'This may take a while...')
    #Functions are loaded at the top from the R functions folder
    #Increment the progress bar each time a function is run
    progress$inc(amount = 1)
    #Extrap productions and attractions for all years
    extract_and_transform(input$cTripends_directory, input$output_directory)
    progress$inc(amount = 1)
    #Interpolate to NTM years
    generate_interpolations(input$output_directory)
    progress$inc(amount = 1)
    #Convert into ULC files
    generate_ulc_files(input$output_directory, input$ulc_type)
    progress$inc(amount = 1)
  })

})