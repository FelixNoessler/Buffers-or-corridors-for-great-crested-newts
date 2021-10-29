
setwd("~/Desktop/newt/model analysis/Recolonisation/scripts")



library(dplyr)
library(ggplot2)


data <- readr::read_delim('../data/concat_data.csv')

data %>%
  mutate(corr_reached = corridor_year != -999,
         buffer_reached = buffer_year != -999) %>%
  group_by(mortality_decrease, movement_energy) %>%
  summarise(z = sum(corr_reached), .groups='keep')%>%
ggplot(aes(mortality_decrease, movement_energy, fill= z)) + 
  geom_tile()+
  theme_bw()

data %>%
  ggplot(aes(buffer_year, movement_energy))+
  geom_point()+
  xlim(0, 100)
  
  
  
  
