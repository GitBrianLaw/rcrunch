library(crunchy)
options(httpcache.log="")
# setwd('~/Desktop/rcrunch/vignettes/shiny/')
shinyServer(function(input, output, session) {
    dataset <- shinyDataset("Economist/YouGov Weekly Survey")
    in_pid <- reactive(if (length(input$pid) == 0) c(1:3) else as.numeric(input$pid))
    ds <- reactive(dataset()[dataset()$pid3 %in% in_pid()])
    output$plot_age <- renderPlot({
      par(las=1); par(mar=c(2,2,2,0))
      hist(as.vector(ds()$age), main='Age')
    })
}) 
