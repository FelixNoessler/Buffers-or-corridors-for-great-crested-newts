
library(dplyr)
library(ggplot2)

data <- readr::read_delim('../data/concat_data.csv')

df <- data %>%
  tidyr::pivot_longer(c(buffer_year, corridor_year)) %>%
  filter(value != -999) %>%
  mutate(energy_factor = factor(movement_energy, 
                                labels=c('200 - 400', 
                                         '200 - 400',
                                         '200 - 400',
                                         '400 - 600',
                                         '400 - 600',
                                         '600 - 800',
                                         '600 - 800',
                                         '800 - 1000',
                                         '800 - 1000',
                                         '800 - 1000')),
         name = factor(name, 
                       labels=c('Buffer', 'Corridor')))
outliers <- df %>%
  group_by(energy_factor, name)%>%
  filter(value > quantile(value, 0.75) + 1.5 * IQR(value)) %>%
  mutate(value = ifelse(value > 75, 90, value))

df %>%
  #filter(value <= 50) %>%
  ggplot(aes(energy_factor, value, fill=name, color=name))+
  
  stat_boxplot(color='black', geom ='errorbar', width=0.4, position = position_dodge(width = 0.7)) +
  geom_boxplot(color='black', outlier.shape=NA, width=0.6, position = position_dodge(width = 0.7))+
  scale_fill_manual(guide='none', values = c('#67AB9F', '#EA6B66'))+
  
  ggbeeswarm::geom_beeswarm(data=outliers, cex=0.47, dodge.width=0.7, alpha=0.8,
                            priority = 'ascending')+
  scale_color_manual('Scenario',values = c('#9AC7BF', '#F19C99'))+
  
  geom_hline(yintercept = 85, alpha=0.1)+
  
  scale_y_continuous(breaks=c(0,20,40,60, 90),
                     labels=c('0', '20', '40', '60', '> 75'))+
  labs(x='Movement energy',
       y='Year with first occupancy')+
  coord_cartesian(ylim = c(0, 90))+
  theme_classic()+
  theme(text = element_text(size=14))
ggsave('../results/year.svg')




