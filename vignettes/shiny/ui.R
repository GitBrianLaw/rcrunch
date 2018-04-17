library(crunchy)
library(shinydashboard)

shinyUI(
  dashboardPage(
    dashboardHeader(disable=TRUE),
    dashboardSidebar(
      selectInput(inputId = "pid", label="Political Party", choices=list("Democrats"=1, "Independents"=2, "Republicans"=3))
    ),
    dashboardBody(
      crunchy:::loadCrunchAssets(),
      crunchy:::crunchAuthPlaceholder(),
      fluidRow(
        box(plotOutput("plot_age", height="250"), width = 6)
      )
    )
  )
)