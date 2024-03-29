#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#


library(shiny)
library(shinyjs)
library(shinydashboard)
library(ggplot2)
library(rsconnect)


# Define UI for application
ui <- dashboardPage(
  skin = "blue",
  # Application title
  dashboardHeader(title = "KI Rechner"),
  
  # Sidebar with a inputs
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
      label = "Triff eine Vorauswahl der Normwertskala:",
      c(
        "IQ-Norm" = 1,
        "Leistungsskala der PISA-Studien" = 2,
        "T-Skala" = 3,
        "z-Skala" = 4
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
      max = 500
    ),
    numericInput(
      inputId = "sd",
      label = "Standardabweichung",
      value = 15,
      min = 1,
      max = 100
    ),
    actionButton("verteil_mich_button", "Verteile mich!")
  ),
  
  # Dashboard body with text boxes, values boxes and plots
  dashboardBody(
    useShinyjs(),
    
    fluidRow (
      box(title = "Was sind Konfidenzintervalle?",
          uiOutput("konfidenz")),
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
        title = "Datensatz der Stichprobe",
        solidHeader = TRUE,
        status = "primary",
        plotOutput("datadiagram")
      ),
      box(
        title = "Konfidenzintervall um den geschätzten Erwartungswert",
        solidHeader = TRUE,
        status = "primary",
        plotOutput("intervalldiagram"),
      )
    ),
    
    fluidRow (
      box(title = "Verbale Erklärung",
          uiOutput("verbal_erkl")),
      box(title = "Formeln zur Berechnung",
          uiOutput("formeln"))
    ),
    
    fluidRow (
      box(title = "Unterschied der beiden Diagramme",
          uiOutput("unterschied")),
      box(title = "Quellen",
          uiOutput("quellen"))
    )
  )
  
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
  observeEvent(input$verteil_mich_button, {
    #Define variables and calculate borders of konfidenzintervall
    n <- input$n
    ewert <- input$ewert
    sd <- input$sd
    xsd <- sd / sqrt(input$n)
    
    x.values <- rnorm(n, ewert, sd)
    y.values <- dnorm(x.values, ewert, xsd)
    
    data <- data.frame(x.values, y.values)
    
    niveau <- input$niveau
    niveau_percentage <- niveau * 100
    alpha <- 1 - niveau
    quantil <- 1 - (alpha / 2)
    
    z <- qnorm(quantil, 0, 1)
    f <- z * xsd
    
    mean <- mean(x.values)
    
    aintervall <- mean - f
    bintervall <- mean + f
    
    delta_intervall <- abs(bintervall - aintervall)
    
    # Render plot of datadiagram
    output$datadiagram <- renderPlot({
      ggplot(NULL, aes(x = x.values)) +
        # draw the histogram with the specified number of bins
        geom_histogram (aes(y = ..density..),
                        binwidth = 1,
                        fill = 'grey')  +
        geom_density(alpha = .2, fill = "#3C8DBC") +
        geom_vline(aes(xintercept = aintervall), color = "#3D9970")  +
        geom_vline(aes(xintercept = bintervall), color = "#3D9970") + ylab("Dichte") + xlab("Skala der Normwerte")
    })
    
    # Render plot of intervalldiagram
    output$intervalldiagram <- renderPlot({
      ggplot(data = data, aes(x = x.values, y = y.values)) +
        scale_y_continuous(breaks = NULL) +
        scale_x_continuous(breaks = c(ewert - 2 * xsd,
                                      ewert - xsd, ewert,
                                      ewert + xsd, ewert + 2 * xsd)) +
        geom_line() + labs(x = "Skala der Normwerte", y = NULL) +
        geom_vline(aes(xintercept = aintervall), color = "#3D9970") +
        geom_vline(aes(xintercept = bintervall), color = "#3D9970") +
        geom_area(
          data = subset(data, x.values > aintervall
                        & x.values < bintervall),
          aes(y = y.values),
          fill = "#3C8DBC",
          alpha = .3
        ) +
        xlim(aintervall - (delta_intervall/2), bintervall + (delta_intervall/2)) +
        geom_segment(aes(
          x = ewert,
          y = 0,
          xend = ewert,
          yend = dnorm(ewert, ewert, xsd)
        ), size = 0.5)  +
        geom_errorbarh(
          aes(
            y = 0,
            xmin = aintervall,
            xmax = bintervall),
          height = 0.03 / xsd,
          colour = "black"
        ) +
      annotate(
        geom = "text",
        x = ewert,
        y = 0,
        label = "Erwartungswert",
        angle = 90,
        vjust = -0.5,
        hjust = -1.0,
        size = 4
      ) +
        annotate(
          geom = "text",
          x = aintervall,
          y = 0,
          label = "Untergrenze",
          angle = 90,
          vjust = -1,
          hjust = -4.0,
          size = 4,
          color = "#3D9970"
        ) +
        annotate(
          geom = "text",
          x = bintervall,
          y = 0,
          label = "Obergrenze",
          angle = 90,
          vjust = 1.5,
          hjust = -4.0,
          size = 4,
          color = "#3D9970"
        )
    })
    
    # Render text of value box intervall_a
    output$intervall_a <- renderText({
      paste("a =", round(aintervall, digits = 2))
    })
    
    # Render text of value box intervall_b
    output$intervall_b <- renderText({
      paste("b =", round(bintervall, digits = 2))
    })
    
    # Render text of value box konfidenzniveau
    output$konfidenzniveau <- renderText({
      paste(niveau_percentage, "%")
    })
    
    # Render UI of box konfidenz
    output$konfidenz <- renderUI({
      tagList(
        p(
          "Unter Konfidenzintervallen (KI) sind statistische Intervalle zu verstehen, mit welchem man
                  besser einschätzen kann, wo - wie in diesem Fall - der wahre Erwartungswert µ eines Datensatzes liegt.
                 Dieses Konzept wird angewendet, da in der Statistik berechnete Werte oft auf der Grundlage einer Stichprobe zustande kommen.
          Für dieses Beispiel zur Berechnung von Konfidenzintervallen können für eine erste Vorauswahl über das Drop-Down erste Werte für Erwartungswert und Standardabweichung von Normwertskalen wie der IQ-Norm, z-Skala, T-Skala und Leistungsskala von PISA-Studien, die für die  Normierung von psychologischen Tests verwendet werden, festgelegt werden."
        )
      )
    })
    
    # Render UI of box berech_erkl
    output$berech_erkl <- renderUI({
      tagList(
        p(
          "Für die Berechnung wurden Daten normalverteilt über die Funktion", 
          em("rnorm"),
          "generiert.",
          "Nun soll als",
          strong("Konfidenzintervall"),
          "ein Intervall von der Untergrenze",
          em("a"),
          "bis zur Obergrenze",
          em("b"),
          "gefunden werden.",
          br(),
          "Die Grenzen dieses Intervalles sollen so ermittelt werden, dass mit",
          strong(niveau_percentage, "%"),
          "-iger Wahrscheinlichkeit",
          "(1-\U003B1 = ",
          niveau,
          ")",
          "der wahre Erwartungswert der Grundgesamtheit zwischen ihnen liegt. Den wahren Erwartungswert der Grundgesamtheit
          kann nicht ermitteln werden, da nur mit einer Stichprobe von",
          strong(n),
          "Werten gerechnet wird.",
          "Dabei ist die Annahme, dass das Intervall symmetrisch und die Werte normalverteilt sind und die Standardabweichung, in diesem Fall",
          strong("\U003C3", "=", sd),
          "bekannt ist."
        )
      )
    })
    
    # Render UI of box verbal_erkl
    output$verbal_erkl <- renderUI({
      tagList(
        p(
          "Der wahre Erwartungswert \U00B5 der Grundgesamtheit befindet sich mit einer Wahrscheinlichkeit von",
          strong(niveau_percentage),
          "% innerhalb des Intervalls mit der Untergrenze von",
          strong(round(aintervall, digits = 2)),
          "bis zur Obergrenze von",
          strong(round(bintervall, digits = 2))
        )
      )
    })
    
    # Render UI of box formeln
    output$formeln <- renderUI({
      tagList(
        p(
          "Um die Berechnungen der Intervallgrenzen nachzuvollziehen, sind hier die Formeln für die Ober- und Untergrenze gegeben:",
          strong(
            HTML(
              " a = X̅ - Z <sub> 1 - α/2 </sub> * <sup>σ</sup> / <sub>√n</sub>"
            )
          ),
          "und",
          strong(
            HTML(
              "b = X̅ + Z <sub> 1 - α/2 </sub> * <sup>σ</sup> / <sub>√n</sub>"
            )
          )
        )
      )
    })
    
    # Render UI of box unterschied
    output$unterschied <- renderUI({
      tagList(
        p(
          "Für das Gesamtverständnis zu Konfidenzintervallen ist es wichtig, dass der Unterschied der beiden oben dargestellten Diagramme klar wird.",
          br(),
          "Das Diagramm", 
          em("Datensatz der Stichprobe"),
          "enthält die Verteilung der generierten Werte der Normalverteilung mit der ausgewählten Stichprobengröße, dem angegebenen Erwartungswert und der angegebenen Standardabweichung.",
          "Mit den grünen Linien sind in diesem Diagramm die Intervallgrenzen des Konfidenzintervalls dargestellt.",
          "Das Diagramm",
          em("Konfidenzintervall um den geschätzten Erwartungswert"),
          "bildet die Verteilung der Mittelwerte ab. Es werden ebenfalls die Intervallgrenzen abgebildet, in denen der wahre Mittelwert zu erwarten ist. Es ist deutlich zu erkennen, dass das Konfidenzintervall bei der Verteilung der Daten enger ist als bei der Verteilung der Mittelwerte."
        )
      )
    })
    
    # Render UI of box quellen
    output$quellen <- renderUI({
      tagList(div(
        HTML(
          "<font size=2><em><ul>
      <li> Fahrmeir, L., Heumann C., et al. (2010): Statistik – Der Weg zur Datenanalyse. 7. Auflage, Springer. </li>
      <li> Rdrr.iO (2022): shinyjs, in: https://rdrr.io/cran/shinyjs/, (Stand: 04.01.2022). </li>
      <li> RStudio (2022): ShinyDashboard, in: https://rstudio.github.io/shinydashboard/, (Stand: 04.01.2022). </li>
      <li> Schemmel, J., Ziegler, M. (2020): Der Konfidenzintervall-Rechner: Web-Anwendung zur Berechnung und grafischen Darstellung von Konfidenzintervallen für die testpsychologische Diagnostik. Report Psychologie, 45(1), 16-21. </li>
      <li> Schmuller, J. (2017): Statistik mit R für Dummies, Weinheim. </li>
      <li>StudyFlix (2021): Konfidenzintervalle, in: https://studyflix.de/statistik/konfidenzintervall-1580, (Stand: 28.12.2021) </li>
      <li> Wikipedia (2022): Normwertskala, in: https://de.wikipedia.org/wiki/Normwertskala, (Stand: 04.01.2022). </li>
     </ul></em></font>"
        )
      ))
    })
    
  })
  
  # Click button
  click("verteil_mich_button")
  
  # Set pre-set values of drop-down
  observeEvent(input$normierung, {
    if (input$normierung == 1) {
      updateNumericInput(session, "ewert", value = 100)
      updateNumericInput(session, "sd", value = 15)
    }
    else if (input$normierung == 2) {
      updateNumericInput(session, "ewert", value = 500)
      updateNumericInput(session, "sd", value = 100)
    }
    else if (input$normierung == 3) {
      updateNumericInput(session, "ewert", value = 50)
      updateNumericInput(session, "sd", value = 10)
    }
    else if (input$normierung == 4) {
      updateNumericInput(session, "ewert", value = 0)
      updateNumericInput(session, "sd", value = 1)
    }
  })
}

# Run the application
shinyApp(ui = ui, server = server)

