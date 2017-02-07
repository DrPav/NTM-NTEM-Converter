library(shiny)

shinyUI(fluidPage(
  
  # Application title
  titlePanel("NTEM to NTM converter"),
  
  fluidRow(
    wellPanel(
      textInput("cTripends_directory", label = "cTripEnds folder", value = "C:\\ctripends_folder"),
      textInput('output_directory', label = 'Folder for output files', value = 'C:\\output_folder'),
      radioButtons('ulc_type', "ULC file type", list("Base" = "base", "Policy" = "policy")),
      actionButton('go_button', "Go")
    )

    
  )
))