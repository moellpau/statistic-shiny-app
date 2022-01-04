#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

## First specify the packages of interest
packages = c("shiny", "shinyjs",
             "shinydashboard", "ggplot2")

## Now load or install&load all
package.check <- lapply(
  packages,
  FUN = function(x) {
    if (!require(x, character.only = TRUE)) {
      install.packages(x, dependencies = TRUE)
      library(x, character.only = TRUE)
    }
  }
)

if (interactive()) {
  # Define UI for application that draws a histogram
  ui <- dashboardPage(
    skin = "blue",
    # Application title
    dashboardHeader(title = "KI Rechner"),
    
    
    
    # Sidebar with a slider input
    dashboardSidebar(
      sliderInput(
        inputId = "n",
        label = "Stichprobengröße:",
        min = 10,
        max = 1000,
        value = 500,
        step = 10
      ),
      selectInput(
        inputId = "normierung",
        label = "Triff eine Vorauswahl der Normierung:",
        c(
          "IQ (M=100, SD=15)" = 1,
          "Körpergrößen (M=170, SD=10)" = 2,
          "Rendite DAX (M=0, SD=0.05)" = 3,
          "Standard (M=0, SD=1)" = 4
        )
      ),
      sliderInput(
        "niveau",
        "Konfidenzniveau:",
        min = 0.7,
        max = 0.99,
        value = 0.95,
        step = 0.01
      ),
      numericInput(
        inputId = "ewert",
        label = "Erwartungswert",
        value = 100,
        min = 0,
        max = 200
      ),
      numericInput(
        inputId = "sd",
        label = "Standardabweichung",
        value = 15,
        min = 1,
        max = 20
      ),
      actionButton("verteil_mich_button", "Verteile mich!")
    ),
    
    # Show a plot of the generated distribution
    dashboardBody(
      
      useShinyjs(),
      fluidRow (
        box(
          title = "Was sind Konfidenzintervalle?",
          div(HTML("Unter Konfidenzintervallen (KI) sind ein statistische Intervalle zu verstehen, mit welchem man 
                    besser einschätzen kann, wo beispielsweise wie in diesem Fall der wahre Mittelwert eines Datensatzes liegt. 
                   Dieses Konzept wird angewendet, da in der Statistik berechnete Werte oft auf der Grundlage einer Stichprobe zustande kommen.
                   <br> Die Formeln für die Ober- und Untergrenze sind: <br>
                   <math> a = X̅ - 
                    <msub>
                      <mi>Z</mi>
                      <mn>1 - α/2</mn>
                    </msub>
                   *  <mfrac>σ <msqrt> n </msqrt></mfrac></math>"
        ))),
        box(title = "Erklärung der Berechnung",
            uiOutput("berech_erkl"))
      ),
      
      
      fluidRow (
        valueBox(
          textOutput("konfidenzniveau"),
          p("Konfidenzniveau"),
          icon = icon("flag-checkered"),
          color = "light-blue"
        ),
        valueBox(
          textOutput("intervall_a"),
          "Untergrenze des Konfidenzintervalls",
          icon = icon("less-than-equal"),
          color = "olive"
        ),
        valueBox(
          textOutput("intervall_b"),
          "Obergrenze des Konfidenzintervalls",
          icon = icon("greater-than-equal"),
          color = "olive"
        )
      ),
      fluidRow(
        box(
          title = "Datensatz",
          solidHeader = TRUE,
          status = "primary",
          plotOutput("datadiagram")
        ),
        box(
          title = "Konfidenzintervall",
          solidHeader = TRUE,
          status = "primary",
          plotOutput("intervalldiagram"),
        )
      ),
      fluidRow (
        box(title = "Verbale Erklärung",
            uiOutput("verbal_erkl")),
        box(
          title = "Quellen",
          uiOutput("quellen")
        )
      )
      
    )
    
  )
  
  # Define server logic required to draw a histogram
  server <- function(input, output, session) {
    
    observeEvent(input$verteil_mich_button, {
      n <- input$n
      ewert <- input$ewert
      sd <- input$sd
      x.values <- rnorm(n, ewert, sd)
      y.values <- dnorm(x.values, ewert, sd)
      niveau <- input$niveau
      niveau_percentage <- niveau * 100
      alpha <- 1 - niveau
      quantil <- 1 - (alpha / 2)
      z <- qnorm(quantil, 0, 1)
      f <- z * sd / sqrt(n)
      aintervall <- mean(x.values) - f
      bintervall <- mean(x.values) + f
      
      
      output$datadiagram <- renderPlot({
        ggplot(NULL, aes(x = x.values)) + 
          # draw the histogram with the specified number of bins
          geom_histogram (binwidth = 5, color = "#3C8DBC", fill = 'grey') + ylab("Häufigkeit") + xlab("Werte")
        
        
      })
      output$intervalldiagram <- renderPlot({
        ggplot(NULL, aes(x = x.values, y = y.values)) + 
          geom_line() + labs(x = "Werte", y = NULL) +
          scale_y_continuous(breaks = NULL) +
          scale_x_continuous(breaks = c(ewert - 2 * sd,
                                        ewert - sd, ewert,
                                        ewert + sd, ewert + 2 * sd)) +
          geom_vline(aes(xintercept = aintervall), color = "royalblue1") +
          geom_vline(aes(xintercept = bintervall), color = "red") +
         geom_area(data = NULL, aes(y = y.values), fill = "#3C8DBC", color = NA, alpha = .3)
        
      })
      
      
      output$intervall_a <- renderText({
        paste("a =",round(aintervall, digits = 2))
      })
      
      output$intervall_b <- renderText({
        paste("b =", round(bintervall, digits = 2))
      })
      
      output$konfidenzniveau <- renderText({
        paste(niveau_percentage, "%")
      })
      

     
      
      
      output$berech_erkl <- renderUI({
        tagList(
          p(
            "Für eine erste Vorauswahl können über das Drop-Down erste Werte für Erwartungswert und Standardabweichung von Normskalen festgelegt werden.
            Für die Findung und Validierung der Intervalle suchen wir einen Intervall von der Untergrenze",
            em("a"),
            "bis zur Obergrenze",
            em("b"),
            ".",
            "Die Grenzen dieses Intervalles sollen so ermittelt werden, dass mit",
            strong(niveau_percentage, "%"),
            "-iger Wahrscheinlichkeit",
            "(1-\U003B1 = ", niveau, ")",
            "der echte Mittelwert der Grundgesamtheit in ihnen liegt.",
            br(),
            "Dabei ist die Annahme, dass der Intervall symmetrisch und die Werte immer normalverteilt sind und wir die Standardabweichung, in diesem Fall",
            strong("\U003C3", "=", sd),
            "kennen."
          )
        )
      })
      
      output$verbal_erkl <- renderUI({
        tagList(
          p(
            "Der wahre Mittelwert der Stichprobe von ",
            strong(n),
            "Werten befindet sich mit einer Wahrscheinlichkeit von",
            strong(niveau_percentage),
            "% innerhalb des Intervalls",
            strong(round(aintervall, digits = 2)),
            "bis",
            strong(round(bintervall, digits = 2))
          )
        )
      })
      
      output$quellen <- renderUI({
        tagList(
         div(HTML(
         "<ul><li>StudyFlix (2021): Konfidenzintervalle, in: https://studyflix.de/statistik/konfidenzintervall-1580, (Stand: 28.12.2021) </li>
        <li> Schemmel, J. & Ziegler, M. (2020). Der Konfidenzintervall-Rechner: Web-Anwendung zur Berechnung und grafischen Darstellung von Konfidenzintervallen für die testpsychologische Diagnostik. Report Psychologie, 45(1), 16-21. </li>
        <li> Rdrr.iO (2022): shinyjs, in: https://rdrr.io/cran/shinyjs/, (Stand: 04.01.2022). </li>
        <li> RStudio (2022): ShinyDashboard, in: https://rstudio.github.io/shinydashboard/structure.html, (Stand: 04.01.2022). </li>
        <li> Schmuller, J. (2017): Statistik mit R für Dummies, Weinheim. </li>
        <li> Wikipedia (2022): Normwertskala, in: https://de.wikipedia.org/wiki/Normwertskala, (Stand: 04.01.2022). </li><ul>"
          ))
        )
      })
      
    })
    
    click("verteil_mich_button")
    
    observeEvent(input$normierung, {
      if (input$normierung == 1) {
        updateNumericInput(session, "ewert", value = 100)
        updateNumericInput(session, "sd", value = 15)
      }
      else if (input$normierung == 2) {
        updateNumericInput(session, "ewert", value = 170)
        updateNumericInput(session, "sd", value = 10)
      }
      else if (input$normierung == 3) {
        updateNumericInput(session, "ewert", value = 0)
        updateNumericInput(session, "sd", value = 0.05)
      }
      else if (input$normierung == 4) {
        updateNumericInput(session, "ewert", value = 0)
        updateNumericInput(session, "sd", value = 1)
      }
    })
  }
  
  # Run the application
  shinyApp(ui = ui, server = server)
}