

setwd(getSrcDirectory()[1])


library(dplyr)
library(ggplot2)

data <- readr::read_delim('../data/concat_data.csv')


data  %>%
  select(`newts-buffer`, `newts-corridor`, 
         `mortality-decrease-with-buffer`, 
         `distance-for-viewing-ponds-and-woodland`) %>%
  rename('Buffer scenario' = `newts-buffer`,
         'Corridor scenario' = `newts-corridor`,
         mort = `mortality-decrease-with-buffer`,
         dist = `distance-for-viewing-ponds-and-woodland`) %>%
  tidyr::pivot_longer(cols=c('Buffer scenario', 'Corridor scenario')) %>%
  ggplot()+
  geom_boxplot(aes(x=factor(mort), y = value, fill=factor(dist)),
               size = 0.3, outlier.size = 0.3)+
  scale_fill_discrete('Viewing\ndistance')+
  facet_wrap(~name)+
  labs(x = 'Mortality decrease for the buffer scenario',
       y = 'Population size after 50 years')+
  theme_light()+
  theme(text = element_text(size=14))
ggsave('../results/mortality_viewing_distance.svg')



